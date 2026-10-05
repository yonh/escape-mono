extends Node3D

## 生存屋 (hideout): a small walkable base interior. F interacts with the
## storage box (opens linked 仓库/背包 grids, mouse released) and the
## loadout bench, and the departure pad (enters the factory raid).
## Stash + backpack live in GameState so they survive the scene switch.

const PLAYER_SCRIPT := preload("res://scripts/fps_controller.gd")
const INTERACTABLE := preload("res://scripts/gameplay/interactable.gd")
const GAME_STATE := preload("res://scripts/gameplay/game_state.gd")
const EQUIPMENT := preload("res://scripts/gameplay/equipment.gd")
const INVENTORY_UI := preload("res://scripts/gameplay/inventory_ui.gd")
const UIFONT := preload("res://scripts/gameplay/ui_font.gd")

const RAID_SCENE := "res://scenes/raid.tscn"
const REACH := 2.8

var _player: CharacterBody3D
var _prompt_label: Label
var _stash_layer: CanvasLayer
var _stash_panels: Array = []
var _depart_label: Label
var _departing := false


func _ready() -> void:
	GAME_STATE.ensure()
	if not GAME_STATE.stash.changed.is_connected(_on_stash_changed):
		GAME_STATE.stash.changed.connect(_on_stash_changed)
	_seed_stash_first_run()
	_build_room()
	_build_player()
	_build_hud()


func _seed_stash_first_run() -> void:
	# A fresh profile starts with a small starter kit in the stash.
	if GAME_STATE.stash.is_empty() and GAME_STATE.backpack.is_empty() and GAME_STATE.raids_departed == 0:
		GAME_STATE.stash.add_item("bandage", 3)
		GAME_STATE.stash.add_item("canned_beef", 2)
		GAME_STATE.stash.add_item("ammo_9x18", 16)
		GAME_STATE.stash.add_item("ak74", 1)
		GAME_STATE.stash.add_item("light_armor", 1)
		GAME_STATE.stash.add_item("scout_bag", 1)
		GAME_STATE.backpack.add_item("pm_pistol", 1)


func _process(_delta: float) -> void:
	var target := _interact_target()
	_prompt_label.text = "[F] %s" % String(target.get("prompt")) if target != null else ""
	if Engine.get_process_frames() % 10 == 0 and _player != null:
		print("[NAV] pos=(%.1f,%.1f) yaw=%.2f pitch=%.2f target=%s" % [
			_player.global_position.x, _player.global_position.z, _player.rotation.y,
			_player.get_node("Camera3D").rotation.x,
			String(target.get("prompt")) if target != null else "-"])


func _unhandled_input(event: InputEvent) -> void:
	if _departing:
		return
	if _stash_layer != null:
		# Stash UI open: F/Esc closes it and recaptures the mouse.
		if event is InputEventKey and event.pressed and not event.echo \
				and event.keycode in [KEY_F, KEY_ESCAPE]:
			_close_stash()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		var target := _interact_target()
		if target == null:
			return
		print("[INTERACT] %s | %s" % [target.get("action"), String(target.get("prompt"))])
		match StringName(target.get("action")):
			&"stash":
				_open_stash()
			&"equip":
				_open_equipment()
			&"depart_factory":
				_depart()


func _interact_target() -> Node3D:
	if _player == null:
		return null
	var cam: Camera3D = _player.get_node("Camera3D")
	var from := cam.global_position
	var to := from + -cam.global_basis.z * REACH
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var body = hit.get("collider")
	return body if body != null and body.is_in_group("interactable") else null


func _open_stash() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_player.frozen = true
	_stash_layer = CanvasLayer.new()
	_stash_layer.layer = 50
	add_child(_stash_layer)
	var stash_ui := INVENTORY_UI.new()
	stash_ui.position = Vector2(80, 150)
	_stash_layer.add_child(stash_ui)
	stash_ui.setup(GAME_STATE.stash, "仓库 STASH")
	_stash_panels.append(stash_ui)
	var pack_ui := INVENTORY_UI.new()
	pack_ui.position = Vector2(560, 150)
	_stash_layer.add_child(pack_ui)
	pack_ui.setup(GAME_STATE.backpack, "背包 BACKPACK")
	_stash_panels.append(pack_ui)
	stash_ui.link(pack_ui)
	_restore_cursor_load()
	var hint := Label.new()
	hint.text = "拖拽或右键转移物资（背包限重 40kg）。F/Esc 关闭。"
	hint.position = Vector2(80, 640)
	UIFONT.apply(hint, 15)
	_stash_layer.add_child(hint)


