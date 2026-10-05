extends RefCounted

## Tarkov-style grid container: items occupy rectangular cells, stack up to
## their catalog limit, can be rotated, and serialize for stash persistence.
## Entries are dictionaries {id, count, pos, rotated}; `pos` is the top-left
## cell of the (possibly rotated) footprint.

signal changed

const CATALOG := preload("res://scripts/gameplay/item_catalog.gd")

var grid_size: Vector2i
var weight_limit: float = -1.0  # kg; negative means unlimited
## Optional item-kind gate (equipment slots): when set, entries other than
## what the filter accepts can never enter — via drop, add_item or transfer.
var item_filter: Callable = Callable()
var _entries: Array[Dictionary] = []
var _cells: PackedInt32Array  # flattened grid, entry index or -1


func _init(width: int = 8, height: int = 6, max_weight: float = -1.0) -> void:
	grid_size = Vector2i(width, height)
	weight_limit = max_weight
	_cells = PackedInt32Array()
	_cells.resize(width * height)
	_cells.fill(-1)


func entries() -> Array[Dictionary]:
	return _entries.duplicate()


func entry_count() -> int:
	return _entries.size()


func _entry_index_at(pos: Vector2i) -> int:
	if pos.x < 0 or pos.y < 0 or pos.x >= grid_size.x or pos.y >= grid_size.y:
		return -2
	return _cells[pos.y * grid_size.x + pos.x]


## Entry at a cell (empty dict if the cell is free).
func entry_at(pos: Vector2i) -> Dictionary:
	var index := _entry_index_at(pos)
	if index < 0:
		return {}
	return _entries[index]


static func entry_size(entry: Dictionary) -> Vector2i:
	var size: Vector2i = CATALOG.size(String(entry["id"]))
	if entry.get("rotated", false):
		return Vector2i(size.y, size.x)
	return size


func _rect_fits(size: Vector2i, pos: Vector2i, ignore_index: int = -1) -> bool:
	if pos.x < 0 or pos.y < 0 or pos.x + size.x > grid_size.x or pos.y + size.y > grid_size.y:
		return false
	for y in size.y:
		for x in size.x:
			var cell_index: int = _cells[(pos.y + y) * grid_size.x + pos.x + x]
			if cell_index != -1 and cell_index != ignore_index:
				return false
	return true


func _accepts(id: String) -> bool:  # filter gate; public version is accepts()
	return item_filter.is_null() or bool(item_filter.call(id))


## True when the item's rectangle fits at `pos` without overlapping.
func can_place(id: String, pos: Vector2i, ignore_index: int = -1, rotated: bool = false) -> bool:
	if not CATALOG.has(id) or not _accepts(id):
		return false
	var size := CATALOG.size(id)
	if rotated:
		size = Vector2i(size.y, size.x)
	return _rect_fits(size, pos, ignore_index)


## First top-left position where the item fits; (-1,-1) when none.
func find_space(id: String, rotated: bool = false) -> Vector2i:
	var size := CATALOG.size(id)
	if rotated:
		size = Vector2i(size.y, size.x)
	for y in grid_size.y - size.y + 1:
		for x in grid_size.x - size.x + 1:
			var pos := Vector2i(x, y)
			if _rect_fits(size, pos):
				return pos
	return Vector2i(-1, -1)


## Weight currently carried, including stacks.
func total_weight() -> float:
	var total := 0.0
	for entry in _entries:
		total += CATALOG.weight(String(entry["id"])) * float(entry["count"])
	return total


func _weight_room_for(id: String) -> int:
	if weight_limit < 0.0:
		return 1 << 30
	var room := weight_limit - total_weight()
	if room <= 0.0:
		return 0
	return int(floor(room / CATALOG.weight(id)))


