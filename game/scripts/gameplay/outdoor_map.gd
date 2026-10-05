extends RefCounted

## 外围哨站（野外场）—— 塔科夫"海关/森林"味儿的开阔地图复刻。
## 64×48m 围场：混凝土围墙三处开口（北正门/东路/西缺口=撤离点），
## 场内两间仓库 + 集装箱堆场 + 双哨塔 + 残墙区 + 沙袋阵地散布掩体，
## 树木/岩石/电线杆做地形层次。6 名 scav 拉长巡逻线、视野 20m。
## 与 factory_map 同契约：LAYOUT/CRATES/EXTRACTS/SPAWNS/ENEMIES +
## build(root, plan) → {spawn, spawn_yaw, indoor:false, ...}。

const PROP_KIT := preload("res://scripts/gameplay/prop_kit.gd")
const LOOT_CRATE := preload("res://scripts/gameplay/loot_crate.gd")
const INTERACTABLE := preload("res://scripts/gameplay/interactable.gd")
const SCAV_AI := preload("res://scripts/gameplay/scav_ai.gd")
const UIFONT := preload("res://scripts/gameplay/ui_font.gd")

const MAP_MIN := Vector2(-32, -24)
const MAP_MAX := Vector2(32, 24)
const MAP_NAME := "外围哨站"
const RAID_SECONDS := 600.0


## 区域标签（HUD 左角）。粗粒度 POI 矩形，出界即「开阔地」。
const ZONES := [
	{"id": "wh_a", "label": "西仓库", "rect": Rect2(-24, -19, 11, 10)},
	{"id": "wh_b", "label": "东仓库", "rect": Rect2(13, -18, 10, 11)},
	{"id": "yard", "label": "集装箱堆场", "rect": Rect2(2, -21, 18, 7)},
	{"id": "ruins", "label": "残墙区", "rect": Rect2(-20, 5, 26, 11)},
	{"id": "tower_w", "label": "西哨塔", "rect": Rect2(-27, 5, 6, 7)},
	{"id": "tower_e", "label": "东哨塔", "rect": Rect2(21, 13, 7, 7)},
	{"id": "gate_n", "label": "北正门", "rect": Rect2(-4, -24, 8, 6)},
]


static func zone_label_at(pos: Vector3) -> String:
	for zone in ZONES:
		var r: Rect2 = zone["rect"]
		if r.has_point(Vector2(pos.x, pos.z)):
			return String(zone["label"])
	return "开阔地"


