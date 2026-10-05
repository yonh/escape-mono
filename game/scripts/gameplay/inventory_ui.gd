extends Control

## Grid inventory panel: draws cells and item rectangles, click to pick up /
## place (across linked panels too), right-click (or Ctrl+click)
## quick-transfers to the linked panel, R rotates the held item.

const CATALOG := preload("res://scripts/gameplay/item_catalog.gd")
const INVENTORY := preload("res://scripts/gameplay/inventory.gd")
const UIFONT := preload("res://scripts/gameplay/ui_font.gd")
const CELL := 38
const GAP := 3
const PAD := 8
const TITLE_H := 26

var inventory: RefCounted
var linked: Control  # last panel linked to (informational)
# Shared drag state between linked panels: held = {id, count, rotated},
# from_inv = the Inventory the stack was picked from. `queued` holds extra
# stacks that had no home when groups merged (see _merge_drag_states); the
# next one is promoted to the cursor as soon as `held` empties.
var _drag := {"held": {}, "from_inv": null, "queued": []}
# Panels sharing _drag. Linking merges both sides' groups into one shared
# array, so re-linking never orphans earlier partners.
var _group: Array = []
var _mouse_cell := Vector2i(-1, -1)
var _title := ""
var _header: Label
var _weight_label: Label


func setup(inv: RefCounted, title: String = "") -> void:
	inventory = inv
	_title = title
	custom_minimum_size = Vector2(PAD * 2 + inv.grid_size.x * (CELL + GAP) - GAP, PAD * 2 + TITLE_H + inv.grid_size.y * (CELL + GAP) - GAP)
	size = custom_minimum_size
	_header = Label.new()
	_header.position = Vector2(PAD, 3)
	_header.text = title
	UIFONT.apply(_header, 14)
	add_child(_header)
	_weight_label = Label.new()
	_weight_label.position = Vector2(PAD + 170, 3)
	UIFONT.apply(_weight_label, 13)
	add_child(_weight_label)
	inventory.changed.connect(queue_redraw)
	_update_weight()


func link(other: Control) -> void:
	# Merge both panels' groups (pruning freed members), then share one drag
	# state across the union. Prefer a group holding an item: its stack was
	# already removed from its inventory and must not be lost.
	var members := _pruned_group()
	for p in other.call("_pruned_group"):
		if not members.has(p):
			members.append(p)
	for p in [self, other]:
		if not members.has(p):
			members.append(p)
	var shared := _merge_drag_states(members)
	for p in members:
		p.set("_drag", shared)
		p.set("_group", members)
	linked = other
	other.linked = self


## A merged group keeps a single held stack: the last holding group's item
## stays on the cursor and every other group's held stack returns to the
## inventory it was picked from (or any member's, if the source is full).
## Stacks that still have no home are queued on the shared drag and come
## back to the cursor one at a time — nothing is dropped.
func _merge_drag_states(members: Array) -> Dictionary:
	var held_drags: Array = []
	for p in members:
		var d: Dictionary = p.get("_drag")
		if not (d.get("held") as Dictionary).is_empty() and not held_drags.has(d):
			held_drags.append(d)
	if held_drags.is_empty():
		return _drag
	var shared: Dictionary = held_drags.pop_back()
	var queue: Array = held_drags
	var guard := 0
	while not queue.is_empty() and guard < 16:
		guard += 1
		var d: Dictionary = queue.pop_back()
		if d == shared:
			continue
		var held: Dictionary = d["held"]
		var leftover := _return_stack(held, d.get("from_inv"), members)
		if leftover > 0:
			# No inventory took the whole stack — keep this drag as the
			# group's shared state so the remainder stays held, and try the
			# same return for the previously chosen stack.
			d["held"] = {"id": held["id"], "count": leftover, "rotated": held.get("rotated", false)}
			queue.push_front(shared)
			shared = d
		else:
			d["held"] = {}
			d["from_inv"] = null
	# Guard exhausted with drags still unreturned: only one stack fits on
	# the cursor, so park the rest on the shared drag's queue.
	for d in queue:
		if d == shared:
			continue
		var held: Dictionary = d["held"]
		if held.is_empty():
			continue
		push_warning("inventory link queued an unreturned stack: %s x%d" % [held["id"], int(held["count"])])
		var waiting: Array = shared.get("queued", [])
		waiting.append({"id": held["id"], "count": int(held["count"]), "rotated": held.get("rotated", false)})
		shared["queued"] = waiting
		d["held"] = {}
		d["from_inv"] = null
	# Fold every member's parked queue into the winning drag so relinking
	# can't orphan stacks that were already waiting for the cursor.
	var seen: Array = []
	for p in members:
		var d2: Dictionary = p.get("_drag")
		if d2 == shared or seen.has(d2):
			continue
		seen.append(d2)
		var parked: Array = d2.get("queued", [])
		if not parked.is_empty():
			var merged_q: Array = shared.get("queued", [])
			merged_q.append_array(parked)
			shared["queued"] = merged_q
			d2["queued"] = []
	return shared


