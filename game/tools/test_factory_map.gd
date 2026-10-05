extends SceneTree
## factory_map 数据校验（无渲染）：
##   道具 kind 均注册 · 布局不越界 · 门洞走廊通 · 箱/出生点不压碰撞体
##   撤离点分散 · build() 节点结构 · 区域标签 · raid.tscn 工厂分发冒烟
##   计时文本与 MIA 判负 · 生存屋工厂出发垫。
## 运行: --headless --path . -s res://tools/test_factory_map.gd

const FACTORY_MAP := preload("res://scripts/gameplay/factory_map.gd")
const PROP_KIT := preload("res://scripts/gameplay/prop_kit.gd")
const GAME_STATE := preload("res://scripts/gameplay/game_state.gd")
const RAID_GAME := preload("res://scripts/gameplay/raid_game.gd")
const RAID_SCENE := preload("res://scenes/raid.tscn")
const HIDEOUT_SCENE := preload("res://scenes/hideout.tscn")

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _fail(msg: String) -> void:
	_failures += 1
	printerr("[FAIL] ", msg)


func _run() -> void:
	_check_kinds()
	_check_bounds()
	var root := Node3D.new()
	get_root().add_child(root)
	var built := FACTORY_MAP.build(root, {})
	var props := root.get_node("Props")
	var boxes := _collider_boxes(props)
	_check_door_corridors(boxes)
	_check_spawns_clear(boxes)
	_check_crates_clear(boxes)
	_check_extracts()
	_check_zone_labels()
	_check_ceiling_coverage()
	_check_built_structure(root, props, built, boxes.size())
	_check_clock_fmt()
	await _check_raid_scene()
	await _check_hideout_scene()
	GAME_STATE.raid_map_id = "factory"
	GAME_STATE.raid_plan = {}
	print("[DONE] test_factory_map: %d failure(s)" % _failures)
	quit(1 if _failures > 0 else 0)


## ---- 数据层检查 -------------------------------------------------------

func _check_kinds() -> void:
	for e in FACTORY_MAP.LAYOUT:
		if not PROP_KIT.KINDS.has(e["kind"]):
			_fail("未注册道具类型: %s" % String(e["kind"]))


func _check_bounds() -> void:
	var mn := FACTORY_MAP.MAP_MIN
	var mx := FACTORY_MAP.MAP_MAX
	for e in FACTORY_MAP.LAYOUT:
		var p: Vector3 = e["pos"]
		if p.x < mn.x - 1.0 or p.x > mx.x + 1.0 or p.z < mn.y - 1.0 or p.z > mx.y + 1.0:
			_fail("布局越界: %s @ %s" % [String(e["kind"]), p])
	for sp in FACTORY_MAP.SPAWNS:
		var p: Vector3 = sp["pos"]
		if p.x < mn.x or p.x > mx.x or p.z < mn.y or p.z > mx.y:
			_fail("出生点越界: %s" % p)
	for c in FACTORY_MAP.CRATES:
		var p: Vector3 = c["pos"]
		if p.x < mn.x or p.x > mx.x or p.z < mn.y or p.z > mx.y:
			_fail("物资箱越界: %s" % p)


func _check_door_corridors(boxes: Array) -> void:
	# 每扇 wall_door 的门洞：门宽内 ±0.4、穿墙方向 ±1.6m、胸高 1.0m
	# 采样点不得落在任何道具碰撞体内（lintel 在 2.2m 以上不挡路）。
	for e in FACTORY_MAP.LAYOUT:
		if e["kind"] != &"wall_door":
			continue
		var p: Vector3 = e["pos"]
		var yaw := float(e["params"].get("yaw", 0.0))
		var door_x := float(e["params"].get("door_x", 0.0))
		var basis := Basis.from_euler(Vector3(0, deg_to_rad(yaw), 0))
		for dx in [-0.4, 0.0, 0.4]:
			for dz in [-1.6, 0.0, 1.6]:
				var wpt := p + basis * Vector3(door_x + dx, 1.0, dz)
				if _inside_any(wpt, boxes):
					_fail("门洞走廊被堵: wall_door @ %s 采样 %s" % [p, wpt])


func _check_spawns_clear(boxes: Array) -> void:
	for sp in FACTORY_MAP.SPAWNS:
		var p: Vector3 = sp["pos"]
		for h in [0.3, 1.0, 1.6]:
			if _inside_any(p + Vector3(0, h, 0), boxes):
				_fail("出生点被碰撞体压住: %s (h=%.1f)" % [p, h])


func _check_crates_clear(boxes: Array) -> void:
	for i in FACTORY_MAP.CRATES.size():
		var c: Dictionary = FACTORY_MAP.CRATES[i]
		var p: Vector3 = c["pos"]
		if _inside_any(p + Vector3(0, 0.35, 0), boxes):
			_fail("物资箱 %d 被碰撞体压住: %s" % [i, p])
		for j in i:
			var q: Vector3 = FACTORY_MAP.CRATES[j]["pos"]
			var flat := Vector2(p.x, p.z).distance_to(Vector2(q.x, q.z))
			if flat < 1.0:
				_fail("物资箱 %d/%d 互相重叠: %s / %s" % [i, j, p, q])


