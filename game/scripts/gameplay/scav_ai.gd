extends CharacterBody3D

## Scav 游荡者（白盒敌对环境）——巡逻 → 索敌（视距+视锥+LOS 射线）→
## 追击 → 近距 hitscan 开火。阵亡原地掉落「尸体箱」（loot_crate，scav 表）。
## 遥测：[AI] spawn/alert/fire/die。
##
## 反序列化不持久（每局重新布置）；`setup(spec)` 收 {patrol, hp, dmg, ...}。
## 由 raid_game `set_target(player)` 接线玩家节点。

signal died(scav: Node3D, corpse: Node3D)

const LOOT_CRATE := preload("res://scripts/gameplay/loot_crate.gd")

# --- 数值（普通 scav 档；后续 tier 覆盖） ------------------------------------
var hp := 45.0
var hp_max := 45.0
var speed_patrol := 1.8
var speed_chase := 4.2
var sight_range := 15.0
var sight_cos := 0.5            # cos(60°)：±60° 视锥
var attack_range := 9.0
var fire_interval := 1.2
var damage := 8.0
var hit_chance := 0.5
var loot_table := "scav"
var lose_sight_s := 4.0         # 追击丢失视野后搜索时长

var _patrol: Array = []         # Array[Vector3]
var _patrol_i := 0
var _state := &"patrol"         # patrol / chase / search / dead
var _target: Node3D = null
var _last_seen := Vector3.ZERO
var _lost_t := 0.0
var _search_t := 0.0
var _fire_cd := 0.0
var _grace_t := 0.0            # 出生保护期：玩家未离开出生点 4m 且未开火时完全不可见
var _grace_origin := Vector3.ZERO
var _chase_best := INF         # 追击中距最后目击点的最近纪录（stuck 检测）
var _stuck_t := 0.0
var _facing := Vector3.FORWARD
var _rng := RandomNumberGenerator.new()
var _body: MeshInstance3D = null
var _tracer: MeshInstance3D = null
var _tracer_t := 0.0
var _hit_flash_t := 0.0


## spec: {patrol: Array[Vector3], hp/dmg/sight_range/hit_chance/loot_table 可覆写}
func setup(spec: Dictionary) -> void:
	for p in spec.get("patrol", []):
		_patrol.append(p)
	hp_max = float(spec.get("hp", hp_max))
	hp = hp_max
	damage = float(spec.get("dmg", damage))
	sight_range = float(spec.get("sight_range", sight_range))
	hit_chance = float(spec.get("hit_chance", hit_chance))
	loot_table = String(spec.get("loot_table", loot_table))
	_grace_t = 25.0
	_rng.randomize()
	_build_mesh()
	print("[AI] spawn pos=(%.1f,%.1f) patrol=%d" % [position.x, position.z, _patrol.size()])


func set_target(player: Node3D) -> void:
	_target = player
	_grace_origin = player.global_position  # 玩家出生位——保护期以此为心


## 玩家开火 → 全体敌人立即结束出生保护（raid_game 接线）。
func end_grace() -> void:
	_grace_t = 0.0


func _physics_process(delta: float) -> void:
	if _state == &"dead":
		return
	_fire_cd = maxf(0.0, _fire_cd - delta)
	_grace_t = maxf(0.0, _grace_t - delta)
	var seen := _can_see_target()
	if seen:
		_last_seen = _target.global_position
		_lost_t = 0.0
	match _state:
		&"patrol":
			if seen:
				_alert()
			else:
				_patrol_step(delta)
		&"chase":
			if seen:
				_stuck_t = 0.0
				var dist := _flat_dist(_target.global_position)
				if dist <= attack_range:
					_state = &"attack"
				else:
					_move_toward(_last_seen, speed_chase, delta, 1.2)
			else:
				_lost_t += delta
				var d := _flat_dist(_last_seen)
				if d <= 1.2:
					_state = &"search"
					_search_t = lose_sight_s
				elif d < _chase_best - 0.3:
					# 仍在逼近最后目击点
					_chase_best = d
					_stuck_t = 0.0
					_move_toward(_last_seen, speed_chase, delta)
				else:
					# 掩体挡路走不到目击点：无进展 1.5s 放弃转搜索（review BUG_0004）
					_stuck_t += delta
					if _stuck_t > 1.5:
						_state = &"search"
						_search_t = lose_sight_s
					else:
						_move_toward(_last_seen, speed_chase, delta)
		&"attack":
			if not seen:
				_lost_t += delta
				_state = &"chase"
			elif _flat_dist(_target.global_position) > attack_range + 1.5:
				_state = &"chase"
			else:
				_face(_target.global_position - global_position)
				if _fire_cd <= 0.0:
					_fire()
		&"search":
			if seen:
				_state = &"chase"
				_lost_t = 0.0
			else:
				_search_t -= delta
				# 原地左右扫视（网格朝向同步）
				_facing = _facing.rotated(Vector3.UP, delta * 1.6)
				rotation.y = atan2(-_facing.x, -_facing.z)
				if _search_t <= 0.0:
					_state = &"patrol"