## 布局：{zone, kind, pos, params}。围墙三开口对三撤离垫。
const LAYOUT := [
	# ── 北墙（z=-24）：两段留 2.4m 口（北正门撤离在口内）──
	{"zone": "shell", "kind": &"concrete_wall", "pos": Vector3(-16.8, 0, -24), "params": {"len": 30.4, "h": 3.0}},
	{"zone": "shell", "kind": &"concrete_wall", "pos": Vector3(16.8, 0, -24), "params": {"len": 30.4, "h": 3.0}},
	# ── 南墙（z=24）整段 ──
	{"zone": "shell", "kind": &"concrete_wall", "pos": Vector3(0, 0, 24), "params": {"len": 64, "h": 3.0}},
	# ── 东墙（x=32）：z 2 处开 3m 口（东路撤离）──
	{"zone": "shell", "kind": &"concrete_wall", "pos": Vector3(32, 0, -11.9), "params": {"len": 24.2, "h": 3.0, "yaw": 90}},
	{"zone": "shell", "kind": &"concrete_wall", "pos": Vector3(32, 0, 13.9), "params": {"len": 20.2, "h": 3.0, "yaw": 90}},
	# ── 西墙（x=-32）：z 18 处开 3m 口（西缺口撤离）──
	{"zone": "shell", "kind": &"concrete_wall", "pos": Vector3(-32, 0, -3.6), "params": {"len": 40.8, "h": 3.0, "yaw": 90}},
	{"zone": "shell", "kind": &"concrete_wall", "pos": Vector3(-32, 0, 21.9), "params": {"len": 4.2, "h": 3.0, "yaw": 90}},

	# ── 建筑 ──
	{"zone": "wh_a", "kind": &"warehouse", "pos": Vector3(-18, 0, -14), "params": {"w": 10, "d": 8, "h": 4.5}},
	{"zone": "wh_b", "kind": &"warehouse", "pos": Vector3(18, 0, -12), "params": {"w": 8, "d": 10, "h": 4.5}},
	{"zone": "gate_n", "kind": &"guard_booth", "pos": Vector3(3.2, 0, -20.5), "params": {"yaw": 180}},
	{"zone": "tower_w", "kind": &"watchtower", "pos": Vector3(-24, 0, 8)},
	{"zone": "tower_e", "kind": &"watchtower", "pos": Vector3(24, 0, 16)},

	# ── 集装箱堆场 ──
	{"zone": "yard", "kind": &"container", "pos": Vector3(6, 0, -18), "params": {"yaw": 0}},
	{"zone": "yard", "kind": &"container", "pos": Vector3(11.2, 0, -18), "params": {"yaw": 0, "color": Color(0.5, 0.32, 0.22)}},
	{"zone": "yard", "kind": &"container", "pos": Vector3(16.4, 0, -18), "params": {"yaw": 0, "color": Color(0.3, 0.42, 0.38)}},

	# ── 残墙区（中心掩体带）──
	{"zone": "ruins", "kind": &"ruins_wall", "pos": Vector3(0, 0, 8), "params": {"len": 8, "yaw": 0}},
	{"zone": "ruins", "kind": &"ruins_wall", "pos": Vector3(-16, 0, 12), "params": {"len": 6, "yaw": 25}},
	{"zone": "ruins", "kind": &"ruins_wall", "pos": Vector3(6, 0, 10), "params": {"len": 5, "yaw": -60}},

	# ── 沙袋阵地 ──
	{"zone": "mid", "kind": &"sandbags", "pos": Vector3(-8, 0, 0), "params": {"len": 4, "yaw": 15}},
	{"zone": "mid", "kind": &"sandbags", "pos": Vector3(8, 0, 4), "params": {"len": 4, "yaw": -30}},
	{"zone": "mid", "kind": &"sandbags", "pos": Vector3(-2, 0, -8), "params": {"len": 3, "yaw": 80}},
	{"zone": "mid", "kind": &"sandbags", "pos": Vector3(14, 0, -2), "params": {"len": 3, "yaw": 10}},
	{"zone": "mid", "kind": &"sandbags", "pos": Vector3(0, 0, -14), "params": {"len": 4, "yaw": 0}},

	# ── 岩石/树木/杂物 ──
	{"zone": "mid", "kind": &"rock", "pos": Vector3(-14, 0, -4), "params": {"scale": 1.4}},
	{"zone": "mid", "kind": &"rock", "pos": Vector3(20, 0, 6), "params": {"scale": 1.1}},
	{"zone": "mid", "kind": &"rock", "pos": Vector3(-26, 0, -18), "params": {"scale": 1.2}},
	{"zone": "mid", "kind": &"rock", "pos": Vector3(4, 0, -6), "params": {"scale": 0.9}},
	{"zone": "mid", "kind": &"tree", "pos": Vector3(-28, 0, -20), "params": {"scale": 1.3}},
	{"zone": "mid", "kind": &"tree", "pos": Vector3(-28, 0, 16), "params": {"scale": 1.1}},
	{"zone": "mid", "kind": &"tree", "pos": Vector3(28, 0, -18), "params": {"scale": 1.2}},
	{"zone": "mid", "kind": &"tree", "pos": Vector3(8, 0, 18), "params": {"scale": 1.4}},
	{"zone": "mid", "kind": &"tree", "pos": Vector3(16, 0, 14), "params": {"scale": 1.0}},
	{"zone": "mid", "kind": &"tree", "pos": Vector3(-4, 0, 20), "params": {"scale": 1.2}},
	{"zone": "mid", "kind": &"tree", "pos": Vector3(-22, 0, -2), "params": {"scale": 1.1}},
	{"zone": "mid", "kind": &"tree", "pos": Vector3(12, 0, -8), "params": {"scale": 0.9}},
	{"zone": "mid", "kind": &"hay_bale", "pos": Vector3(14, 0, 10)},
	{"zone": "mid", "kind": &"hay_bale", "pos": Vector3(-6, 0, 16), "params": {"yaw": 45}},

	# ── 电线杆沿路（东侧）──
	{"zone": "edge", "kind": &"power_pole", "pos": Vector3(28, 0, -16)},
	{"zone": "edge", "kind": &"power_pole", "pos": Vector3(28, 0, -4)},
	{"zone": "edge", "kind": &"power_pole", "pos": Vector3(28, 0, 8)},

	# ── 西缺口反坦克桩 ──
	{"zone": "edge", "kind": &"tank_trap", "pos": Vector3(-27, 0, 4)},
	{"zone": "edge", "kind": &"tank_trap", "pos": Vector3(-27, 0, 8)},
]