func _check_extracts() -> void:
	for i in FACTORY_MAP.EXTRACTS.size():
		var a: Vector3 = FACTORY_MAP.EXTRACTS[i]["pos"]
		for j in i:
			var b: Vector3 = FACTORY_MAP.EXTRACTS[j]["pos"]
			if a.distance_to(b) < 5.0:
				_fail("撤离点过近: %s / %s" % [a, b])


func _check_zone_labels() -> void:
	# (点 → 期望区域名)
	var cases := [
		[Vector3(0, 0, 0), "主车间"],
		[Vector3(12.4, 3.0, 0), "二层平台"],
		[Vector3(-18, 0, -15), "办公室"],
		[Vector3(-5, 0, -15), "会议室"],
		[Vector3(8, 0, -15), "机房"],
		[Vector3(19, 0, -14), "储藏间"],
		[Vector3(-18, 0, -8), "更衣室"],
		[Vector3(-18, 0, 0), "车间"],
		[Vector3(-18, 0, 8), "库房"],
		[Vector3(20, 0, 0), "危险品库"],
		[Vector3(21, 0, 8), "备件间"],
		[Vector3(0, 0, 15), "装卸区"],
		[Vector3(0, 0, -9.6), "走廊"],
	]
	for c in cases:
		var got := FACTORY_MAP.zone_label_at(c[0])
		if got != c[1]:
			_fail("区域标签错误: %s → %s (期望 %s)" % [c[0], got, c[1]])


## 回归（PR#35 review）：厂房内部任何点都必须有吊顶覆盖——
## 逐米网格采样，点不在任何 ceiling 的 xz 矩形内即露天。
## （当前 ceiling 均轴对齐；若引入带 yaw 的吊顶需扩展此处。）
func _check_ceiling_coverage() -> void:
	var rects: Array = []
	for e in FACTORY_MAP.LAYOUT:
		if e["kind"] != &"ceiling":
			continue
		if float(e["params"].get("yaw", 0.0)) != 0.0:
			_fail("ceiling 带 yaw，覆盖检查未支持: %s" % e["pos"])
			continue
		var c: Vector3 = e["pos"]
		var hw := float(e["params"].get("w", 10.0)) * 0.5
		var hd := float(e["params"].get("d", 10.0)) * 0.5
		rects.append(Rect2(c.x - hw, c.z - hd, hw * 2.0, hd * 2.0))
	var misses := []
	var x := FACTORY_MAP.MAP_MIN.x + 0.5
	while x < FACTORY_MAP.MAP_MAX.x:
		var z := FACTORY_MAP.MAP_MIN.y + 0.5
		while z < FACTORY_MAP.MAP_MAX.y:
			var pt := Vector2(x, z)
			var covered := false
			for r in rects:
				if (r as Rect2).has_point(pt):
					covered = true
					break
			if not covered:
				misses.append(pt)
			z += 1.0
		x += 1.0
	if misses.size() > 0:
		_fail("吊顶空洞 %d 处（首个 %s）" % [misses.size(), misses[0]])


func _check_built_structure(root: Node3D, props: Node, built: Dictionary, n_boxes: int) -> void:
	if props.get_child_count() != FACTORY_MAP.LAYOUT.size():
		_fail("Props 数 %d ≠ 布局 %d" % [props.get_child_count(), FACTORY_MAP.LAYOUT.size()])
	if root.get_node("LootCrates").get_child_count() != FACTORY_MAP.CRATES.size():
		_fail("LootCrates 数 ≠ CRATES")
	if root.get_node("Lights").get_child_count() != FACTORY_MAP.LIGHTS.size():
		_fail("Lights 数 ≠ LIGHTS")
	var extracts := 0
	for c in root.get_node("Extracts").get_children():
		if c.is_in_group("interactable") and StringName(c.get("action")) == &"extract":
			extracts += 1
	if extracts != FACTORY_MAP.EXTRACTS.size():
		_fail("撤离垫 %d ≠ EXTRACTS %d" % [extracts, FACTORY_MAP.EXTRACTS.size()])
	if not bool(built.get("indoor", false)):
		_fail("build() 未标记 indoor")
	if String(built.get("map_name", "")) != "工厂":
		_fail("map_name 错误: %s" % built.get("map_name"))
	if n_boxes < 100:
		_fail("碰撞体过少: %d" % n_boxes)
	# 灯具要带发光灯泡（视觉光源）——抽查大厅灯罩下有 emissive 材质
	var found_lamp := false
	for c in props.get_children():
		if c.get_meta("prop_kind", &"") == &"lamp":
			found_lamp = true
	if not found_lamp:
		_fail("缺少 lamp 道具")