## Add `count` units of `id`. Fills existing stacks first, then places new
## stacks at `pos` (or the first free space). Returns the unplaced leftover.
func add_item(id: String, count: int = 1, pos: Vector2i = Vector2i(-1, -1), rotated: bool = false) -> int:
	if count <= 0 or not CATALOG.has(id) or not _accepts(id):
		return count
	var left := count
	var stack_max := CATALOG.max_stack(id)
	if stack_max > 1:
		for i in _entries.size():
			if left <= 0 or _weight_room_for(id) <= 0:
				break
			var entry := _entries[i]
			if String(entry["id"]) != id or int(entry["count"]) >= stack_max:
				continue
			var move := mini(stack_max - int(entry["count"]), left)
			if weight_limit >= 0.0:
				move = mini(move, _weight_room_for(id))
			if move <= 0:
				break
			entry["count"] = int(entry["count"]) + move
			left -= move
	while left > 0 and _weight_room_for(id) > 0:
		var batch := mini(stack_max, left)
		if weight_limit >= 0.0:
			batch = mini(batch, _weight_room_for(id))
			if batch <= 0:
				break
		var place := pos
		if place.x < 0 or not can_place(id, place, -1, rotated):
			place = find_space(id, rotated)
		if place.x < 0:
			break
		_place(id, batch, place, rotated)
		left -= batch
		pos = Vector2i(-1, -1)
	if left != count:
		changed.emit()
	return left


func _place(id: String, count: int, pos: Vector2i, rotated: bool = false) -> void:
	_entries.append({"id": id, "count": count, "pos": pos, "rotated": rotated})
	var index := _entries.size() - 1
	_mark_cells(_entries[index], index)


func _mark_cells(entry: Dictionary, index: int) -> void:
	var pos: Vector2i = entry["pos"]
	var size := entry_size(entry)
	for y in size.y:
		for x in size.x:
			_cells[(pos.y + y) * grid_size.x + pos.x + x] = index


func _clear_cells(entry: Dictionary, index: int, shift_indices: bool) -> void:
	var pos: Vector2i = entry["pos"]
	var size := entry_size(entry)
	for y in size.y:
		for x in size.x:
			_cells[(pos.y + y) * grid_size.x + pos.x + x] = -1
	# cells referencing later entries shift only after array removal
	if shift_indices:
		for i in _cells.size():
			if _cells[i] > index:
				_cells[i] -= 1


## Remove `count` units from the stack at `pos` (default: whole stack).
## Returns the removed portion {id, count, rotated} or {} when empty.
func take_at(pos: Vector2i, count: int = -1) -> Dictionary:
	var index := _entry_index_at(pos)
	if index < 0:
		return {}
	var entry := _entries[index]
	var take := int(entry["count"]) if count < 0 else mini(count, int(entry["count"]))
	var result := {"id": String(entry["id"]), "count": take, "rotated": entry.get("rotated", false)}
	entry["count"] = int(entry["count"]) - take
	if int(entry["count"]) <= 0:
		_clear_cells(entry, index, true)
		_entries.remove_at(index)
	changed.emit()
	return result


## Move the stack at `from` so its top-left cell lands on `to` (the caller
## computes the intended top-left). Returns false when the target is blocked.
func move_entry(from: Vector2i, to: Vector2i, rotated: bool = false) -> bool:
	var index := _entry_index_at(from)
	if index < 0:
		return false
	var entry := _entries[index]
	var id := String(entry["id"])
	if not can_place(id, to, index, rotated):
		return false
	_clear_cells(entry, index, false)
	entry["pos"] = to
	entry["rotated"] = rotated
	_mark_cells(entry, index)
	changed.emit()
	return true


## Split `count` units off the stack at `from` onto `to`. Returns false when
## the stack cannot spare that many or the target is blocked.
func split_stack(from: Vector2i, to: Vector2i, count: int) -> bool:
	var index := _entry_index_at(from)
	if index < 0 or count <= 0 or int(_entries[index]["count"]) <= count:
		return false
	var id := String(_entries[index]["id"])
	var rotated := bool(_entries[index].get("rotated", false))
	if not can_place(id, to, -1, rotated):
		return false
	_entries[index]["count"] = int(_entries[index]["count"]) - count
	_place(id, count, to, rotated)
	changed.emit()
	return true