func _process(delta: float) -> void:
	if _tracer_t > 0.0:
		_tracer_t -= delta
		if _tracer_t <= 0.0 and _tracer != null:
			_tracer.visible = false
	if _hit_flash_t > 0.0:
		_hit_flash_t -= delta
		if _hit_flash_t <= 0.0 and _body != null:
			_body.material_override.albedo_color = Color(0.38, 0.42, 0.28)


# --- 感知 -------------------------------------------------------------------

func _can_see_target() -> bool:
	if _target == null or not is_instance_valid(_target):
		return false
	var eye := global_position + Vector3(0, 1.55, 0)
	var tgt := _target.global_position + Vector3(0, 1.2, 0)
	var to := tgt - eye
	# 出生保护判定先于视距/视锥：离开出生区对全体敌人一次性结束（review
	# BUG_0002——原来只在视距内才清标志，远处敌人留着保护，回圈又隐形）。
	if _grace_t > 0.0:
		var from_spawn := _target.global_position - _grace_origin
		from_spawn.y = 0.0
		if from_spawn.length() > 4.0:
			_grace_t = 0.0
		else:
			return false  # 还在出生圈内 → 完全不可见
	var dist := to.length()
	if dist > sight_range:
		return false
	var flat := Vector3(to.x, 0, to.z).normalized()
	if dist > 2.0 and _facing.normalized().dot(flat) < sight_cos:
		return false
	var space := get_world_3d()
	if space == null:
		return false
	var query := PhysicsRayQueryParameters3D.create(eye, tgt)
	query.exclude = [get_rid()]
	var hit := space.direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit["collider"] == _target


func _alert() -> void:
	if _state == &"chase" or _state == &"attack":
		return
	_state = &"chase"
	_lost_t = 0.0
	_chase_best = INF
	_stuck_t = 0.0
	print("[AI] alert pos=(%.1f,%.1f)" % [global_position.x, global_position.z])


# --- 移动 -------------------------------------------------------------------

func _flat_dist(p: Vector3) -> float:
	var d := p - global_position
	d.y = 0.0
	return d.length()


func _face(dir: Vector3) -> void:
	var flat := Vector3(dir.x, 0, dir.z)
	if flat.length_squared() > 0.001:
		_facing = flat.normalized()
		rotation.y = atan2(-_facing.x, -_facing.z)


func _move_toward(p: Vector3, speed: float, _delta: float, min_dist := 0.0) -> void:
	var dir := p - global_position
	dir.y = 0.0
	# 最小接近距离：不再顶进玩家胶囊（贴身会没入相机近平面不可见）。
	if dir.length() <= min_dist or dir.length() < 0.05:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	_face(dir)
	velocity = _facing * speed
	move_and_slide()


func _patrol_step(delta: float) -> void:
	if _patrol.is_empty():
		return
	var wp: Vector3 = _patrol[_patrol_i]
	if _flat_dist(wp) <= 0.6:
		_patrol_i = (_patrol_i + 1) % _patrol.size()
		wp = _patrol[_patrol_i]
	_move_toward(wp, speed_patrol, delta)


# --- 开火与受击 ---------------------------------------------------------------

func _fire() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	_fire_cd = fire_interval
	var eye := global_position + Vector3(0, 1.45, 0)
	var tgt := _target.global_position + Vector3(0, 1.1, 0)
	var hit_roll := _rng.randf() < hit_chance
	_show_tracer(eye, tgt)
	var health = _target.get_node_or_null("Health")
	if hit_roll and health != null and health.has_method("damage"):
		health.damage(damage, "scav")
	print("[AI] fire %s dist=%.1f" % ["hit" if hit_roll else "miss", _flat_dist(_target.global_position)])