func _check_clock_fmt() -> void:
	if RAID_GAME._fmt_left(900.0) != "15:00":
		_fail("_fmt_left(900) ≠ 15:00")
	if RAID_GAME._fmt_left(59.4) != "00:59":
		_fail("_fmt_left(59.4) ≠ 00:59")
	if RAID_GAME._fmt_left(-3.0) != "00:00":
		_fail("_fmt_left(-3) ≠ 00:00")


## ---- 场景冒烟 ---------------------------------------------------------

func _check_raid_scene() -> void:
	GAME_STATE.raid_map_id = "factory"
	GAME_STATE.raid_plan = {}
	var inst := RAID_SCENE.instantiate()
	get_root().add_child(inst)
	await process_frame
	var props := inst.get_node_or_null("Props")
	if props == null or props.get_child_count() < 80:
		_fail("工厂 raid Props 未生成")
	if inst.get_node_or_null("Lights") == null:
		_fail("工厂 raid 无 Lights 组")
	if inst.get("_sun") != null or inst.get("_clock") != null:
		_fail("室内图不应有太阳/昼夜")
	if not is_equal_approx(float(inst.get("_raid_left")), FACTORY_MAP.RAID_SECONDS):
		_fail("raid 计时未初始化: %s" % inst.get("_raid_left"))
	if String(inst.get("_map_name")) != "工厂":
		_fail("_map_name ≠ 工厂")
	inst._process(0.016)
	var clock_lbl: Label = inst.get("_clock_label")
	if clock_lbl == null:
		_fail("HUD 无 _clock_label")
	elif clock_lbl.text.find("剩余时间") < 0:
		_fail("HUD 无倒计时文本: '%s'" % clock_lbl.text)
	# MIA：倒计时归零 → 判负横幅 + dead_timer。
	inst.set("_raid_left", 0.05)
	inst._process(0.1)
	if not bool(inst.get("_dead")):
		_fail("倒计时归零未判负")
	elif String((inst.get("_banner_label") as Label).text).find("MIA") < 0:
		_fail("MIA 横幅缺失: %s" % (inst.get("_banner_label") as Label).text)
	inst.queue_free()
	await process_frame

	# 回归（PR#35 review）：超时与撤离读条同帧归零 → MIA 优先，不能成功撤离。
	var inst2 := RAID_SCENE.instantiate()
	get_root().add_child(inst2)
	await process_frame
	var pad := Node3D.new()
	inst2.add_child(pad)
	pad.global_position = (inst2.get("_player") as Node3D).global_position
	inst2.set("_extract_pad", pad)
	inst2.set("_extract_timer", 0.05)
	inst2.set("_raid_left", 0.05)
	inst2._process(0.1)
	if not bool(inst2.get("_dead")):
		_fail("同帧双归零时撤离抢在 MIA 前结算")
	elif String((inst2.get("_banner_label") as Label).text).find("MIA") < 0:
		_fail("同帧双归零未判 MIA: %s" % (inst2.get("_banner_label") as Label).text)
	inst2.queue_free()
	await process_frame


func _check_hideout_scene() -> void:
	var inst := HIDEOUT_SCENE.instantiate()
	get_root().add_child(inst)
	await process_frame
	var actions := {}
	for n in inst.get_tree().get_nodes_in_group("interactable"):
		actions[StringName(n.get("action"))] = true
	if not actions.has(&"depart_factory"):
		_fail("生存屋缺工厂出发垫")
	inst.queue_free()
	await process_frame


## ---- 碰撞体收集（含任意轴旋转 → 世界 AABB） ------------------------------

func _collider_boxes(root: Node) -> Array:
	var out: Array = []
	_collect(root, out)
	return out


func _collect(n: Node, out: Array) -> void:
	for c in n.get_children():
		_collect(c, out)
	if n is CollisionShape3D and n.shape is BoxShape3D:
		var box: BoxShape3D = n.shape
		var xf: Transform3D = n.global_transform
		var h := box.size * 0.5
		var mn := Vector3(INF, INF, INF)
		var mx := Vector3(-INF, -INF, -INF)
		for i in 8:
			var corner := Vector3(
				h.x if i & 1 else -h.x,
				h.y if i & 2 else -h.y,
				h.z if i & 4 else -h.z)
			var w: Vector3 = xf * corner
			mn = mn.min(w)
			mx = mx.max(w)
		out.append({"min": mn, "max": mx})
	elif n is CollisionShape3D and n.shape is CylinderShape3D:
		var cyl: CylinderShape3D = n.shape
		var c: Vector3 = n.global_position
		out.append({
			"min": c - Vector3(cyl.radius, cyl.height * 0.5, cyl.radius),
			"max": c + Vector3(cyl.radius, cyl.height * 0.5, cyl.radius),
		})


func _inside_any(pt: Vector3, boxes: Array) -> bool:
	for b in boxes:
		var mn: Vector3 = b["min"]
		var mx: Vector3 = b["max"]
		if pt.x >= mn.x and pt.x <= mx.x and pt.y >= mn.y and pt.y <= mx.y \
				and pt.z >= mn.z and pt.z <= mx.z:
			return true
	return false
