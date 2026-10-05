extends SceneTree

## Raid-loop checks: extraction merge into stash, death loot loss,
## loot crate fill/pending/drain.

const INVENTORY := preload("res://scripts/gameplay/inventory.gd")
const RAID_KIT := preload("res://scripts/gameplay/raid_kit.gd")
const LOOT_CRATE := preload("res://scripts/gameplay/loot_crate.gd")

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)


func _run() -> void:
	# Extraction merges the backpack into the stash and empties it.
	var backpack := INVENTORY.new(8, 5, 40.0)
	var stash := INVENTORY.new(10, 8)
	backpack.add_item("bandage", 2)
	backpack.add_item("gp_coin", 1)
	var result: Dictionary = RAID_KIT.merge_into_stash(backpack, stash)
	_check(result["moved"] == 3 and result["dropped"] == 0, "merge counts wrong: %s" % str(result))
	_check(stash.count_of("bandage") == 2 and stash.count_of("gp_coin") == 1, "stash missing items")
	_check(backpack.is_empty(), "backpack not emptied after extract")

	# Overflow drops count as lost, not destroyed silently. A 1x1 stash
	# can't hold a 2x2 toolset.
	var tiny_stash := INVENTORY.new(1, 1)
	backpack.add_item("toolset", 1)
	result = RAID_KIT.merge_into_stash(backpack, tiny_stash)
	_check(result["moved"] == 0 and result["dropped"] == 1, "overflow not counted as dropped")
	_check(backpack.is_empty(), "backpack kept overflow items")

	# Death clears the backpack entirely.
	backpack.add_item("ak74", 1)
	backpack.add_item("ammo_545", 30)
	var lost: int = RAID_KIT.clear_backpack(backpack)
	_check(lost == 31 and backpack.is_empty(), "death kept backpack items")

	# Loot crate: search once fills its grid; overflow goes to pending.
	var crate := LOOT_CRATE.new()
	crate.setup("medkit", 1, 1, 0.1)  # tiny grid forces pending
	root.add_child(crate)
	var finished := []
	crate.searchable.search_finished.connect(func(items: Array) -> void: finished.append_array(items))
	_check(crate.begin_search(), "crate search did not start")
	crate.searchable.tick(0.2)
	_check(crate.searched(), "crate not marked searched")
	_check(finished.size() > 0, "crate emitted no loot")
	_check(crate.pending.size() + crate.inventory.entry_count() > 0, "crate holds nothing")
	var pending_before = crate.pending.size()
	crate.drain_pending()
	_check(crate.pending.size() == pending_before, "drain moved items without space")
	# Free space? tiny grid holds 1 item; verify pending retried when freed
	var inv_count = crate.inventory.entry_count()
	_check(inv_count <= 1, "tiny crate overfilled")
	_check(crate.display_prompt().contains("容器"), "looted crate prompt wrong: %s" % crate.display_prompt())
	_check(crate.item_names() is Array, "item_names broken")

	# A bigger crate: everything fits directly.
	var big := LOOT_CRATE.new()
	big.setup("food", 8, 6, 0.1)
	root.add_child(big)
	big.begin_search()
	big.searchable.tick(0.2)
	_check(big.pending.is_empty(), "big crate left pending")
	_check(big.inventory.entry_count() > 0, "big crate empty")

	crate.free()
	big.free()

	# Rotated pending survives a drain (PR17-review BUG_0003): a rotated
	# 1x2 water bottle only fits a 2-wide column when kept rotated.
	var rot_crate := LOOT_CRATE.new()
	rot_crate.setup("food", 2, 1, 0.1)  # 2x1 grid: bottle fits only rotated
	root.add_child(rot_crate)
	rot_crate.pending.append({"id": "water_bottle", "count": 1, "rotated": true})
	rot_crate.drain_pending()
	_check(rot_crate.inventory.count_of("water_bottle") == 1, "rotated pending never drained")
	_check(rot_crate.pending.is_empty(), "rotated pending stuck in queue")
	rot_crate.free()

	# Hands-carried stacks merge on extract and are dropped when full
	# (PR17-review BUG_0001/0002).
	var pend := [{"id": "gp_coin", "count": 1}, {"id": "toolset", "count": 1}]
	var room_stash := INVENTORY.new(4, 4)
	var pr: Dictionary = RAID_KIT.merge_pending_into_stash(pend, room_stash)
	_check(pr["moved"] == 2 and pr["dropped"] == 0, "pending merge wrong: %s" % str(pr))
	_check(room_stash.count_of("gp_coin") == 1 and room_stash.count_of("toolset") == 1, "pending not in stash")
	_check(pend.is_empty(), "pending not consumed by extract")

	print("Raid loop checks: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
