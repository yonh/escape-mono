extends "res://scripts/gameplay/interactable.gd"

## Lootable crate for the raid map: a physical interactable holding a
## Searchable plus its own loot grid. Searching once fills the grid;
## items that don't fit stay in `pending` until space frees up.

const SEARCHABLE := preload("res://scripts/gameplay/searchable.gd")
const INVENTORY := preload("res://scripts/gameplay/inventory.gd")
const CATALOG := preload("res://scripts/gameplay/item_catalog.gd")

var inventory: RefCounted
var searchable: Node
var pending: Array = []


func setup(table_id: String, grid_w: int = 4, grid_h: int = 3, search_time: float = 2.5) -> void:
	action = &"loot"
	prompt = "搜索"
	inventory = INVENTORY.new(grid_w, grid_h)
	searchable = SEARCHABLE.new()
	searchable.table_id = table_id
	searchable.search_time = search_time
	searchable.search_finished.connect(_fill)
	add_child(searchable)
	add_to_group("interactable")


func searching() -> bool:
	return searchable != null and searchable.searching()


func searched() -> bool:
	return searchable != null and searchable.looted


func progress() -> float:
	return searchable.progress() if searchable != null else 0.0


func begin_search() -> bool:
	return searchable != null and searchable.begin_search()


func display_prompt() -> String:
	if searching():
		return "搜索中 %.0f%%" % (progress() * 100.0)
	if not pending.is_empty():
		return "打开容器（还有 %d 件未取）" % pending.size()
	return "搜索" if not searched() else "打开容器"


## Rebuild the crate's visual box. Called once after placement.
func build_mesh(color: Color = Color(0.38, 0.32, 0.22)) -> void:
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.9, 0.7, 0.7)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = 0.35
	add_child(col)
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = shape.size
	mesh.mesh = cube
	mesh.position.y = 0.35
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mesh.material_override = mat
	add_child(mesh)


func _fill(items: Array) -> void:
	for item in items:
		var leftover = inventory.add_item(String(item["id"]), int(item["count"]))
		if leftover > 0:
			pending.append({"id": String(item["id"]), "count": leftover})


## Retry pending items once the grid has space. Returns count moved.
## Rotation is part of the parked stack: a rotated item may only fit the
## way it was held, so keep the flag through the drain.
func drain_pending() -> int:
	var kept: Array = []
	var moved := 0
	for item in pending:
		var rotated := bool(item.get("rotated", false))
		var leftover = inventory.add_item(String(item["id"]), int(item["count"]), Vector2i(-1, -1), rotated)
		moved += int(item["count"]) - leftover
		if leftover > 0:
			kept.append({"id": String(item["id"]), "count": leftover, "rotated": rotated})
	pending = kept
	return moved


func item_names() -> Array[String]:
	var names: Array[String] = []
	for entry in inventory.entries():
		names.append("%s x%d" % [CATALOG.item_name(String(entry["id"])), int(entry["count"])])
	return names