## 战利品箱：仓库/堆场密，野外疏。
const CRATES := [
	{"table": "cache", "pos": Vector3(-20.5, 0, -16), "color": Color(0.3, 0.38, 0.22)},
	{"table": "toolbox", "pos": Vector3(-16, 0, -11.5), "color": Color(0.32, 0.32, 0.36)},
	{"table": "food", "pos": Vector3(19.5, 0, -15), "color": Color(0.42, 0.36, 0.2)},
	{"table": "cache", "pos": Vector3(16, 0, -9), "color": Color(0.3, 0.38, 0.22)},
	{"table": "cache", "pos": Vector3(11.2, 0, -16.4), "color": Color(0.3, 0.38, 0.22)},
	{"table": "valuable", "pos": Vector3(3.2, 0, -20.4), "color": Color(0.5, 0.4, 0.15)},
	{"table": "toolbox", "pos": Vector3(-24.5, 0, 9.5), "color": Color(0.32, 0.32, 0.36)},
	{"table": "medkit", "pos": Vector3(-8.5, 0, 1.6), "color": Color(0.55, 0.25, 0.2)},
	{"table": "cache", "pos": Vector3(0, 0, 8.8), "color": Color(0.3, 0.38, 0.22)},
	{"table": "food", "pos": Vector3(22, 0, 12), "color": Color(0.42, 0.36, 0.2)},
	{"table": "scav", "pos": Vector3(-14, 0, 13.5), "color": Color(0.4, 0.36, 0.3)},
]


## 撤离点：对应围墙三开口。
const EXTRACTS := [
	{"label": "北正门 NORTH GATE", "pos": Vector3(0, 0, -22.5)},
	{"label": "东路 EAST ROAD", "pos": Vector3(30.5, 0, 2)},
	{"label": "西缺口 WEST BREACH", "pos": Vector3(-30.5, 0, 18)},
]


## 出生点：南侧三角，背南面北开局（yaw 0=-Z 朝场内）。
const SPAWNS := [
	{"pos": Vector3(-26, 0.05, 20), "yaw": -45.0},
	{"pos": Vector3(26, 0.05, 20), "yaw": 45.0},
	{"pos": Vector3(0, 0.05, 21), "yaw": 0.0},
]


## 6 名 scav：视野 20m 配开阔场，巡逻线沿大道/掩体带。
const ENEMIES := [
	{"pos": Vector3(-24, 0, -6), "patrol": [Vector3(-24, 0, -16), Vector3(-24, 0, 4)], "spec": {"sight_range": 20.0}},
	{"pos": Vector3(4, 0, -18), "patrol": [Vector3(-6, 0, -18), Vector3(12, 0, -18)], "spec": {"sight_range": 20.0}},
	{"pos": Vector3(0, 0, 6), "patrol": [Vector3(-6, 0, 8), Vector3(8, 0, 8), Vector3(8, 0, -2), Vector3(-6, 0, -2)], "spec": {"sight_range": 20.0}},
	{"pos": Vector3(14, 0, -14), "patrol": [Vector3(8, 0, -14), Vector3(22, 0, -14)], "spec": {"sight_range": 20.0}},
	{"pos": Vector3(-10, 0, 12), "patrol": [Vector3(-12, 0, 12), Vector3(6, 0, 12)], "spec": {"sight_range": 20.0}},
	{"pos": Vector3(24, 0, 6), "patrol": [Vector3(24, 0, 0), Vector3(24, 0, 10)], "spec": {"sight_range": 20.0}},
]