## Give `held` back to `from` first, then to any other member's inventory.
## Returns how many units still have no home.
func _return_stack(held: Dictionary, from_inv, members: Array) -> int:
	var leftover := int(held["count"])
	if from_inv != null:
		leftover = from_inv.add_item(String(held["id"]), leftover, Vector2i(-1, -1), bool(held.get("rotated", false)))
	for p in members:
		if leftover <= 0:
			break
		var inv = p.get("inventory")
		if inv != null and inv != from_inv:
			leftover = inv.add_item(String(held["id"]), leftover, Vector2i(-1, -1), bool(held.get("rotated", false)))
	return maxi(leftover, 0)


## When the held stack empties and merged groups parked extra stacks on
## `queued`, bring the next one onto the cursor.
func _promote_queued() -> void:
	var waiting: Array = _drag.get("queued", [])
	if not _drag["held"].is_empty() or waiting.is_empty():
		return
	_drag["held"] = waiting.pop_front()
	# The queued stack lost its origin — cancelling cycles it back into
	# the queue instead of returning to an inventory.
	_drag["from_inv"] = null


func _pruned_group() -> Array:
	var out: Array = []
	for p in _group:
		if is_instance_valid(p) and not out.has(p):
			out.append(p)
	return out


## Quick-transfer target. From a filtered panel (equipment slot) the item is
## being unequipped → first unfiltered acceptor (stash). From an ordinary
## panel, a filtered acceptor (empty slot that takes this kind) wins so gear
## equips on right-click; otherwise any acceptor, then linked.
func _transfer_target(item_id := "") -> Control:
	if not item_id.is_empty():
		var self_filtered: bool = inventory != null and not inventory.item_filter.is_null()
		for p in _pruned_group():
			var inv = p.get("inventory")
			if p == self or inv == null or not inv.accepts(item_id):
				continue
			var filtered: bool = not inv.item_filter.is_null()
			if filtered != self_filtered and (self_filtered or filtered):
				return p
		for p in _pruned_group():
			if p != self and p.get("inventory") != null and p.inventory.accepts(item_id):
				return p
	if is_instance_valid(linked):
		return linked
	for p in _pruned_group():
		if p != self:
			return p
	return null


func _update_weight() -> void:
	if _weight_label == null or inventory == null:
		return
	var w := "%.1f kg" % inventory.total_weight()
	if inventory.weight_limit >= 0.0:
		w += " / %.0f" % inventory.weight_limit
	_weight_label.text = w


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAW:
		_update_weight()


func _cell_rect(pos: Vector2i) -> Rect2:
	return Rect2(PAD + pos.x * (CELL + GAP), PAD + TITLE_H + pos.y * (CELL + GAP), CELL, CELL)


func _item_rect(pos: Vector2i, size: Vector2i) -> Rect2:
	return Rect2(PAD + pos.x * (CELL + GAP), PAD + TITLE_H + pos.y * (CELL + GAP), size.x * (CELL + GAP) - GAP, size.y * (CELL + GAP) - GAP)


func _mouse_to_cell(at: Vector2) -> Vector2i:
	var local := at - Vector2(PAD, PAD + TITLE_H)
	if local.x < 0 or local.y < 0:
		return Vector2i(-1, -1)
	return Vector2i(int(local.x / (CELL + GAP)), int(local.y / (CELL + GAP)))


func _held_size() -> Vector2i:
	var size: Vector2i = CATALOG.size(String(_drag["held"]["id"]))
	if _drag["held"].get("rotated", false):
		size = Vector2i(size.y, size.x)
	return size


## Top-left cell the held item would occupy if dropped at `cell`.
func _held_top_left(cell: Vector2i) -> Vector2i:
	var size := _held_size()
	return cell - size / 2