func count_of(id: String) -> int:
	var total := 0
	for entry in _entries:
		if String(entry["id"]) == id:
			total += int(entry["count"])
	return total


func total_value() -> int:
	var total := 0
	for entry in _entries:
		total += CATALOG.value(String(entry["id"])) * int(entry["count"])
	return total


func is_empty() -> bool:
	return _entries.is_empty()


func serialize() -> Dictionary:
	var items: Array = []
	for entry in _entries:
		items.append({"id": entry["id"], "count": entry["count"], "pos": [entry["pos"].x, entry["pos"].y], "rotated": entry.get("rotated", false)})
	return {"grid": [grid_size.x, grid_size.y], "weight_limit": weight_limit, "items": items}


## Remove every entry and free all cells.
func clear() -> void:
	_entries.clear()
	_cells.fill(-1)
	changed.emit()


## Replace this inventory's contents from a serialize() blob, keeping its
## own grid size and weight cap. Saved positions that no longer fit fall
## back to find_space, then stacking; unplaceable items are returned as
## leftovers (never dropped silently).
func load_data(data: Dictionary) -> Array:
	clear()
	var leftovers := _load_items(data.get("items", []))
	if not leftovers.is_empty():
		push_warning("inventory restore could not place %d item(s)" % leftovers.size())
	changed.emit()
	return leftovers


## Rebuild this grid at a new size/weight cap in place, preserving every
## entry that still fits. Items that cannot fit are returned as
## {id, count, rotated} leftovers for the caller to re-home — never dropped.
func regrid(new_size: Vector2i, new_cap: float) -> Array:
	var data := serialize()
	grid_size = new_size
	weight_limit = new_cap
	_cells = PackedInt32Array()
	_cells.resize(new_size.x * new_size.y)
	_cells.fill(-1)
	_entries.clear()
	var leftovers := _load_items(data.get("items", []))
	changed.emit()
	return leftovers


## Filter gate for UI transfer routing: does this inventory accept the
## item kind at all (item_filter consulted)?
func accepts(id: String) -> bool:
	return _accepts(id)


## Shared restore loop for load_data/regrid: places every saved entry via
## add_item so stacking, the saved position, weight cap and the item filter
## all apply; entries that could not be placed come back as leftovers.
func _load_items(items: Array) -> Array:
	var leftovers: Array = []
	for item in items:
		var id := String(item["id"])
		var pos := Vector2i(int(item["pos"][0]), int(item["pos"][1]))
		var rotated := bool(item.get("rotated", false))
		var left := add_item(id, int(item["count"]), pos, rotated)
		if left > 0:
			leftovers.append({"id": id, "count": left, "rotated": rotated})
	return leftovers


static func deserialize(data: Dictionary) -> RefCounted:
	var grid: Array = data.get("grid", [8, 6])
	var inv: RefCounted = (load("res://scripts/gameplay/inventory.gd") as GDScript).new(int(grid[0]), int(grid[1]), float(data.get("weight_limit", -1.0)))
	for item in data.get("items", []):
		var id := String(item["id"])
		var pos := Vector2i(int(item["pos"][0]), int(item["pos"][1]))
		var rotated := bool(item.get("rotated", false))
		var size := CATALOG.size(id)
		if rotated:
			size = Vector2i(size.y, size.x)
		if inv._rect_fits(size, pos):
			# exact restore: saved layout and partial stacks are preserved
			inv._place(id, int(item["count"]), pos, rotated)
			continue
		# Saved cell blocked: keep the item's own (possibly rotated) footprint
		# before falling back to an unrotated/stacked placement.
		var free = inv.find_space(id, rotated)
		if free.x >= 0:
			inv._place(id, int(item["count"]), free, rotated)
			continue
		var leftover = inv.add_item(id, int(item["count"]))
		if leftover > 0:
			push_warning("inventory restore dropped %d of %s" % [leftover, id])
	return inv