## 装备台面板: 仓库 + 四个槽位(主武器/副武器/护甲/背包) + 背包，
## 与仓库共享拖拽组——从仓库把装备拖进对应槽位。
func _open_equipment() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_player.frozen = true
	_stash_layer = CanvasLayer.new()
	_stash_layer.layer = 50
	add_child(_stash_layer)
	var stash_ui := INVENTORY_UI.new()
	stash_ui.position = Vector2(60, 300)
	_stash_layer.add_child(stash_ui)
	stash_ui.setup(GAME_STATE.stash, "仓库 STASH")
	_stash_panels.append(stash_ui)
	var pack_ui := INVENTORY_UI.new()
	pack_ui.position = Vector2(560, 300)
	_stash_layer.add_child(pack_ui)
	pack_ui.setup(GAME_STATE.backpack, "背包 BACKPACK")
	_stash_panels.append(pack_ui)
	stash_ui.link(pack_ui)
	var x := 60.0
	for slot in EQUIPMENT.SLOTS:
		var slot_ui := INVENTORY_UI.new()
		slot_ui.position = Vector2(x, 60)
		_stash_layer.add_child(slot_ui)
		slot_ui.setup(GAME_STATE.loadout_invs[slot], String(EQUIPMENT.SLOT_NAMES[slot]))
		_stash_panels.append(slot_ui)
		stash_ui.link(slot_ui)
		x += 40.0 + EQUIPMENT.slot_dims(slot).x * 40.0
	_restore_cursor_load()
	var hint := Label.new()
	hint.text = "从仓库拖拽装备到对应槽位（武器/护甲/背包）。F/Esc 关闭。"
	hint.position = Vector2(60, 640)
	UIFONT.apply(hint, 15)
	_stash_layer.add_child(hint)


func _close_stash() -> void:
	_release_held_loot()
	_stash_layer.queue_free()
	_stash_layer = null
	_stash_panels.clear()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_player.frozen = false
	_player.set("_capture_grace", 0.15)


## Cursor load must outlive the stash view: a stack already out of its
## grid returns to a home inventory, then the stash, and stays in-hand
## (raid_pending) if nothing can take it — never deleted with the panels.
func _release_held_loot() -> void:
	if _stash_panels.is_empty():
		return
	var drag: Dictionary = _stash_panels[0].get("_drag")
	var stacks: Array = []
	var held: Dictionary = drag.get("held", {})
	if not held.is_empty():
		stacks.append(held)
	stacks.append_array(drag.get("queued", []))
	drag["held"] = {}
	drag["queued"] = []
	var from_inv = drag.get("from_inv")
	drag["from_inv"] = null
	for stack in stacks:
		var leftover := int(stack["count"])
		var homes: Array = []
		if from_inv != null:
			homes.append(from_inv)
		for p in _stash_panels:
			var inv = p.get("inventory")
			if inv != null and not homes.has(inv):
				homes.append(inv)
		for inv in homes:
			leftover = inv.add_item(String(stack["id"]), leftover, Vector2i(-1, -1), bool(stack.get("rotated", false)))
			if leftover <= 0:
				break
		if leftover > 0:
			GAME_STATE.raid_pending.append({"id": stack["id"], "count": leftover, "rotated": stack.get("rotated", false)})


## In-hand stacks ride back onto the cursor next time the stash opens.
func _restore_cursor_load() -> void:
	if GAME_STATE.raid_pending.is_empty() or _stash_panels.is_empty():
		return
	var drag: Dictionary = _stash_panels[0].get("_drag")
	var waiting: Array = drag.get("queued", [])
	waiting.append_array(GAME_STATE.raid_pending)
	drag["queued"] = waiting
	GAME_STATE.raid_pending.clear()
	_stash_panels[0].call("_promote_queued")


## stash.changed 即座に補充すると _pick の take_at→held 設定の間に抜かれる。
## 1 フレーム遅延させ、ドラッグ状態が確定してから判定する。
func _on_stash_changed() -> void:
	call_deferred(&"_drain_stash_if_idle")


## 仓库腾位就把 stash_pending 的排队物补回去 —— 但拖拽中不动：取物腾出的
## 格子随时可能被放回取消，抢先补队会把持物挤成无家可归（进 raid_pending
## 阵亡会丢）。
func _drain_stash_if_idle() -> void:
	if not _stash_panels.is_empty():
		var drag: Dictionary = _stash_panels[0].get("_drag")
		if not drag.get("held", {}).is_empty():
			return
	GAME_STATE.drain_stash_pending()


