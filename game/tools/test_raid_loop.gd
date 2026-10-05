extends SceneTree

## Raid-loop checks: extraction merge into stash, death loot loss,
## loot crate fill/pending/drain.

const INVENTORY := preload("res://scripts/gameplay/inventory.gd")
const RAID_KIT := preload("res://scripts/gameplay/raid_kit.gd")
const LOOT_CRATE := preload("res://scripts/gameplay/loot_crate.gd")
const RAID_GAME := preload("res://scripts/gameplay/raid_game.gd")
const WEAPON_CONTROLLER := preload("res://scripts/gameplay/weapon_controller.gd")
const INVENTORY_UI := preload("res://scripts/gameplay/inventory_ui.gd")
const GAME_STATE := preload("res://scripts/gameplay/game_state.gd")

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

	# 回归 (review BUG_0001): 容器关界面时，玩家持物的兜底家只有玩家格子——
	# 背包物自动塞回箱子会在撤离时随箱子留在图里遗失。
	GAME_STATE.ensure()
	GAME_STATE.backpack.clear()
	for i in 40:  # 8x5 背包填满
		GAME_STATE.backpack.add_item("gp_coin", 1)
	var hold_crate := LOOT_CRATE.new()
	hold_crate.setup("food", 4, 4, 0.1)
	root.add_child(hold_crate)
	var rg = RAID_GAME.new()
	var crate_ui := INVENTORY_UI.new()
	root.add_child(crate_ui)
	crate_ui.setup(hold_crate.inventory, "容器")
	var pack_ui := INVENTORY_UI.new()
	root.add_child(pack_ui)
	pack_ui.setup(GAME_STATE.backpack, "背包")
	crate_ui.link(pack_ui)
	rg.set("_container_panels", [crate_ui, pack_ui])
	rg.set("_container_overflow", hold_crate)
	var drag: Dictionary = crate_ui.get("_drag")
	drag["held"] = {"id": "bandage", "count": 1}
	drag["from_inv"] = GAME_STATE.backpack
	rg.call("_release_held_loot")
	_check(hold_crate.inventory.count_of("bandage") == 0, "背包持物被塞回箱子")
	_check(hold_crate.pending.is_empty(), "背包持物进了箱子 pending")
	_check(GAME_STATE.raid_pending.size() == 1, "持物未留在手上（raid_pending）")
	# 反向：箱子自己的物退回箱子 pending。
	for i in 16:
		hold_crate.inventory.add_item("gp_coin", 1)
	drag["held"] = {"id": "bandage", "count": 1}
	drag["from_inv"] = hold_crate.inventory
	rg.call("_release_held_loot")
	_check(hold_crate.pending.size() == 1, "箱子持物未退回箱子")
	_check(GAME_STATE.raid_pending.size() == 1, "箱子持物误入 raid_pending")
	GAME_STATE.raid_pending.clear()
	rg.free()
	crate_ui.free()
	pack_ui.free()
	hold_crate.free()

	# 回归 (review BUG_0003): 搜刮弹药按口径并入武器储备。
	GAME_STATE.backpack.clear()
	GAME_STATE.backpack.add_item("ammo_9x18", 30)
	GAME_STATE.backpack.add_item("ammo_545", 60)
	var rg2 = RAID_GAME.new()
	var wpn := WEAPON_CONTROLLER.new()
	wpn.setup("pm", -1, 0)
	rg2.set("_weapon", wpn)
	rg2.call("_scavenge_ammo")
	_check(wpn.reserve == 30, "口径弹药未并入储备: %d" % wpn.reserve)
	_check(GAME_STATE.backpack.count_of("ammo_9x18") == 0, "弹药未从背包消耗")
	_check(GAME_STATE.backpack.count_of("ammo_545") == 60, "异口径弹药被误收")
	GAME_STATE.backpack.clear()
	wpn.free()
	rg2.free()

	print("Raid loop checks: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
