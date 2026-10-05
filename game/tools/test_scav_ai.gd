extends SceneTree

## Scav AI checks: patrol advance, sight cone + LOS aggro, chase→attack→damage,
## death corpse loot, locked door keycard gate.
## godot --headless --path . -s res://tools/test_scav_ai.gd

const SCAV_AI := preload("res://scripts/gameplay/scav_ai.gd")
const HEALTH := preload("res://scripts/gameplay/health.gd")
const LOOT_CRATE := preload("res://scripts/gameplay/loot_crate.gd")
const LOCKED_DOOR := preload("res://scripts/gameplay/locked_door.gd")
const GAME_STATE := preload("res://scripts/gameplay/game_state.gd")
const FACTORY_MAP := preload("res://scripts/gameplay/factory_map.gd")

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)


func _new_scav(pos: Vector3, spec: Dictionary = {}) -> CharacterBody3D:
	var s = SCAV_AI.new()
	root.add_child(s)
	s.position = pos
	s.setup(spec)
	return s


func _new_player(pos: Vector3) -> CharacterBody3D:
	var p := CharacterBody3D.new()
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.31
	cap.height = 1.75
	col.shape = cap
	col.position.y = 0.875
	p.add_child(col)
	var health = HEALTH.new()
	health.name = "Health"
	p.add_child(health)
	root.add_child(p)
	p.position = pos
	return p


## 物理帧推进 n 步（headless 下 SceneTree 仍有 physics）。
func _step(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	# --- 巡逻推进 ---
	var s = _new_scav(Vector3(0, 0, 0), {"patrol": [Vector3(0, 0, 8)]})
	await _step(40)
	_check(s.position.z > 0.5, "scav 未向巡逻点移动: %s" % str(s.position))
	_check(s.state() == &"patrol", "无目标时不在巡逻态")

	# --- 冷静期：>5m 不秒锁 ---
	var calm = _new_scav(Vector3(10, 0, 0), {"patrol": [Vector3(10, 0, 10)]})
	var p1 = _new_player(Vector3(10, 0, -8))  # 距 8m，在移动朝向里
	calm.set_target(p1)
	await _step(30)
	_check(calm.state() == &"patrol", "冷静期内越距索敌")
	calm.free()
	p1.free()

	# --- 正面视锥 + LOS → 追击 ---
	var hunt = _new_scav(Vector3(20, 0, 0), {"patrol": [Vector3(20, 0, 10)], "hit_chance": 1.0})
	var p2 = _new_player(Vector3(20, 0, 6))  # 巡逻朝向前方 6m
	hunt.set_target(p2)
	hunt.set("_calm_t", 0.0)
	await _step(20)
	_check(hunt.state() == &"chase" or hunt.state() == &"attack", "看见玩家未追击: %s" % hunt.state())

	# --- 进入射程开火 → 玩家掉血 ---
	for i in 200:
		await physics_frame
		if hunt.state() == &"attack" and float(hunt.get("_fire_cd")) > 0.0:
			break
	var hp_before: float = p2.get_node("Health").hp
	for i in 120:
		await physics_frame
		if p2.get_node("Health").hp < hp_before:
			break
	_check(p2.get_node("Health").hp < hp_before, "scav 开火未造成伤害")
	hunt.free()

	# --- 背身 + 隔墙不可见 ---
	var blind = _new_scav(Vector3(-10, 0, 0), {"patrol": [Vector3(-10, 0, 10)]})  # 朝 +z
	var p3 = _new_player(Vector3(-10, 0, -6))  # 背后 6m
	blind.set_target(p3)
	blind.set("_calm_t", 0.0)
	await _step(40)
	_check(blind.state() == &"patrol", "背后目标被看见")
	var wall := StaticBody3D.new()
	var wcol := CollisionShape3D.new()
	var wbox := BoxShape3D.new()
	wbox.size = Vector3(10, 4, 0.3)
	wcol.shape = wbox
	wcol.position.y = 2.0
	wall.add_child(wcol)
	root.add_child(wall)
	wall.position = Vector3(-10, 0, -2)
	var front = _new_scav(Vector3(-10, 0, 5), {"patrol": [Vector3(-10, 0, 10)]})  # 朝 +z 背对墙
	var p4 = _new_player(Vector3(-10, 0, -8))  # 墙后
	front.set_target(p4)
	front.set("_calm_t", 0.0)
	await _step(40)
	_check(front.state() == &"patrol", "隔墙看见玩家")
	blind.free()
	front.free()
	p3.free()
	p4.free()
	wall.free()

	# --- 中弹警觉 + 阵亡掉尸体箱 ---
	var dead = _new_scav(Vector3(5, 0, 20), {"patrol": [Vector3(5, 0, 25)]})
	var corpse_holder: Array = []
	dead.died.connect(func(_s, corpse): corpse_holder.append(corpse))
	dead.take_damage(50.0)
	_check(dead.state() == &"dead", "致死伤害未死亡")
	_check(corpse_holder.size() == 1, "死亡未掉落尸体箱")
	var corpse: Node3D = corpse_holder[0]
	_check(corpse.is_in_group("interactable"), "尸体箱不可交互")
	root.add_child(corpse)
	corpse.searchable.search_time = 0.05
	_check(corpse.begin_search(), "尸体箱搜索未启动")
	for i in 20:
		await process_frame
		if corpse.searched():
			break
	_check(corpse.searched(), "尸体箱搜索未结束")
	_check(corpse.inventory.entry_count() + corpse.pending.size() > 0, "尸体箱无战利品")
	dead.free()
	corpse.free()

	# --- 锁门：无卡拒开 / 有卡开门且不再拦路 ---
	GAME_STATE.backpack = null
	GAME_STATE.ensure()
	GAME_STATE.backpack.clear()
	var door = LOCKED_DOOR.new()
	root.add_child(door)
	door.position = Vector3(0, 0, 30)
	door.setup("keycard_red")
	_check(door.display_prompt().contains("需要"), "锁门提示未声明钥匙卡")
	_check(not door.try_open(), "无卡开门成功")
	GAME_STATE.backpack.add_item("keycard_red", 1)
	_check(door.display_prompt().contains("刷卡"), "持卡提示未切换")
	_check(door.try_open(), "持卡开门失败")
	_check(door.opened, "门未标记开启")
	await _step(2)
	var col_done := true
	for child in door.get_children():
		if child is CollisionShape3D and not child.disabled:
			col_done = false
	_check(col_done, "开门后碰撞仍生效")
	_check(GAME_STATE.backpack.count_of("keycard_red") == 1, "钥匙卡被消耗（不应消耗）")
	door.free()

	# --- 巡逻路点都在图内（防穿墙/出界） ---
	for def in FACTORY_MAP.ENEMIES:
		for wp in def["patrol"]:
			var inside: bool = wp.x > FACTORY_MAP.MAP_MIN.x + 0.5 and wp.x < FACTORY_MAP.MAP_MAX.x - 0.5 \
				and wp.z > FACTORY_MAP.MAP_MIN.y + 0.5 and wp.z < FACTORY_MAP.MAP_MAX.y - 0.5
			_check(inside, "巡逻点出界: %s" % str(wp))
		var sp: Vector3 = def["pos"]
		_check(sp.x > FACTORY_MAP.MAP_MIN.x and sp.x < FACTORY_MAP.MAP_MAX.x, "出生点出界: %s" % str(sp))

	print("Scav AI checks: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