func _show_tracer(eye: Vector3, tgt: Vector3) -> void:
	if _tracer == null:
		_tracer = MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.03, 0.03, 1.0)
		_tracer.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.85, 0.3)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.7, 0.2)
		_tracer.material_override = mat
		add_child(_tracer)  # 挂自身：随 scav 一起释放，不依赖 current_scene
	var mid := (eye + tgt) * 0.5
	_tracer.global_position = mid
	_tracer.look_at(tgt, Vector3.UP)
	_tracer.scale = Vector3(1, 1, eye.distance_to(tgt))
	_tracer.visible = true
	_tracer_t = 0.12


## raid_game._fire_from 的命中入口（collider.take_damage）。
func take_damage(dmg: float) -> void:
	if _state == &"dead":
		return
	hp -= dmg
	_hit_flash_t = 0.12
	if _body != null:
		_body.material_override.albedo_color = Color(1.0, 0.6, 0.5)
	if hp <= 0.0:
		_die()
	else:
		# 中弹即警觉并朝射手方向搜索。
		if _target != null and is_instance_valid(_target):
			_last_seen = _target.global_position
		if _state == &"patrol" or _state == &"search":
			_state = &"chase"
			_lost_t = 0.0
			_chase_best = INF
			_stuck_t = 0.0
			print("[AI] alert pos=(%.1f,%.1f) dmg" % [global_position.x, global_position.z])


func _die() -> void:
	_state = &"dead"
	# 倒地姿态；尸体只留视觉不留碰撞——不挡门/不挡 F 交互射线（实机验证：
	# 平躺碰撞板会罩住尸体箱，沿尸体长轴走近时射线永远打中板子）。
	rotation.z = PI * 0.5
	position.y = 0.3
	for child in get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", true)
	# 尸体可搜刮：尸体箱放身体侧旁偏玩家一侧；用 shape 查询依次试
	# 两侧/前后取第一个空位——免得塞建立柱/墙里摸不到（review BUG_0003）。
	var corpse := LOOT_CRATE.new()
	corpse.setup(loot_table, 4, 3, 1.8)
	corpse.build_mesh(Color(0.25, 0.22, 0.18))
	corpse.position = global_position + _corpse_spot() * 0.9
	corpse.position.y = 0.0
	print("[AI] die pos=(%.1f,%.1f) hp=0" % [global_position.x, global_position.z])
	died.emit(self, corpse)


## 尸体箱落位：按「玩家侧→另一侧→前方→后方」试，返回第一个无碰撞的方向；
## 全堵则原地（spawn 挤出来也比埋进墙里好）。
func _corpse_spot() -> Vector3:
	var side := _facing.rotated(Vector3.UP, PI * 0.5)
	if _target != null and is_instance_valid(_target) \
			and side.dot(_target.global_position - global_position) < 0.0:
		side = -side
	var dirs := [side, -side, _facing, -_facing]
	var space := get_world_3d()
	if space == null:
		return side
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.8, 0.5, 0.8)
	for d in dirs:
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = shape
		q.transform = Transform3D(Basis(), global_position + d * 0.9 + Vector3(0, 0.3, 0))
		q.exclude = [get_rid()]
		if space.direct_space_state.intersect_shape(q, 1).is_empty():
			return d
	return Vector3.ZERO


# --- 白盒外观 -----------------------------------------------------------------

func _build_mesh() -> void:
	# 胶囊身体（橄榄绿工作服）+ 深色头 + 胸前弹挂色块。
	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.7
	col.shape = capsule
	col.position.y = 0.85
	add_child(col)
	_body = MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.3
	body_mesh.height = 1.7
	_body.mesh = body_mesh
	_body.position.y = 0.85
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.38, 0.42, 0.28)
	mat.roughness = 0.9
	_body.material_override = mat
	add_child(_body)
	var head := MeshInstance3D.new()
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.28, 0.26, 0.28)
	head.mesh = head_mesh
	head.position = Vector3(0, 1.62, 0)
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(0.5, 0.42, 0.35)
	head.material_override = hmat
	add_child(head)
	var rig := MeshInstance3D.new()
	var rig_mesh := BoxMesh.new()
	rig_mesh.size = Vector3(0.34, 0.3, 0.12)
	rig.mesh = rig_mesh
	rig.position = Vector3(0, 1.05, -0.3)
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.25, 0.22, 0.18)
	rig.material_override = rmat
	add_child(rig)


func state() -> StringName:
	return _state