func _held_fits() -> bool:
	var held: Dictionary = _drag["held"]
	if held.is_empty() or _mouse_cell.x < 0:
		return false
	var top := _held_top_left(_mouse_cell)
	return inventory.can_place(String(held["id"]), top, -1, bool(held.get("rotated", false)))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.09, 0.09, 0.10, 0.94))
	for y in inventory.grid_size.y:
		for x in inventory.grid_size.x:
			var rect := _cell_rect(Vector2i(x, y))
			draw_rect(rect, Color(0.16, 0.16, 0.18))
			draw_rect(rect, Color(0.28, 0.28, 0.30), false, 1.0)
	var font := UIFONT.font()
	for entry in inventory.entries():
		var id := String(entry["id"])
		var rect := _item_rect(entry["pos"], INVENTORY.entry_size(entry))
		var color: Color = CATALOG.ui_color(id)
		draw_rect(rect, color.darkened(0.15))
		draw_rect(rect, color.lightened(0.25), false, 1.5)
		var label := "%s" % CATALOG.item_name(id)
		if int(entry["count"]) > 1:
			label += " x%d" % int(entry["count"])
		draw_string(font, rect.position + Vector2(3, 13), label, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 4, 10, Color.WHITE)
		draw_string(font, rect.position + Vector2(3, rect.size.y - 5), CATALOG.category_label(id), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 4, 9, Color(1, 1, 1, 0.55))
	var held: Dictionary = _drag["held"]
	if not held.is_empty() and _mouse_cell.x >= 0:
		var top := _held_top_left(_mouse_cell)
		var ghost := _item_rect(top, _held_size())
		var color: Color = CATALOG.ui_color(String(held["id"]))
		color.a = 0.45 if _held_fits() else 0.18
		draw_rect(ghost, color)
		draw_rect(ghost, Color.RED if not _held_fits() else color.lightened(0.4), false, 2.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_cell = _mouse_to_cell(event.position)
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		var cell := _mouse_to_cell(event.position)
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.ctrl_pressed:
				_quick_transfer(cell)
			elif _drag["held"].is_empty():
				_pick(cell)
			else:
				_place(cell)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if _drag["held"].is_empty():
				_quick_transfer(cell)
			else:
				_cancel_hold()
	elif event is InputEventMouseButton and not event.pressed:
		_mouse_cell = _mouse_to_cell(event.position)


func _unhandled_key_input(event: InputEvent) -> void:
	# _gui_input needs keyboard focus; R rotation must work while the pointer
	# simply hovers a panel.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		if not _drag["held"].is_empty() and get_global_rect().has_point(get_global_mouse_position()):
			rotate_held()


func rotate_held() -> void:
	if _drag["held"].is_empty():
		return
	_drag["held"]["rotated"] = not bool(_drag["held"].get("rotated", false))
	queue_redraw()


func _pick(cell: Vector2i) -> void:
	var entry = inventory.entry_at(cell)
	if entry.is_empty():
		return
	var taken = inventory.take_at(entry["pos"])
	_drag["held"] = {"id": taken["id"], "count": taken["count"], "rotated": taken.get("rotated", false)}
	_drag["from_inv"] = inventory
	queue_redraw()


func _place(cell: Vector2i) -> void:
	var held: Dictionary = _drag["held"]
	if held.is_empty() or not _held_fits():
		return
	var id := String(held["id"])
	var top := _held_top_left(cell)
	var count := int(held["count"])
	var stack_max := CATALOG.max_stack(id)
	var placed := 0
	while placed < count:
		var stack := mini(stack_max, count - placed)
		var leftover = inventory.add_item(id, stack, top, bool(held.get("rotated", false)))
		placed += stack - leftover
		if leftover > 0:
			break
	if placed < count:
		_drag["held"] = {"id": id, "count": count - placed, "rotated": held.get("rotated", false)}
	else:
		_drag["held"] = {}
		_drag["from_inv"] = null
		_promote_queued()
	queue_redraw()


func _cancel_hold() -> void:
	# Return the held stack to the inventory it came from; a leftover that no
	# longer fits stays in hand instead of being deleted.
	var held: Dictionary = _drag["held"]
	var from = _drag["from_inv"]
	if from == null:
		# No home inventory (a queued stack): cycle it to the back of the
		# queue so the cursor can move on to the next waiting stack.
		var waiting: Array = _drag.get("queued", [])
		waiting.append(held)
		_drag["queued"] = waiting
		_drag["held"] = {}
		_promote_queued()
		queue_redraw()
		return
	var leftover = from.add_item(String(held["id"]), int(held["count"]), Vector2i(-1, -1), bool(held.get("rotated", false)))
	if leftover > 0:
		_drag["held"] = {"id": held["id"], "count": leftover, "rotated": held.get("rotated", false)}
	else:
		_drag["held"] = {}
		_drag["from_inv"] = null
		_promote_queued()
	queue_redraw()


func _quick_transfer(cell: Vector2i) -> void:
	var entry = inventory.entry_at(cell)
	if entry.is_empty():
		return
	var target := _transfer_target(String(entry["id"]))
	if target == null:
		return
	var other = target.get("inventory")
	if other == null:
		return
	var leftover = other.add_item(String(entry["id"]), int(entry["count"]))
	if leftover < int(entry["count"]):
		inventory.take_at(entry["pos"], int(entry["count"]) - leftover)
	queue_redraw()


## Synthetic-input entry point used by headless tests.
func click_cell(cell: Vector2i, button: int = MOUSE_BUTTON_LEFT, ctrl: bool = false) -> void:
	_mouse_cell = cell
	if button == MOUSE_BUTTON_LEFT and ctrl:
		_quick_transfer(cell)
	elif button == MOUSE_BUTTON_LEFT:
		if _drag["held"].is_empty():
			_pick(cell)
		else:
			_place(cell)
	elif button == MOUSE_BUTTON_RIGHT:
		if _drag["held"].is_empty():
			_quick_transfer(cell)
		else:
			_cancel_hold()
	queue_redraw()


func held_item() -> Dictionary:
	return _drag["held"]