func _depart() -> void:
	if _departing:
		return
	_departing = true
	print("[DEPART] map=factory")
	GAME_STATE.raid_map_id = "factory"
	GAME_STATE.pack_for_raid()  # 背包格子按装备的背包品目收放，放不下回仓库
	_player.frozen = true
	GAME_STATE.raid_plan = {"source": "factory"}
	GAME_STATE.raids_departed += 1  # 出发计 departed；completed 只由撤离加
	get_tree().change_scene_to_file(RAID_SCENE)


# --- room construction -------------------------------------------------------

func _build_room() -> void:
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.55, 0.52, 0.46)
	wall_mat.roughness = 0.9
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.32, 0.30, 0.26)
	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.45, 0.33, 0.20)

	# Room is 12 wide x 10 deep x 3.2 high, centered on origin, floor at y=0.
	_box("Floor", Vector3(12, 0.2, 10), Vector3(0, -0.1, 0), floor_mat)
	_box("Ceiling", Vector3(12, 0.2, 10), Vector3(0, 3.2, 0), wall_mat)
	_box("WallN", Vector3(12, 3.2, 0.2), Vector3(0, 1.6, -5), wall_mat)
	_box("WallS", Vector3(12, 3.2, 0.2), Vector3(0, 1.6, 5), wall_mat)
	_box("WallW", Vector3(0.2, 3.2, 10), Vector3(-6, 1.6, 0), wall_mat)
	_box("WallE", Vector3(0.2, 3.2, 10), Vector3(6, 1.6, 0), wall_mat)

	# Furniture: table, crate stack, bedroll — props only.
	_box("Table", Vector3(2.0, 0.1, 1.0), Vector3(-3.5, 0.85, -3.5), wood_mat)
	for off in [Vector3(-0.9, 0, -0.4), Vector3(0.9, 0, -0.4), Vector3(-0.9, 0, 0.4), Vector3(0.9, 0, 0.4)]:
		_box("TableLeg", Vector3(0.1, 0.8, 0.1), Vector3(-3.5, 0.4, -3.5) + off, wood_mat)
	_box("Crate1", Vector3(0.9, 0.9, 0.9), Vector3(4.5, 0.45, -4.0), wood_mat)
	_box("Crate2", Vector3(0.7, 0.7, 0.7), Vector3(4.4, 1.25, -3.9), wood_mat)
	_box("Bedroll", Vector3(2.2, 0.15, 0.9), Vector3(-4.5, 0.08, 3.5), wall_mat)

	# Storage box — opens the stash UI.
	var stash_body := INTERACTABLE.new()
	stash_body.prompt = "打开储物箱"
	stash_body.action = &"stash"
	stash_body.add_to_group("interactable")
	stash_body.position = Vector3(3.6, 0.45, 3.8)
	var box_col := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(1.3, 0.9, 0.9)
	box_col.shape = box_shape
	stash_body.add_child(box_col)
	var box_mesh := MeshInstance3D.new()
	var box_cube := BoxMesh.new()
	box_cube.size = Vector3(1.3, 0.9, 0.9)
	box_mesh.mesh = box_cube
	var box_mat := StandardMaterial3D.new()
	box_mat.albedo_color = Color(0.30, 0.42, 0.28)
	box_mesh.material_override = box_mat
	stash_body.add_child(box_mesh)
	add_child(stash_body)
	_label3d("储物箱 STASH", Vector3(3.6, 1.3, 3.8), Color(0.7, 0.9, 0.7))

	# Equipment bench — opens the loadout UI.
	var bench_body := INTERACTABLE.new()
	bench_body.prompt = "打开装备台"
	bench_body.action = &"equip"
	bench_body.add_to_group("interactable")
	bench_body.position = Vector3(-4.7, 0.45, 0.6)
	var bench_col := CollisionShape3D.new()
	var bench_shape := BoxShape3D.new()
	bench_shape.size = Vector3(1.9, 0.9, 0.8)
	bench_col.shape = bench_shape
	bench_body.add_child(bench_col)
	var bench_mesh := MeshInstance3D.new()
	var bench_cube := BoxMesh.new()
	bench_cube.size = Vector3(1.9, 0.12, 0.8)
	bench_mesh.mesh = bench_cube
	var bench_mat := StandardMaterial3D.new()
	bench_mat.albedo_color = Color(0.5, 0.38, 0.24)
	bench_mesh.material_override = bench_mat
	bench_body.add_child(bench_mesh)
	for off in [Vector3(-0.8, -0.45, -0.3), Vector3(0.8, -0.45, -0.3), Vector3(-0.8, -0.45, 0.3), Vector3(0.8, -0.45, 0.3)]:
		var leg := MeshInstance3D.new()
		var leg_cube := BoxMesh.new()
		leg_cube.size = Vector3(0.1, 0.9, 0.1)
		leg.mesh = leg_cube
		leg.position = off
		leg.material_override = bench_mat
		bench_body.add_child(leg)
	add_child(bench_body)
	_label3d("装备台 LOADOUT", Vector3(-4.7, 1.3, 0.6), Color(0.75, 0.85, 1.0))

	# Departure pad —— 工厂（室内 CQB）当前唯一图。
	for pad_def in [
		{"x": 0.0, "prompt": "出发前往工厂（室内）", "action": &"depart_factory", "label": "出发 DEPART → 工厂"},
	]:
		var pad_body := INTERACTABLE.new()
		pad_body.prompt = String(pad_def["prompt"])
		pad_body.action = pad_def["action"]
		pad_body.add_to_group("interactable")
		pad_body.position = Vector3(float(pad_def["x"]), 0.05, -4.2)
		var pad_col := CollisionShape3D.new()
		var pad_shape := BoxShape3D.new()
		pad_shape.size = Vector3(1.8, 0.5, 1.4)
		pad_col.shape = pad_shape
		pad_body.add_child(pad_col)
		var pad_mesh := MeshInstance3D.new()
		var pad_cube := BoxMesh.new()
		pad_cube.size = Vector3(1.8, 0.1, 1.4)
		pad_mesh.mesh = pad_cube
		var pad_mat := StandardMaterial3D.new()
		pad_mat.albedo_color = Color(0.55, 0.5, 0.35)
		pad_mesh.material_override = pad_mat
		pad_body.add_child(pad_mesh)
		add_child(pad_body)
		_label3d(String(pad_def["label"]), Vector3(float(pad_def["x"]), 0.6, -4.2), Color(0.95, 0.8, 0.3))

	# Warm interior lights.
	for pos in [Vector3(-3, 2.9, 0), Vector3(3, 2.9, 0)]:
		var light := OmniLight3D.new()
		light.position = pos
		light.light_color = Color(1.0, 0.85, 0.6)
		light.light_energy = 1.1
		light.omni_range = 9.0
		add_child(light)


