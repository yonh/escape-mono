extends "res://scripts/gameplay/interactable.gd"

## 锁区门：白盒金属门扇，F 交互——背包里有 required_item（默认红色钥匙卡）
## 才开门（卡不消耗，类塔科夫钥匙语义）。开门后滑入门楣上方并保持可通行。

const CATALOG := preload("res://scripts/gameplay/item_catalog.gd")
const GAME_STATE := preload("res://scripts/gameplay/game_state.gd")
const SFX := preload("res://scripts/gameplay/sfx_kit.gd")

var required_item := "keycard_red"
var opened := false
var _slab: MeshInstance3D = null
var _col: CollisionShape3D = null
var _open_t := -1.0
var _closed_y := 0.0


func setup(item_id: String = "keycard_red") -> void:
	required_item = item_id
	action = &"locked_door"
	add_to_group("interactable")
	_build()


func display_prompt() -> String:
	if opened:
		return "门已开"
	if GAME_STATE.backpack != null and GAME_STATE.backpack.count_of(required_item) > 0:
		return "刷卡开门（%s）" % CATALOG.item_name(required_item)
	return "上锁的门（需要 %s）" % CATALOG.item_name(required_item)


## raid_game F 分发调用。持卡开门返回 true。
func try_open() -> bool:
	if opened:
		return true
	if GAME_STATE.backpack == null or GAME_STATE.backpack.count_of(required_item) <= 0:
		SFX.play_3d(SFX.stream("sfx_door_denied"), self, Vector3(0, 1.1, 0), -6.0, 15.0)
		print("[DOOR] denied %s" % required_item)
		return false
	opened = true
	_open_t = 0.0
	_closed_y = _slab.position.y
	if _col != null:
		_col.set_deferred("disabled", true)
	SFX.play_3d(SFX.stream("sfx_door_open"), self, Vector3(0, 1.1, 0), -4.0, 20.0)
	print("[DOOR] open %s" % required_item)
	return true


func _process(delta: float) -> void:
	if _open_t < 0.0:
		return
	_open_t += delta
	var t := minf(_open_t / 0.7, 1.0)
	_slab.position.y = _closed_y + t * 2.1
	if t >= 1.0:
		_open_t = -1.0


## 门扇：门洞 1.4w×2.2h 对应 1.5×2.2 金属板（yaw 由摆放 params 给）。
func _build() -> void:
	_col = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.5, 2.2, 0.14)
	_col.shape = box
	_col.position.y = 1.1
	add_child(_col)
	_slab = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box.size
	_slab.mesh = mesh
	_slab.position.y = 1.1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.4, 0.48)
	mat.metallic = 0.6
	mat.roughness = 0.5
	_slab.material_override = mat
	add_child(_slab)
	# 红色警示条
	var stripe := MeshInstance3D.new()
	var stripe_mesh := BoxMesh.new()
	stripe_mesh.size = Vector3(1.5, 0.14, 0.02)
	stripe.mesh = stripe_mesh
	stripe.position = Vector3(0, 1.5, -0.08)
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.7, 0.15, 0.12)
	smat.emission_enabled = true
	smat.emission = Color(0.7, 0.15, 0.12) * 0.6
	stripe.material_override = smat
	add_child(stripe)
