extends SceneTree
## 性能预算检查：建图耗时 + 场景节点/灯光/碰撞体数量上限。
## headless 无法测 GPU 帧率，但节点数与 build_ms 直接决定运行时负载——
## 预算按当前地图实测余量设定，地图扩张劣化即 FAIL。
##
## cd game && timeout 120 "$HOME/godot47/..." --headless --path . -s res://tools/test_perf.gd

const FACTORY_MAP := preload("res://scripts/gameplay/factory_map.gd")
const GAME_STATE := preload("res://scripts/gameplay/game_state.gd")

# 预算（实测 mesh=715 / lights=25 / bodies=172 / build=9ms，各留 ~60% 余量）
const BUDGET := {
	"mesh_nodes": 1150,
	"lights": 40,
	"physics_bodies": 280,
	"build_ms": 400,
}

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("[FAIL] ", msg)


func _count(node: Node, cls: String) -> int:
	var n := 1 if node.is_class(cls) else 0
	for c in node.get_children():
		n += _count(c, cls)
	return n


func _run() -> void:
	GAME_STATE.ensure()
	var root := Node3D.new()
	get_root().add_child(root)

	var t0 := Time.get_ticks_msec()
	FACTORY_MAP.build(root, {"seed": 7})
	var build_ms := Time.get_ticks_msec() - t0

	var meshes := _count(root, "MeshInstance3D")
	var lights := _count(root, "Light3D")
	var bodies := _count(root, "PhysicsBody3D")
	print("[PERF] build_ms=%d mesh=%d lights=%d bodies=%d" % [build_ms, meshes, lights, bodies])

	_check(meshes <= int(BUDGET["mesh_nodes"]),
		"mesh=%d 超预算 %d" % [meshes, BUDGET["mesh_nodes"]])
	_check(lights <= int(BUDGET["lights"]),
		"lights=%d 超预算 %d" % [lights, BUDGET["lights"]])
	_check(bodies <= int(BUDGET["physics_bodies"]),
		"bodies=%d 超预算 %d" % [bodies, BUDGET["physics_bodies"]])
	_check(build_ms <= int(BUDGET["build_ms"]),
		"build_ms=%d 超预算 %d" % [build_ms, BUDGET["build_ms"]])

	print("[DONE] test_perf: %d failure(s)" % _failures)
	quit(0 if _failures == 0 else 1)
