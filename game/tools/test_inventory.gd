extends SceneTree

## Inventory-system unit checks: catalog integrity, grid placement, stacking,
## rotation, weight limits, serialization, and UI pick/place/transfer.
## godot --headless --path . -s res://tools/test_inventory.gd

const CATALOG := preload("res://scripts/gameplay/item_catalog.gd")
const INVENTORY := preload("res://scripts/gameplay/inventory.gd")
const INVENTORY_UI := preload("res://scripts/gameplay/inventory_ui.gd")

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)


func _new_inv(w: int = 4, h: int = 4, limit: float = -1.0) -> RefCounted:
	return INVENTORY.new(w, h, limit)


func _run() -> void:
	# Catalog integrity
	_check(CATALOG.all_ids().size() >= 25, "catalog too small")
	for id: String in CATALOG.all_ids():
		var def = CATALOG.get_def(id)
		var size: Vector2i = def.get("size", Vector2i.ZERO)
		_check(size.x > 0 and size.y > 0, "%s bad size" % id)
		_check(def.has("name") and def.has("category") and def.has("max_stack"), "%s missing fields" % id)

	# Placement + overlap
	var inv := _new_inv(4, 4)
	_check(inv.add_item("ak74", 1) == 0, "ak74 not placed")
	_check(inv.entry_at(Vector2i(0, 0))["id"] == "ak74", "ak74 not at origin")
	_check(inv.entry_at(Vector2i(3, 1))["id"] == "ak74", "ak74 footprint wrong")
	_check(not inv.can_place("pm_pistol", Vector2i(2, 0)), "overlap should be refused by can_place")
	_check(inv.add_item("pm_pistol", 1, Vector2i(2, 0)) == 0, "pistol should auto-fall-back to a free cell")
	_check(inv.entry_at(Vector2i(2, 0))["id"] == "ak74", "blocked cell must keep its owner")

	# Stacking
	var ammo := _new_inv(4, 4)
	_check(ammo.add_item("ammo_545", 90) == 0, "ammo leftover")
	_check(ammo.count_of("ammo_545") == 90, "ammo count wrong")
	_check(ammo.entry_count() == 2, "ammo should occupy two stacks")
	_check(ammo.add_item("ammo_545", 40) == 0, "40 more rounds should fit")
	ammo.add_item("ammo_545", 2000)
	_check(ammo.count_of("ammo_545") == 960, "16 cells x 60 rounds expected")

	# Rotation: 1x2 item into a 2-wide slot only fits rotated
	var rot := _new_inv(2, 2)
	_check(rot.add_item("water_bottle", 1, Vector2i(0, 0), true) == 0, "rotated bottle failed")
	var bottle = rot.entry_at(Vector2i(0, 0))
	_check(bottle.get("rotated", false) == true, "rotation flag missing")
	_check(INVENTORY.entry_size(bottle) == Vector2i(2, 1), "rotated footprint wrong")

	# Weight limit
	var bag := _new_inv(8, 8, 1.0)
	var leftover = bag.add_item("scrap_metal", 4)  # 1.2 kg each
	_check(leftover == 4 and bag.is_empty(), "overweight add not refused")
	_check(bag.add_item("bolts", 3) == 0, "0.9 kg should fit")
	_check(bag.add_item("bolts", 1) == 1, "1.2 kg total must reject 4th bolt")

	# Move + take
	var mv := _new_inv(4, 4)
	mv.add_item("gold_chain", 1)
	_check(mv.move_entry(Vector2i(0, 0), Vector2i(2, 2)), "move failed")
	_check(mv.entry_at(Vector2i(0, 0)).is_empty(), "origin not cleared")
	_check(mv.entry_at(Vector2i(2, 2))["id"] == "gold_chain", "move target wrong")
	_check(mv.take_at(Vector2i(2, 2))["count"] == 1, "take failed")
	_check(mv.is_empty(), "inventory not empty after take")

	# Split
	var sp := _new_inv(4, 4)
	sp.add_item("bolts", 10, Vector2i(0, 0))
	_check(sp.split_stack(Vector2i(0, 0), Vector2i(2, 0), 4), "split failed")
	_check(sp.count_of("bolts") == 10 and sp.entry_count() == 2, "split bookkeeping wrong")
	_check(not sp.split_stack(Vector2i(0, 0), Vector2i(0, 0), 1), "overlapping split allowed")

	# Serialization round-trip
	var rt := _new_inv(6, 5, 25.0)
	rt.add_item("salewa", 1)
	rt.add_item("ammo_9x18", 75)
	rt.add_item("water_bottle", 1, Vector2i(-1, -1), true)
	var data = rt.serialize()
	var inv2: RefCounted = INVENTORY.deserialize(data)
	_check(inv2.grid_size == Vector2i(6, 5), "grid size not restored")
	_check(inv2.count_of("ammo_9x18") == 75, "stack counts lost")
	_check(inv2.total_weight() == rt.total_weight(), "weight changed")
	_check(inv2.serialize() == data, "serialize not stable")

	# UI: pick up, place elsewhere, quick-transfer to linked panel
	var ui := INVENTORY_UI.new()
	var ui_inv := _new_inv(6, 4)
	ui_inv.add_item("gp_coin", 1, Vector2i(0, 0))
	ui_inv.add_item("bandage", 2, Vector2i(2, 0))
	root.add_child(ui)
	ui.setup(ui_inv, "test")
	var other_inv := _new_inv(6, 4)
	var other := INVENTORY_UI.new()
	root.add_child(other)
	other.setup(other_inv, "other")
	ui.link(other)

	ui.click_cell(Vector2i(0, 0))
	_check(ui.held_item().get("id") == "gp_coin", "pick up failed")
	ui.click_cell(Vector2i(4, 2))
	_check(ui.held_item().is_empty() and ui_inv.entry_at(Vector2i(4, 2)).get("id") == "gp_coin", "place failed")
	ui.click_cell(Vector2i(2, 0), MOUSE_BUTTON_RIGHT)
	_check(other_inv.count_of("bandage") == 2 and ui_inv.count_of("bandage") == 0, "quick transfer failed")

	# Cross-panel drag: pick in A, drop into B
	ui_inv.add_item("wire", 3, Vector2i(0, 1))
	ui.click_cell(Vector2i(0, 1))
	other.click_cell(Vector2i(3, 3))
	_check(other_inv.count_of("wire") == 3 and ui_inv.count_of("wire") == 0, "cross-panel drag failed")

	# Cancel with a now-full source keeps the leftover in hand
	var small_inv := _new_inv(1, 1)
	small_inv.add_item("gp_coin", 1, Vector2i(0, 0))
	var small := INVENTORY_UI.new()
	root.add_child(small)
	small.setup(small_inv, "small")
	small.link(ui)
	small.click_cell(Vector2i(0, 0))
	_check(small.held_item().get("id") == "gp_coin", "small pick failed")
	small_inv.add_item("bolts", 1, Vector2i(0, 0))  # occupy the only cell
	small.click_cell(Vector2i(0, 0), MOUSE_BUTTON_RIGHT)  # cancel hold
	_check(small.held_item().get("count") == 1, "cancel deleted the held item")

	# Re-linking must not orphan earlier partners (review BUG_0002): the held
	# coin goes home first, then a fresh pick in ui must drop into other.
	ui.click_cell(Vector2i(5, 3))
	_check(ui.held_item().is_empty() and ui_inv.count_of("gp_coin") == 2, "held coin failed to return")
	ui_inv.add_item("duct_tape", 1, Vector2i(4, 3))
	ui.click_cell(Vector2i(4, 3))
	other.click_cell(Vector2i(1, 1))
	_check(other_inv.count_of("duct_tape") == 1 and ui_inv.count_of("duct_tape") == 0,
		"third panel link orphaned the first partner")
	small.queue_free()

	# Chained links share one drag state across every panel (review-2 BUG_0002)
	var fourth_inv := _new_inv(4, 4)
	var fourth := INVENTORY_UI.new()
	root.add_child(fourth)
	fourth.setup(fourth_inv, "fourth")
	other.link(fourth)  # link via a middle panel: ui must still share state
	ui_inv.add_item("wire", 1, Vector2i(0, 2))
	ui.click_cell(Vector2i(0, 2))
	fourth.click_cell(Vector2i(1, 1))
	_check(fourth_inv.count_of("wire") == 1, "chained link split the drag group")
	ui.queue_free()
	other.queue_free()
	fourth.queue_free()

	# Linking while a panel holds an item must keep it (review-2 BUG_0001)
	var holder_inv := _new_inv(3, 3)
	holder_inv.add_item("gp_coin", 1, Vector2i(0, 0))
	var holder := INVENTORY_UI.new()
	root.add_child(holder)
	holder.setup(holder_inv, "holder")
	holder.click_cell(Vector2i(0, 0))
	var fresh := INVENTORY_UI.new()
	root.add_child(fresh)
	fresh.setup(_new_inv(3, 3), "fresh")
	fresh.link(holder)
	_check(fresh.held_item().get("id") == "gp_coin", "re-link deleted the held item")
	fresh.click_cell(Vector2i(1, 1))
	_check(fresh.get("inventory").count_of("gp_coin") == 1, "held coin lost across link")

	# Freed partners are pruned so re-linking still works (review-2 BUG_0003)
	var gone := INVENTORY_UI.new()
	root.add_child(gone)
	gone.setup(_new_inv(3, 3), "gone")
	gone.link(fresh)
	gone.free()  # immediate free: simulates a freed linked partner
	var fifth_inv := _new_inv(3, 3)
	var fifth := INVENTORY_UI.new()
	root.add_child(fifth)
	fifth.setup(fifth_inv, "fifth")
	fresh.link(fifth)
	fresh.get("inventory").add_item("bolts", 1, Vector2i(0, 0))
	fresh.click_cell(Vector2i(0, 0))
	fifth.click_cell(Vector2i(1, 1))
	_check(fifth_inv.count_of("bolts") == 1, "freed partner blocked re-linking")
	fresh.queue_free()
	fifth.queue_free()
	holder.queue_free()

	# When both groups hold items, the displaced one returns to its source (review-3 BUG_0001)
	var a_inv := _new_inv(3, 3)
	a_inv.add_item("gp_coin", 1, Vector2i(0, 0))
	var a := INVENTORY_UI.new()
	root.add_child(a)
	a.setup(a_inv, "a")
	var b_inv := _new_inv(3, 3)
	b_inv.add_item("bolts", 1, Vector2i(0, 0))
	var b := INVENTORY_UI.new()
	root.add_child(b)
	b.setup(b_inv, "b")
	a.click_cell(Vector2i(0, 0))  # a holds coin
	b.click_cell(Vector2i(0, 0))  # b holds bolts
	a.link(b)
	_check(a.held_item().get("id") == "bolts", "link dropped the held item")
	_check(a_inv.count_of("gp_coin") == 1, "displaced held item vanished")
	a.queue_free()
	b.queue_free()

	# Right-click transfer picks a live partner when `linked` is freed (review-3 BUG_0002)
	var qa_inv := _new_inv(3, 3)
	qa_inv.add_item("wire", 1, Vector2i(0, 0))
	var qa := INVENTORY_UI.new()
	root.add_child(qa)
	qa.setup(qa_inv, "qa")
	var qb := INVENTORY_UI.new()
	root.add_child(qb)
	qb.setup(_new_inv(3, 3), "qb")
	var qc_inv := _new_inv(3, 3)
	var qc := INVENTORY_UI.new()
	root.add_child(qc)
	qc.setup(qc_inv, "qc")
	qa.link(qb)
	qb.link(qc)  # group {qa, qb, qc}; qa.linked = qb
	qb.free()  # qa.linked now dangles
	qa.click_cell(Vector2i(0, 0), MOUSE_BUTTON_RIGHT)
	_check(qc_inv.count_of("wire") == 1 and qa_inv.is_empty(), "transfer to freed panel failed")
	qa.queue_free()
	qc.queue_free()

	# Move must not renumber later stacks (review BUG_0001)
	var mv2 := _new_inv(6, 3)
	mv2.add_item("wire", 2, Vector2i(0, 0))
	mv2.add_item("bolts", 3, Vector2i(1, 0))
	mv2.add_item("gp_coin", 1, Vector2i(2, 0))
	mv2.move_entry(Vector2i(0, 0), Vector2i(0, 1))
	_check(mv2.entry_at(Vector2i(2, 0)).get("id") == "gp_coin", "later stack misidentified after move")
	_check(mv2.entry_at(Vector2i(1, 0)).get("id") == "bolts", "middle stack misidentified after move")

	# Saved partial stacks restore at their own cells (review BUG_0003)
	var saved := {"grid": [4, 4], "weight_limit": -1.0, "items": [
		{"id": "bolts", "count": 3, "pos": [0, 0]},
		{"id": "bolts", "count": 2, "pos": [3, 3]},
	]}
	var restored: RefCounted = INVENTORY.deserialize(saved)
	_check(restored.entry_count() == 2, "partial stacks merged on load")
	_check(restored.entry_at(Vector2i(3, 3)).get("count") == 2, "saved layout lost")

	# Blocked rotated item keeps its rotated footprint on restore (review BUG_0003)
	var blocked := {"grid": [2, 2], "weight_limit": -1.0, "items": [
		{"id": "gp_coin", "count": 1, "pos": [0, 0]},
		{"id": "gp_coin", "count": 1, "pos": [1, 0]},
		{"id": "water_bottle", "count": 1, "pos": [0, 0], "rotated": true},
	]}
	var rb_inv: RefCounted = INVENTORY.deserialize(blocked)
	var rbe = rb_inv.entry_at(Vector2i(0, 1))
	_check(rbe.get("id") == "water_bottle" and rbe.get("rotated", false), "rotated item lost on restore")

	# Rotate toggles the held footprint (review BUG_0004)
	var ri := _new_inv(4, 4)
	ri.add_item("water_bottle", 1, Vector2i(0, 0))
	var rui := INVENTORY_UI.new()
	root.add_child(rui)
	rui.setup(ri, "rot")
	rui.click_cell(Vector2i(0, 0))
	rui.rotate_held()
	_check(rui.held_item().get("rotated") == true, "rotate_held did not toggle")
	rui.queue_free()

	# Two full sources: the displaced held stack queues instead of vanishing
	# (PR6-review BUG_0001). a holds a coin it can never put back; b holds
	# bolts with a likewise-full source.
	var fa_inv := _new_inv(1, 1)
	fa_inv.add_item("gp_coin", 1, Vector2i(0, 0))
	var fa := INVENTORY_UI.new()
	root.add_child(fa)
	fa.setup(fa_inv, "fa")
	var fb_inv := _new_inv(1, 1)
	fb_inv.add_item("bolts", 1, Vector2i(0, 0))
	var fb := INVENTORY_UI.new()
	root.add_child(fb)
	fb.setup(fb_inv, "fb")
	# Both sources stay full after the picks: re-add to the freed cell.
	fa.click_cell(Vector2i(0, 0))  # fa holds coin
	fa_inv.add_item("wire", 1, Vector2i(0, 0))
	fb.click_cell(Vector2i(0, 0))  # fb holds bolts
	fb_inv.add_item("duct_tape", 1, Vector2i(0, 0))
	fa.link(fb)
	# Nothing vanished: one stack is on the cursor, the other is queued.
	var held_id := String(fa.held_item().get("id", ""))
	var queued: Array = fa.get("_drag").get("queued", [])
	_check(not held_id.is_empty(), "merge cleared the cursor")
	var queued_total := 0
	for q in queued:
		queued_total += int(q["count"])
	var held_count = int(fa.held_item().get("count", 0))
	_check(held_count + queued_total == 2, "merge lost a stack (held=%d queued=%d)" % [held_count, queued_total])
	# Placing the cursor stack promotes the queued one.
	fa_inv.take_at(Vector2i(0, 0))  # free fa's only cell
	fa.click_cell(Vector2i(0, 0))
	_check(fa_inv.entry_count() == 1, "cursor stack failed to place")
	_check(not fa.held_item().is_empty(), "queued stack was not promoted")

	# Queued stacks survive a second merge (PR16-review BUG_0001): a fresh
	# panel holding an item links in and becomes shared — the parked queue
	# must move onto the winning drag, not vanish with the old one.
	var fc_inv := _new_inv(1, 1)
	fc_inv.add_item("bandage", 1, Vector2i(0, 0))
	var fc := INVENTORY_UI.new()
	root.add_child(fc)
	fc.setup(fc_inv, "fc")
	fc.click_cell(Vector2i(0, 0))  # fc holds a bandage, source stays full? no — cell freed
	fc_inv.add_item("gp_coin", 1, Vector2i(0, 0))  # refill: fc's source is full again
	fb.link(fc)  # merge {fa,fb} (queued=[coin-ish]) with {fc} (held bandage)
	var drag_after: Dictionary = fa.get("_drag")
	var total_now := int(drag_after["held"].get("count", 0))
	for q in drag_after.get("queued", []):
		total_now += int(q["count"])
	_check(total_now == 2, "relink dropped queued items (total=%d)" % total_now)
	fa.queue_free()
	fb.queue_free()
	fc.queue_free()

	# load_data restores into the SAME inventory and empty data resets it
	# (PR14-review BUG_0002: deserialize returned a new inventory that the
	# caller discarded, so the target kept its stale contents).
	var src := _new_inv(6, 4)
	src.add_item("bandage", 2)
	src.add_item("gp_coin", 1)
	var dst := _new_inv(6, 4)
	dst.load_data(src.serialize())
	_check(dst.count_of("bandage") == 2, "load_data missed bandage")
	_check(dst.count_of("gp_coin") == 1, "load_data missed gp_coin")
	_check(dst.entry_count() == src.entry_count(), "load_data wrong entry count")
	dst.load_data({})
	_check(dst.is_empty(), "empty blob did not reset inventory")

	print("Inventory checks: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