func _box(name: String, size: Vector3, pos: Vector3, mat: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name
	body.position = pos
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = size
	mesh.mesh = cube
	mesh.material_override = mat
	body.add_child(mesh)
	add_child(body)
	return body


func _label3d(text: String, pos: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = pos
	label.modulate = color
	label.font_size = 48
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)


func _build_player() -> void:
	_player = CharacterBody3D.new()
	_player.name = "Player"
	_player.set_script(PLAYER_SCRIPT)
	_player.position = Vector3(0, 0.04, 2.5)
	_player.rotation.y = PI  # face the departure pad
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.31
	capsule.height = 1.75
	collision.shape = capsule
	collision.position.y = 0.875
	_player.add_child(collision)
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.position.y = 1.64
	camera.fov = 62.0
	camera.far = 60.0
	camera.current = true
	_player.add_child(camera)
	add_child(_player)
	# No weapon in the hideout — LMB clicks only recapture the cursor.


func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var hud := Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Full-rect HUD must let mouse events through to _unhandled_input —
	# STOP here would eat every motion/click and kill mouse look.
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(hud)
	_prompt_label = Label.new()
	_prompt_label.position = Vector2(-80, 30)
	_prompt_label.set_anchors_preset(Control.PRESET_CENTER)
	_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIFONT.apply(_prompt_label, 18)
	hud.add_child(_prompt_label)
	var help := Label.new()
	help.text = "WASD 移动 | F 交互 | Esc 释放鼠标"
	help.position = Vector2(20, 20)
	help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIFONT.apply(help, 14)
	hud.add_child(help)
	_depart_label = Label.new()
	_depart_label.text = "生存屋 HIDEOUT"
	_depart_label.position = Vector2(20, 44)
	_depart_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIFONT.apply(_depart_label, 14)
	hud.add_child(_depart_label)