static func pick_spawn(plan: Dictionary) -> Dictionary:
	var idx := int(plan.get("spawn_idx", -1))
	if idx >= 0 and idx < SPAWNS.size():
		return SPAWNS[idx]
	return SPAWNS[randi() % SPAWNS.size()]


## 搭整张哨站图进 root。plan 只取 spawn_idx。
static func build(root: Node3D, plan: Dictionary = {}) -> Dictionary:
	_ground(root)
	var props := Node3D.new()
	props.name = "Props"
	root.add_child(props)
	for def in LAYOUT:
		var p := PROP_KIT.spawn(def["kind"], def.get("params", {}))
		if p != null:
			p.position = def["pos"]
			props.add_child(p, true)
	var crates := Node3D.new()
	crates.name = "LootCrates"
	root.add_child(crates)
	for def in CRATES:
		var crate := LOOT_CRATE.new()
		crate.position = def["pos"]
		crate.setup(String(def["table"]))
		crate.build_mesh(def["color"])
		crates.add_child(crate)
	var extracts := Node3D.new()
	extracts.name = "Extracts"
	root.add_child(extracts)
	for def in EXTRACTS:
		extracts.add_child(_extract_pad(String(def["label"]), def["pos"]))
	var enemies := Node3D.new()
	enemies.name = "Enemies"
	root.add_child(enemies)
	for def in ENEMIES:
		var scav: Node3D = SCAV_AI.new()
		scav.position = def["pos"]
		enemies.add_child(scav)
		var spec: Dictionary = def.get("spec", {}).duplicate()
		spec["patrol"] = def["patrol"]
		scav.setup(spec)
	var spawn: Dictionary = pick_spawn(plan)
	return {
		"crates": crates,
		"extracts": extracts,
		"spawn": spawn["pos"],
		"spawn_yaw": deg_to_rad(float(spawn["yaw"])),
		"indoor": false,
		"map_name": MAP_NAME,
	}


## 泥草混合地表（地面碰撞 + 贴图地面）。
static func _ground(root: Node3D) -> void:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(MAP_MAX.x - MAP_MIN.x + 16, 0.4, MAP_MAX.y - MAP_MIN.y + 16)
	col.shape = shape
	col.position = Vector3(0, -0.2, 0)
	body.add_child(col)
	root.add_child(body)
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(MAP_MAX.x - MAP_MIN.x + 16, MAP_MAX.y - MAP_MIN.y + 16)
	mesh.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.58, 0.45)  # 草泥色调制
	mat.albedo_texture = load("res://assets/texture/ground_dirt.png")
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3(0.18, 0.18, 0.18)  # 野外大砖 ~5.6m
	mat.roughness = 0.95
	mesh.material_override = mat
	mesh.position.y = 0.001
	root.add_child(mesh)


static func _extract_pad(label: String, pos: Vector3) -> Node3D:
	var pad := INTERACTABLE.new()
	pad.prompt = "开始撤离（%s，8 秒）" % label
	pad.action = &"extract"
	pad.add_to_group("interactable")
	pad.position = pos
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.4, 0.5, 2.4)
	col.shape = shape
	col.position.y = 0.25
	pad.add_child(col)
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = Vector3(2.4, 0.12, 2.4)
	mesh.mesh = cube
	mesh.position.y = 0.06
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.6, 0.12)
	mat.emission_enabled = true
	mat.emission = Color(0.75, 0.6, 0.12) * 0.5
	mesh.material_override = mat
	pad.add_child(mesh)
	var l := Label3D.new()
	l.text = label
	l.font = UIFONT.font()
	l.position = Vector3(0, 1.3, 0)
	l.font_size = 48
	l.pixel_size = 0.01
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = Color(1.0, 0.85, 0.3)
	pad.add_child(l)
	return pad
