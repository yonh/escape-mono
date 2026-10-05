extends RefCounted

const UIFONT := preload("res://scripts/gameplay/ui_font.gd")

## 白盒素材库 Whitebox prop kit — standard-named placeholder props for map
## layout. Every prop is procedural geometry with a consistent color code,
## so maps can be designed now and real assets swapped in later by name.
##
## Usage: var p = PROPKIT.spawn(&"house", {"size": Vector3(6,3,5)}) — a
## Node3D (usually a StaticBody3D) named "prop_house" with collision.
## Convention docs: docs/props-library.md

## Color coding (whitebox convention, also documented in props-library.md):
const PAL := {
	"structure": Color(0.55, 0.55, 0.58),  # 混凝土/墙体 gray
	"wood": Color(0.45, 0.33, 0.20),       # 木制品 brown
	"metal": Color(0.30, 0.32, 0.36),      # 金属件 dark gray-blue
	"vegetation": Color(0.32, 0.45, 0.26), # 植被 green
	"ground_cover": Color(0.38, 0.34, 0.24),
	"asphalt": Color(0.16, 0.16, 0.17),    # 路面
	"marking": Color(0.85, 0.75, 0.3),     # 标识/撤离 gold
	"hazard": Color(0.7, 0.25, 0.2),       # 危险/军事 red-ish
	"canvas": Color(0.45, 0.48, 0.36),     # 帐篷/布料 olive
	"rock": Color(0.42, 0.40, 0.36),
	"vehicle": Color(0.35, 0.38, 0.42),
}

static var _mats: Dictionary = {}
static var _texmats: Dictionary = {}


static func _mat(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.9
		_mats[key] = m
	return _mats[key]


## 贴图材质：world-triplanar——纹素密度按世界坐标，任意尺寸的 BoxMesh
## 不用管 UV，4m 一砖。缓存按 (color, tex) 复用。
static func _tex_mat(color: Color, tex_file: String) -> StandardMaterial3D:
	var key := color.to_html() + "|" + tex_file
	if not _texmats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.albedo_texture = load("res://assets/texture/" + tex_file)
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3(0.25, 0.25, 0.25)  # 256px 砖 ≈ 4m
		m.roughness = 0.9
		_texmats[key] = m
	return _texmats[key]


static func _mesh_node(mesh: Mesh, color: Color, pos: Vector3, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color)
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _mesh_node_mat(mesh: Mesh, mat: Material, pos: Vector3, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _mesh_node(m, color, pos, parent)


static func _box_tex(parent: Node3D, size: Vector3, pos: Vector3, color: Color, tex_file: String) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _mesh_node_mat(m, _tex_mat(color, tex_file), pos, parent)


static func _col_box(parent: Node3D, size: Vector3, pos: Vector3) -> void:
	var col := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	col.shape = s
	col.position = pos
	parent.add_child(col)


static func _col_cyl(parent: Node3D, radius: float, height: float, pos: Vector3) -> void:
	var col := CollisionShape3D.new()
	var s := CylinderShape3D.new()
	s.radius = radius
	s.height = height
	col.shape = s
	col.position = pos
	parent.add_child(col)


## All available whitebox prop kinds (standard names).
const KINDS: Array[StringName] = [
	&"wall", &"house", &"warehouse", &"fence", &"concrete_wall", &"barrier",
	&"sandbags", &"watchtower", &"stairs", &"crate_stack", &"barrel", &"table",
	&"shelf", &"container", &"vehicle", &"tent", &"pipe", &"sign",
	&"tree", &"bush", &"rock", &"road", &"plaza", &"ruins_wall",
	&"log", &"rubble", &"tank_trap", &"guard_booth", &"power_pole",
	&"concrete_block", &"scrap_pile", &"hay_bale", &"well",
	# 工厂/室内件（feat/factory-map）
	&"pillar", &"wall_door", &"ceiling", &"machine", &"tank", &"catwalk",
	&"ramp", &"railing", &"locker", &"duct", &"beam", &"lamp",
	&"rollup_door", &"forklift", &"floor_mark",
]


## Spawn a prop by kind. `params` keys differ per kind; common:
##   size Vector3, yaw float (deg).
## Returns the prop root (StaticBody3D or Node3D) named prop_<kind>.
static func spawn(kind: StringName, params: Dictionary = {}) -> Node3D:
	var p: Node3D = null
	match kind:
		&"wall": p = _prop_wall(params)
		&"house": p = _prop_house(params)
		&"warehouse": p = _prop_warehouse(params)
		&"fence": p = _prop_fence(params)
		&"concrete_wall": p = _prop_concrete_wall(params)
		&"barrier": p = _prop_barrier(params)
		&"sandbags": p = _prop_sandbags(params)
		&"watchtower": p = _prop_watchtower(params)
		&"stairs": p = _prop_stairs(params)
		&"crate_stack": p = _prop_crate_stack(params)
		&"barrel": p = _prop_barrel(params)
		&"table": p = _prop_table(params)
		&"shelf": p = _prop_shelf(params)
		&"container": p = _prop_container(params)
		&"vehicle": p = _prop_vehicle(params)
		&"tent": p = _prop_tent(params)
		&"pipe": p = _prop_pipe(params)
		&"sign": p = _prop_sign(params)
		&"tree": p = _prop_tree(params)
		&"bush": p = _prop_bush(params)
		&"rock": p = _prop_rock(params)
		&"road": p = _prop_road(params)
		&"plaza": p = _prop_plaza(params)
		&"ruins_wall": p = _prop_ruins_wall(params)
		&"log": p = _prop_log(params)
		&"rubble": p = _prop_rubble(params)
		&"tank_trap": p = _prop_tank_trap(params)
		&"guard_booth": p = _prop_guard_booth(params)
		&"power_pole": p = _prop_power_pole(params)
		&"concrete_block": p = _prop_concrete_block(params)
		&"scrap_pile": p = _prop_scrap_pile(params)
		&"hay_bale": p = _prop_hay_bale(params)
		&"well": p = _prop_well(params)
		&"pillar": p = _prop_pillar(params)
		&"wall_door": p = _prop_wall_door(params)
		&"ceiling": p = _prop_ceiling(params)
		&"machine": p = _prop_machine(params)
		&"tank": p = _prop_tank(params)
		&"catwalk": p = _prop_catwalk(params)
		&"ramp": p = _prop_ramp(params)
		&"railing": p = _prop_railing(params)
		&"locker": p = _prop_locker(params)
		&"duct": p = _prop_duct(params)
		&"beam": p = _prop_beam(params)
		&"lamp": p = _prop_lamp(params)
		&"rollup_door": p = _prop_rollup_door(params)
		&"forklift": p = _prop_forklift(params)
		&"floor_mark": p = _prop_floor_mark(params)
	if p == null:
		push_error("prop_kit: unknown prop kind '%s'" % kind)
		return null
	p.name = "prop_" + String(kind)
	p.set_meta("prop_kind", String(kind))
	return p


static func kinds() -> Array[StringName]:
	return KINDS.duplicate()


static func _yaw(p: Node3D, params: Dictionary) -> void:
	p.rotation_degrees.y = float(params.get("yaw", 0.0))


# --- structures ---------------------------------------------------------------

## wall: a single wall slab. params: size (default 4x3x0.2), yaw
static func _prop_wall(params: Dictionary) -> Node3D:
	var size: Vector3 = params.get("size", Vector3(4.0, 3.0, 0.2))
	var p := StaticBody3D.new()
	_box(p, size, Vector3(0, size.y * 0.5, 0), PAL["structure"])
	_col_box(p, size, Vector3(0, size.y * 0.5, 0))
	_yaw(p, params)
	return p


## house: four walls with a door gap on the south side + flat roof.
## params: w,d (footprint), h, yaw, color
static func _prop_house(params: Dictionary) -> Node3D:
	var w := float(params.get("w", 7.0))
	var d := float(params.get("d", 6.0))
	var h := float(params.get("h", 3.0))
	var t := 0.25
	var door_w := 1.4
	var door_h := 2.2
	var color: Color = params.get("color", PAL["structure"])
	var p := StaticBody3D.new()
	# north wall
	_box(p, Vector3(w, h, t), Vector3(0, h * 0.5, -d * 0.5), color)
	_col_box(p, Vector3(w, h, t), Vector3(0, h * 0.5, -d * 0.5))
	# south wall: two segments leaving a door gap centered
	var seg := (w - door_w) * 0.5
	for sx in [-1.0, 1.0]:
		var off = sx * (door_w * 0.5 + seg * 0.5)
		_box(p, Vector3(seg, h, t), Vector3(off, h * 0.5, d * 0.5), color)
		_col_box(p, Vector3(seg, h, t), Vector3(off, h * 0.5, d * 0.5))
	# lintel above the door
	_box(p, Vector3(door_w, h - door_h, t), Vector3(0, door_h + (h - door_h) * 0.5, d * 0.5), color)
	# side walls
	for sx in [-1.0, 1.0]:
		_box(p, Vector3(t, h, d), Vector3(sx * w * 0.5, h * 0.5, 0), color)
		_col_box(p, Vector3(t, h, d), Vector3(sx * w * 0.5, h * 0.5, 0))
	# roof slab
	_box(p, Vector3(w + 0.4, 0.15, d + 0.4), Vector3(0, h + 0.08, 0), PAL["metal"])
	_yaw(p, params)
	return p


## warehouse: big open shed — tall walls, flat roof, both short ends open.
## params: w,d,h, yaw
static func _prop_warehouse(params: Dictionary) -> Node3D:
	var w := float(params.get("w", 14.0))
	var d := float(params.get("d", 20.0))
	var h := float(params.get("h", 6.0))
	var t := 0.3
	var p := StaticBody3D.new()
	for sz in [-1.0, 1.0]:
		_box(p, Vector3(t, h, d), Vector3(sz * w * 0.5, h * 0.5, 0), PAL["metal"])
		_col_box(p, Vector3(t, h, d), Vector3(sz * w * 0.5, h * 0.5, 0))
	# back wall (north) solid, front (south) has a 6m door gap
	_box(p, Vector3(w, h, t), Vector3(0, h * 0.5, -d * 0.5), PAL["metal"])
	_col_box(p, Vector3(w, h, t), Vector3(0, h * 0.5, -d * 0.5))
	var door_w := 6.0
	var seg := (w - door_w) * 0.5
	for sx in [-1.0, 1.0]:
		var off = sx * (door_w * 0.5 + seg * 0.5)
		_box(p, Vector3(seg, h, t), Vector3(off, h * 0.5, d * 0.5), PAL["metal"])
		_col_box(p, Vector3(seg, h, t), Vector3(off, h * 0.5, d * 0.5))
	_box(p, Vector3(door_w, 1.2, t), Vector3(0, h - 0.6, d * 0.5), PAL["metal"])
	_box(p, Vector3(w + 0.6, 0.2, d + 0.6), Vector3(0, h + 0.1, 0), PAL["structure"])
	_yaw(p, params)
	return p


## fence: a rail fence run. params: len, yaw
static func _prop_fence(params: Dictionary) -> Node3D:
	var len := float(params.get("len", 6.0))
	var p := StaticBody3D.new()
	var posts := int(len / 2.0) + 1
	for i in posts:
		var x := -len * 0.5 + i * (len / float(posts - 1))
		_box(p, Vector3(0.12, 1.1, 0.12), Vector3(x, 0.55, 0), PAL["wood"])
	for y in [0.45, 0.9]:
		_box(p, Vector3(len, 0.08, 0.06), Vector3(0, y, 0), PAL["wood"])
	_col_box(p, Vector3(len, 1.1, 0.15), Vector3(0, 0.55, 0))
	_yaw(p, params)
	return p


## concrete_wall: perimeter block. params: len, h, yaw
static func _prop_concrete_wall(params: Dictionary) -> Node3D:
	var len := float(params.get("len", 8.0))
	var h := float(params.get("h", 2.6))
	var p := StaticBody3D.new()
	_box_tex(p, Vector3(len, h, 0.35), Vector3(0, h * 0.5, 0), PAL["structure"], "wall_concrete.png")
	_col_box(p, Vector3(len, h, 0.35), Vector3(0, h * 0.5, 0))
	_yaw(p, params)
	return p


## barrier: jersey-style low barrier. params: yaw
static func _prop_barrier(params: Dictionary) -> Node3D:
	var p := StaticBody3D.new()
	_box(p, Vector3(2.4, 0.5, 0.6), Vector3(0, 0.25, 0), PAL["structure"])
	_box(p, Vector3(2.4, 0.45, 0.32), Vector3(0, 0.72, 0), PAL["structure"])
	_col_box(p, Vector3(2.4, 0.95, 0.6), Vector3(0, 0.48, 0))
	_yaw(p, params)
	return p


## sandbags: low sandbag wall segment. params: len, yaw
static func _prop_sandbags(params: Dictionary) -> Node3D:
	var len := float(params.get("len", 3.0))
	var p := StaticBody3D.new()
	for i in 3:
		_box(p, Vector3(len, 0.28, 0.5 - i * 0.1), Vector3(0, 0.14 + i * 0.27, 0), PAL["canvas"])
	_col_box(p, Vector3(len, 0.85, 0.5), Vector3(0, 0.42, 0))
	_yaw(p, params)
	return p


## watchtower: 4 legs + cabin platform. params: yaw
static func _prop_watchtower(params: Dictionary) -> Node3D:
	var p := StaticBody3D.new()
	for off in [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(-1, 0, 1), Vector3(1, 0, 1)]:
		_box(p, Vector3(0.18, 4.4, 0.18), Vector3(off.x, 2.2, off.z), PAL["wood"])
		_col_box(p, Vector3(0.18, 4.4, 0.18), Vector3(off.x, 2.2, off.z))
	_box(p, Vector3(3.0, 0.15, 3.0), Vector3(0, 4.4, 0), PAL["wood"])
	_box(p, Vector3(3.0, 0.9, 0.1), Vector3(0, 5.0, 1.45), PAL["wood"])
	_box(p, Vector3(3.0, 0.9, 0.1), Vector3(0, 5.0, -1.45), PAL["wood"])
	_box(p, Vector3(0.1, 0.9, 3.0), Vector3(1.45, 5.0, 0), PAL["wood"])
	_box(p, Vector3(0.1, 0.9, 3.0), Vector3(-1.45, 5.0, 0), PAL["wood"])
	_box(p, Vector3(3.4, 0.12, 3.4), Vector3(0, 5.9, 0), PAL["metal"])
	_col_box(p, Vector3(3.0, 0.15, 3.0), Vector3(0, 4.4, 0))
	_yaw(p, params)
	return p


## stairs: 3-step climbable block. params: yaw
static func _prop_stairs(params: Dictionary) -> Node3D:
	var p := StaticBody3D.new()
	for i in 3:
		var h := 0.35 * (i + 1)
		_box(p, Vector3(1.4, h, 0.45), Vector3(0, h * 0.5, -0.45 * i + 0.45), PAL["structure"])
		_col_box(p, Vector3(1.4, h, 0.45), Vector3(0, h * 0.5, -0.45 * i + 0.45))
	_yaw(p, params)
	return p


# --- furniture / cover --------------------------------------------------------

## crate_stack: pile of wooden boxes (cover/decor). params: yaw
static func _prop_crate_stack(params: Dictionary) -> Node3D:
	var p := StaticBody3D.new()
	var defs := [
		[Vector3(0, 0.45, 0), 0.9], [Vector3(1.0, 0.45, 0.1), 0.9],
		[Vector3(0.45, 1.3, 0.05), 0.8], [Vector3(-0.55, 0.35, 0.5), 0.7],
	]
	for def in defs:
		var s: float = def[1]
		_box(p, Vector3(s, s, s), def[0], PAL["wood"])
		_col_box(p, Vector3(s, s, s), def[0])
	_yaw(p, params)
	return p


## barrel: fuel drum. params: yaw, color
static func _prop_barrel(params: Dictionary) -> Node3D:
	var p := StaticBody3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.3
	c.bottom_radius = 0.3
	c.height = 0.9
	_mesh_node(c, params.get("color", PAL["hazard"]), Vector3(0, 0.45, 0), p)
	_col_cyl(p, 0.3, 0.9, Vector3(0, 0.45, 0))
	_yaw(p, params)
	return p


## table: work table. params: yaw
static func _prop_table(params: Dictionary) -> Node3D:
	var p := StaticBody3D.new()
	_box(p, Vector3(1.8, 0.1, 0.9), Vector3(0, 0.8, 0), PAL["wood"])
	for off in [Vector3(-0.75, 0, -0.35), Vector3(0.75, 0, -0.35), Vector3(-0.75, 0, 0.35), Vector3(0.75, 0, 0.35)]:
		_box(p, Vector3(0.1, 0.8, 0.1), Vector3(off.x, 0.4, off.z), PAL["wood"])
	_col_box(p, Vector3(1.8, 0.9, 0.9), Vector3(0, 0.45, 0))
	_yaw(p, params)
	return p


## shelf: warehouse shelf — two uprights + three boards. params: yaw
static func _prop_shelf(params: Dictionary) -> Node3D:
	var p := StaticBody3D.new()
	for sx in [-1.0, 1.0]:
		_box(p, Vector3(0.1, 2.2, 0.5), Vector3(sx * 0.95, 1.1, 0), PAL["metal"])
	for y in [0.5, 1.2, 1.9]:
		_box(p, Vector3(2.0, 0.06, 0.5), Vector3(0, y, 0), PAL["metal"])
	_col_box(p, Vector3(2.0, 2.2, 0.5), Vector3(0, 1.1, 0))
	_yaw(p, params)
	return p


## container: shipping container. params: yaw, color
static func _prop_container(params: Dictionary) -> Node3D:
	var size := Vector3(6.0, 2.6, 2.5)
	var p := StaticBody3D.new()
	_box(p, size, Vector3(0, size.y * 0.5, 0), params.get("color", PAL["metal"]))
	_col_box(p, size, Vector3(0, size.y * 0.5, 0))
	_yaw(p, params)
	return p


## vehicle: derelict car. params: yaw, color
static func _prop_vehicle(params: Dictionary) -> Node3D:
	var p := StaticBody3D.new()
	var color: Color = params.get("color", PAL["vehicle"])
	_box(p, Vector3(4.0, 0.7, 1.8), Vector3(0, 0.55, 0), color)
	_box(p, Vector3(2.0, 0.55, 1.6), Vector3(-0.3, 1.15, 0), color)
	for off in [Vector3(-1.3, 0, -0.85), Vector3(1.3, 0, -0.85), Vector3(-1.3, 0, 0.85), Vector3(1.3, 0, 0.85)]:
		var w := CylinderMesh.new()
		w.top_radius = 0.32
		w.bottom_radius = 0.32
		w.height = 0.22
		var mi := _mesh_node(w, PAL["asphalt"], Vector3(off.x, 0.32, off.z), p)
		mi.rotation_degrees.x = 90.0
	_col_box(p, Vector3(4.0, 1.5, 1.8), Vector3(0, 0.75, 0))
	_yaw(p, params)
	return p


## tent: small ridge tent. params: yaw
static func _prop_tent(params: Dictionary) -> Node3D:
	var p := StaticBody3D.new()
	for sx in [-1.0, 1.0]:
		var m := _box(p, Vector3(2.4, 0.08, 2.0), Vector3(sx * 0.72, 0.85, 0), PAL["canvas"])
		m.rotation_degrees.z = sx * 55.0
	_box(p, Vector3(0.15, 0.15, 2.0), Vector3(0, 1.55, 0), PAL["canvas"])
	_col_box(p, Vector3(2.2, 1.6, 2.0), Vector3(0, 0.8, 0))
	_yaw(p, params)
	return p


## pipe: horizontal industrial pipe. params: len, yaw
static func _prop_pipe(params: Dictionary) -> Node3D:
	var len := float(params.get("len", 4.0))
	var p := StaticBody3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.35
	c.bottom_radius = 0.35
	c.height = len
	var mi := _mesh_node(c, PAL["metal"], Vector3(0, 0.35, 0), p)
	mi.rotation_degrees.z = 90.0
	_col_box(p, Vector3(len, 0.7, 0.7), Vector3(0, 0.35, 0))
	_yaw(p, params)
	return p


## sign: pole + board. params: text, yaw
static func _prop_sign(params: Dictionary) -> Node3D:
	var p := StaticBody3D.new()
	var pole := CylinderMesh.new()
	pole.top_radius = 0.05
	pole.bottom_radius = 0.05
	pole.height = 2.4
	_mesh_node(pole, PAL["metal"], Vector3(0, 1.2, 0), p)
	_box(p, Vector3(1.4, 0.8, 0.06), Vector3(0, 2.1, 0), PAL["marking"])
	_col_box(p, Vector3(1.4, 0.8, 0.1), Vector3(0, 2.1, 0))
	var text := String(params.get("text", ""))
	if not text.is_empty():
		var l := Label3D.new()
		l.text = text
		l.font = UIFONT.font()
		l.position = Vector3(0, 2.1, 0.05)
		l.font_size = 32
		l.pixel_size = 0.01
		l.modulate = Color(0.1, 0.1, 0.1)
		p.add_child(l)
	_yaw(p, params)
	return p


# --- nature -------------------------------------------------------------------

## tree: trunk + crown. params: yaw, scale
static func _prop_tree(params: Dictionary) -> Node3D:
	var s := float(params.get("scale", 1.0))
	var p := StaticBody3D.new()
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.12 * s
	trunk.bottom_radius = 0.18 * s
	trunk.height = 2.4 * s
	_mesh_node(trunk, PAL["wood"], Vector3(0, 1.2 * s, 0), p)
	var crown := SphereMesh.new()
	crown.radius = 1.3 * s
	crown.height = 2.6 * s
	_mesh_node(crown, PAL["vegetation"], Vector3(0, 2.4 * s + 1.0 * s, 0), p)
	_col_cyl(p, 0.18 * s, 2.4 * s, Vector3(0, 1.2 * s, 0))
	_yaw(p, params)
	return p


## bush: low shrub clump. params: yaw
static func _prop_bush(params: Dictionary) -> Node3D:
	var p := Node3D.new()
	var m := SphereMesh.new()
	m.radius = 0.7
	m.height = 1.1
	var mi := _mesh_node(m, PAL["vegetation"], Vector3(0, 0.4, 0), p)
	mi.scale = Vector3(1.2, 1.0, 1.2)
	_yaw(p, params)
	return p


## rock: boulder. params: scale, yaw
static func _prop_rock(params: Dictionary) -> Node3D:
	var s := float(params.get("scale", 1.0))
	var p := StaticBody3D.new()
	var m := SphereMesh.new()
	m.radius = 1.0
	m.height = 1.6
	var mi := _mesh_node(m, PAL["rock"], Vector3(0, 0.5 * s, 0), p)
	mi.scale = Vector3(1.4 * s, 0.8 * s, 1.1 * s)
	_col_box(p, Vector3(2.0 * s, 1.0 * s, 1.6 * s), Vector3(0, 0.5 * s, 0))
	_yaw(p, params)
	return p


# --- ground pieces ------------------------------------------------------------

## road: flat asphalt slab. params: len, w, yaw
static func _prop_road(params: Dictionary) -> Node3D:
	var len := float(params.get("len", 20.0))
	var w := float(params.get("w", 5.0))
	var p := Node3D.new()
	_box(p, Vector3(w, 0.04, len), Vector3(0, 0.02, 0), PAL["asphalt"])
	# center dashes
	var dashes := int(len / 4.0)
	for i in dashes:
		var z := -len * 0.5 + 2.0 + i * 4.0
		_box(p, Vector3(0.25, 0.05, 1.6), Vector3(0, 0.035, z), PAL["marking"])
	_yaw(p, params)
	return p


## plaza: flat concrete pad (house foundation / yard). params: w,d,yaw
static func _prop_plaza(params: Dictionary) -> Node3D:
	var w := float(params.get("w", 8.0))
	var d := float(params.get("d", 8.0))
	var p := Node3D.new()
	_box(p, Vector3(w, 0.05, d), Vector3(0, 0.025, 0), PAL["ground_cover"])
	_yaw(p, params)
	return p


## ruins_wall: broken wall — height drops along its length. params: len, yaw
static func _prop_ruins_wall(params: Dictionary) -> Node3D:
	var len := float(params.get("len", 6.0))
	var p := StaticBody3D.new()
	var segs := 4
	var seg_len := len / segs
	var heights := [2.4, 1.6, 2.0, 0.9]
	for i in segs:
		var h: float = heights[i % heights.size()]
		var x := -len * 0.5 + seg_len * (i + 0.5)
		_box(p, Vector3(seg_len, h, 0.3), Vector3(x, h * 0.5, 0), PAL["structure"])
		_col_box(p, Vector3(seg_len, h, 0.3), Vector3(x, h * 0.5, 0))
	_yaw(p, params)
	return p


# --- obstacles / dressing (map detail pass) ------------------------------------

## log: fallen tree trunk lying on the ground. params: len, yaw
static func _prop_log(params: Dictionary) -> Node3D:
	var len := float(params.get("len", 4.0))
	var p := StaticBody3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.3
	c.bottom_radius = 0.38
	c.height = len
	var mi := _mesh_node(c, PAL["wood"], Vector3(0, 0.35, 0), p)
	mi.rotation_degrees.z = 90.0
	_col_box(p, Vector3(len, 0.7, 0.7), Vector3(0, 0.35, 0))
	_yaw(p, params)
	return p


## rubble: irregular debris mound. params: scale, yaw
static func _prop_rubble(params: Dictionary) -> Node3D:
	var s := float(params.get("scale", 1.0))
	var p := StaticBody3D.new()
	var chunks := [
		[Vector3(0, 0.35, 0), Vector3(2.2, 0.9, 1.8)],
		[Vector3(0.8, 0.9, -0.4), Vector3(1.1, 0.7, 1.0)],
		[Vector3(-0.7, 0.8, 0.5), Vector3(0.9, 0.6, 0.9)],
	]
	for chunk in chunks:
		var pos: Vector3 = chunk[0] * s
		var size: Vector3 = chunk[1] * s
		var yaw_deg := randf_range(-15.0, 15.0)
		var m := _box(p, size, pos, PAL["rock"])
		m.rotation_degrees.y = yaw_deg
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		col.shape = shape
		col.position = pos
		col.rotation_degrees.y = yaw_deg
		p.add_child(col)
	_yaw(p, params)
	return p


## tank_trap: steel hedgehog anti-tank obstacle. params: yaw
static func _prop_tank_trap(params: Dictionary) -> Node3D:
	var p := StaticBody3D.new()
	for rot in [Vector3(0, 0, 45), Vector3(90, 0, 45), Vector3(45, 90, 0)]:
		var beam := _box(p, Vector3(0.18, 2.2, 0.18), Vector3(0, 0.8, 0), PAL["metal"])
		beam.rotation_degrees = rot
	_col_box(p, Vector3(1.4, 1.6, 1.4), Vector3(0, 0.8, 0))
	_yaw(p, params)
	return p


## guard_booth: small checkpoint hut with door gap. params: yaw
static func _prop_guard_booth(params: Dictionary) -> Node3D:
	var p := StaticBody3D.new()
	var w := 2.4
	var d := 2.4
	var h := 2.5
	var t := 0.15
	_box(p, Vector3(w, h, t), Vector3(0, h * 0.5, -d * 0.5), PAL["canvas"])
	_col_box(p, Vector3(w, h, t), Vector3(0, h * 0.5, -d * 0.5))
	for sx in [-1.0, 1.0]:
		_box(p, Vector3(t, h, d), Vector3(sx * w * 0.5, h * 0.5, 0), PAL["canvas"])
		_col_box(p, Vector3(t, h, d), Vector3(sx * w * 0.5, h * 0.5, 0))
	var seg := (w - 1.1) * 0.5
	for sx in [-1.0, 1.0]:
		var off := float(sx) * (1.1 * 0.5 + seg * 0.5)
		_box(p, Vector3(seg, h, t), Vector3(off, h * 0.5, d * 0.5), PAL["canvas"])
		_col_box(p, Vector3(seg, h, t), Vector3(off, h * 0.5, d * 0.5))
	_box(p, Vector3(w + 0.3, 0.12, d + 0.3), Vector3(0, h + 0.06, 0), PAL["metal"])
	_yaw(p, params)
	return p


## power_pole: utility pole with crossarm. params: yaw
static func _prop_power_pole(params: Dictionary) -> Node3D:
	var p := StaticBody3D.new()
	var pole := CylinderMesh.new()
	pole.top_radius = 0.12
	pole.bottom_radius = 0.16
	pole.height = 7.0
	_mesh_node(pole, PAL["wood"], Vector3(0, 3.5, 0), p)
	_box(p, Vector3(2.4, 0.12, 0.12), Vector3(0, 6.4, 0), PAL["wood"])
	_col_cyl(p, 0.16, 7.0, Vector3(0, 3.5, 0))
	_yaw(p, params)
	return p


## concrete_block: freestanding concrete cube obstacle. params: scale, yaw
static func _prop_concrete_block(params: Dictionary) -> Node3D:
	var s := float(params.get("scale", 1.0))
	var p := StaticBody3D.new()
	_box(p, Vector3(1.2 * s, 1.2 * s, 1.2 * s), Vector3(0, 0.6 * s, 0), PAL["structure"])
	_col_box(p, Vector3(1.2 * s, 1.2 * s, 1.2 * s), Vector3(0, 0.6 * s, 0))
	_yaw(p, params)
	return p


## scrap_pile: jumbled metal debris. params: yaw
static func _prop_scrap_pile(params: Dictionary) -> Node3D:
	var p := StaticBody3D.new()
	var defs := [
		[Vector3(0, 0.3, 0), Vector3(2.6, 0.6, 1.4), 10],
		[Vector3(-0.4, 0.75, 0.3), Vector3(1.4, 0.35, 1.0), -25],
		[Vector3(0.7, 0.95, -0.2), Vector3(1.0, 0.25, 0.7), 60],
	]
	for def in defs:
		var m := _box(p, def[1], def[0], PAL["metal"])
		m.rotation_degrees.y = def[2]
		m.rotation_degrees.z = randf_range(-8.0, 8.0)
	_col_box(p, Vector3(2.6, 1.1, 1.5), Vector3(0, 0.55, 0))
	_yaw(p, params)
	return p


## hay_bale: round farm bale. params: yaw
static func _prop_hay_bale(params: Dictionary) -> Node3D:
	var p := StaticBody3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.75
	c.bottom_radius = 0.75
	c.height = 1.3
	var mi := _mesh_node(c, PAL["ground_cover"], Vector3(0, 0.75, 0), p)
	mi.rotation_degrees.z = 90.0
	_col_box(p, Vector3(1.3, 1.5, 1.5), Vector3(0, 0.75, 0))
	_yaw(p, params)
	return p


## well: village well — stone ring + posts + tiny roof. params: yaw
static func _prop_well(params: Dictionary) -> Node3D:
	var p := StaticBody3D.new()
	var ring := CylinderMesh.new()
	ring.top_radius = 0.8
	ring.bottom_radius = 0.85
	ring.height = 0.9
	_mesh_node(ring, PAL["rock"], Vector3(0, 0.45, 0), p)
	for sx in [-1.0, 1.0]:
		_box(p, Vector3(0.1, 1.7, 0.1), Vector3(sx * 0.7, 0.85, 0), PAL["wood"])
	_box(p, Vector3(1.9, 0.1, 1.3), Vector3(0, 1.85, 0), PAL["wood"])
	_col_cyl(p, 0.85, 0.9, Vector3(0, 0.45, 0))
	_yaw(p, params)
	return p


# --- 工厂 / 室内件（feat/factory-map） -----------------------------------------

## pillar: 承重柱（柱身 + 柱础/柱头环带）。params: w, h, yaw
static func _prop_pillar(params: Dictionary) -> Node3D:
	var w := float(params.get("w", 0.7))
	var h := float(params.get("h", 6.0))
	var color: Color = params.get("color", PAL["structure"])
	var p := StaticBody3D.new()
	_box(p, Vector3(w, h, w), Vector3(0, h * 0.5, 0), color)
	_col_box(p, Vector3(w, h, w), Vector3(0, h * 0.5, 0))
	# 柱础/柱头环带（略宽于柱身，各自带碰撞）
	for y in [0.25, h - 0.25]:
		_box(p, Vector3(w + 0.18, 0.5, w + 0.18), Vector3(0, y, 0), PAL["metal"])
		_col_box(p, Vector3(w + 0.18, 0.5, w + 0.18), Vector3(0, y, 0))
	_yaw(p, params)
	return p


## wall_door: 带门洞的隔墙段（整段一侧含一个门洞，居中或 door_x 偏移）。
## params: w(段长), h, t(厚), door_w, door_h, door_x(洞中心偏移), yaw, color
static func _prop_wall_door(params: Dictionary) -> Node3D:
	var w := float(params.get("w", 6.0))
	var h := float(params.get("h", 4.0))
	var t := float(params.get("t", 0.25))
	var door_w := float(params.get("door_w", 1.4))
	var door_h := float(params.get("door_h", 2.2))
	var door_x := clampf(float(params.get("door_x", 0.0)), -w * 0.5 + door_w * 0.5, w * 0.5 - door_w * 0.5)
	var color: Color = params.get("color", PAL["structure"])
	var p := StaticBody3D.new()
	# 门洞两侧墙段
	var left_lo := -w * 0.5
	var left_hi := door_x - door_w * 0.5
	var right_lo := door_x + door_w * 0.5
	var right_hi := w * 0.5
	for seg in [[left_lo, left_hi], [right_lo, right_hi]]:
		var lo: float = seg[0]
		var hi: float = seg[1]
		var seg_w := hi - lo
		if seg_w <= 0.02:
			continue
		var cx := (lo + hi) * 0.5
		_box_tex(p, Vector3(seg_w, h, t), Vector3(cx, h * 0.5, 0), color, "wall_concrete.png")
		_col_box(p, Vector3(seg_w, h, t), Vector3(cx, h * 0.5, 0))
	# 门楣（门洞上方补齐到墙高）
	if h - door_h > 0.02:
		var ly := door_h + (h - door_h) * 0.5
		_box_tex(p, Vector3(door_w, h - door_h, t), Vector3(door_x, ly, 0), color, "wall_concrete.png")
		_col_box(p, Vector3(door_w, h - door_h, t), Vector3(door_x, ly, 0))
	_yaw(p, params)
	return p


## ceiling: 平顶/屋面板（挡雨封顶）。params: w, d, y(底面高度), t, yaw, color
static func _prop_ceiling(params: Dictionary) -> Node3D:
	var w := float(params.get("w", 10.0))
	var d := float(params.get("d", 10.0))
	var y := float(params.get("y", 6.0))
	var t := float(params.get("t", 0.3))
	var color: Color = params.get("color", PAL["structure"])
	var p := StaticBody3D.new()
	_box_tex(p, Vector3(w, t, d), Vector3(0, y + t * 0.5, 0), color, "metal_plate.png")
	_col_box(p, Vector3(w, t, d), Vector3(0, y + t * 0.5, 0))
	_yaw(p, params)
	return p


## machine: 工业机床/压机 — 底座 + 上压头 + 操作面板。params: w,d,h, yaw, color
static func _prop_machine(params: Dictionary) -> Node3D:
	var w := float(params.get("w", 2.2))
	var d := float(params.get("d", 1.4))
	var h := float(params.get("h", 2.2))
	var color: Color = params.get("color", PAL["metal"])
	var p := StaticBody3D.new()
	var base_h := h * 0.62
	_box(p, Vector3(w, base_h, d), Vector3(0, base_h * 0.5, 0), color)
	_col_box(p, Vector3(w, base_h, d), Vector3(0, base_h * 0.5, 0))
	# 压头（悬于底座上方，立柱连接）
	_box(p, Vector3(w * 0.62, h - base_h, d * 0.62), Vector3(-w * 0.15, base_h + (h - base_h) * 0.5, 0), color)
	_col_box(p, Vector3(w * 0.62, h - base_h, d * 0.62), Vector3(-w * 0.15, base_h + (h - base_h) * 0.5, 0))
	_box(p, Vector3(w * 0.16, h - base_h, d * 0.16), Vector3(w * 0.3, base_h + (h - base_h) * 0.5, -d * 0.3), color)
	_col_box(p, Vector3(w * 0.16, h - base_h, d * 0.16), Vector3(w * 0.3, base_h + (h - base_h) * 0.5, -d * 0.3))
	# 操作面板（前侧斜置小块）
	_box(p, Vector3(w * 0.3, 0.5, 0.08), Vector3(w * 0.2, base_h * 0.72, d * 0.5 + 0.04), PAL["asphalt"])
	_col_box(p, Vector3(w * 0.3, 0.5, 0.08), Vector3(w * 0.2, base_h * 0.72, d * 0.5 + 0.04))
	_yaw(p, params)
	return p


## tank: 立式化工储罐 — 罐体 + 支腿 + 顶部人孔盖 + 侧接管。
## params: r(半径), h(罐身高), yaw, color
static func _prop_tank(params: Dictionary) -> Node3D:
	var r := float(params.get("r", 1.3))
	var h := float(params.get("h", 3.4))
	var color: Color = params.get("color", PAL["metal"])
	var p := StaticBody3D.new()
	var body := CylinderMesh.new()
	body.top_radius = r
	body.bottom_radius = r
	body.height = h
	_mesh_node(body, color, Vector3(0, 0.5 + h * 0.5, 0), p)
	# 顶部人孔盖 + 接管（都在罐体半径内 → 一个圆柱碰撞体罩住全部）
	var hatch := CylinderMesh.new()
	hatch.top_radius = r * 0.3
	hatch.bottom_radius = r * 0.3
	hatch.height = 0.25
	_mesh_node(hatch, PAL["asphalt"], Vector3(0, 0.5 + h + 0.12, 0), p)
	var stub := CylinderMesh.new()
	stub.top_radius = r * 0.18
	stub.bottom_radius = r * 0.18
	stub.height = 0.5
	_mesh_node(stub, color, Vector3(r * 0.55, 0.5 + h - 0.2, 0), p)
	for i in 4:
		var a := TAU * i / 4.0 + PI * 0.25
		_box(p, Vector3(0.12, 0.55, 0.12), Vector3(cos(a) * r * 0.72, 0.25, sin(a) * r * 0.72), PAL["metal"])
	_col_cyl(p, r, h + 0.55, Vector3(0, 0.5 + h * 0.5 + 0.1, 0))
	_yaw(p, params)
	return p


## catwalk: 架空走道 — 桥面 + 支腿 + 侧护栏。
## params: len(沿局部 X), w(桥宽), elev(桥面高), rails:"both"|"near"|"far"|"none"
##         near = 局部 +Z 侧, far = 局部 -Z 侧; yaw
static func _prop_catwalk(params: Dictionary) -> Node3D:
	var len := float(params.get("len", 8.0))
	var w := float(params.get("w", 1.6))
	var elev := float(params.get("elev", 2.7))
	var rails := String(params.get("rails", "both"))
	var p := StaticBody3D.new()
	# 桥面
	_box(p, Vector3(len, 0.12, w), Vector3(0, elev, 0), PAL["metal"])
	_col_box(p, Vector3(len, 0.12, w), Vector3(0, elev, 0))
	# 支腿（两端两对）
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var lx: float = sx * (len * 0.5 - 0.25)
			var lz: float = sz * (w * 0.5 - 0.15)
			_box(p, Vector3(0.12, elev, 0.12), Vector3(lx, elev * 0.5, lz), PAL["metal"])
			_col_box(p, Vector3(0.12, elev, 0.12), Vector3(lx, elev * 0.5, lz))
	# 护栏（顶杆+立杆，整段一个碰撞盒——与 fence 同约定）
	var rail_sides: Array = []
	match rails:
		"both": rail_sides = [1.0, -1.0]
		"near": rail_sides = [1.0]
		"far": rail_sides = [-1.0]
		_: rail_sides = []
	for sz in rail_sides:
		var rz: float = sz * (w * 0.5 - 0.08)
		_box(p, Vector3(len, 0.08, 0.06), Vector3(0, elev + 1.05, rz), PAL["metal"])
		_box(p, Vector3(len, 0.08, 0.06), Vector3(0, elev + 0.55, rz), PAL["metal"])
		var posts := int(len / 2.0) + 1
		for i in posts:
			var px := -len * 0.5 + i * (len / float(posts - 1))
			_box(p, Vector3(0.06, 1.1, 0.06), Vector3(px, elev + 0.55, rz), PAL["metal"])
		_col_box(p, Vector3(len, 1.1, 0.1), Vector3(0, elev + 0.55, rz))
	_yaw(p, params)
	return p


## ramp: 步行坡道（爬坡向局部 -Z 端起升）。params: len(水平投影), rise, w, yaw
static func _prop_ramp(params: Dictionary) -> Node3D:
	var len := float(params.get("len", 5.0))
	var rise := float(params.get("rise", 2.7))
	var w := float(params.get("w", 1.5))
	var color: Color = params.get("color", PAL["structure"])
	var p := StaticBody3D.new()
	var slope := sqrt(len * len + rise * rise)
	var ang := rad_to_deg(atan2(rise, len))
	var slab := _box(p, Vector3(w, 0.12, slope), Vector3(0, rise * 0.5, 0), color)
	slab.rotation_degrees.x = ang
	var col := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = Vector3(w, 0.12, slope)
	col.shape = s
	col.position = Vector3(0, rise * 0.5, 0)
	col.rotation_degrees.x = ang
	p.add_child(col)
	_yaw(p, params)
	return p


## railing: 独立护栏段。params: len, yaw
static func _prop_railing(params: Dictionary) -> Node3D:
	var len := float(params.get("len", 4.0))
	var p := StaticBody3D.new()
	_box(p, Vector3(len, 0.08, 0.06), Vector3(0, 1.05, 0), PAL["metal"])
	_box(p, Vector3(len, 0.08, 0.06), Vector3(0, 0.55, 0), PAL["metal"])
	var posts := int(len / 2.0) + 1
	for i in posts:
		var x := -len * 0.5 + i * (len / float(posts - 1))
		_box(p, Vector3(0.06, 1.1, 0.06), Vector3(x, 0.55, 0), PAL["metal"])
	_col_box(p, Vector3(len, 1.1, 0.1), Vector3(0, 0.55, 0))
	_yaw(p, params)
	return p


## locker: 一排金属储物柜。params: n(柜数), yaw
static func _prop_locker(params: Dictionary) -> Node3D:
	var n := int(params.get("n", 4))
	var p := StaticBody3D.new()
	var w := 0.55
	var total := w * n
	_box(p, Vector3(total, 1.9, 0.5), Vector3(0, 0.95, 0), PAL["metal"])
	# 门缝刻线（贴片，在主碰撞体内）
	for i in n - 1:
		var x := -total * 0.5 + w * (i + 1)
		_box(p, Vector3(0.03, 1.7, 0.02), Vector3(x, 0.95, 0.25), PAL["asphalt"])
	# 把手
	for i in n:
		var x := -total * 0.5 + w * (i + 0.72)
		_box(p, Vector3(0.06, 0.12, 0.04), Vector3(x, 1.05, 0.26), PAL["structure"])
	_col_box(p, Vector3(total, 1.9, 0.52), Vector3(0, 0.95, 0))
	_yaw(p, params)
	return p


## duct: 高架通风管（方管 + 环箍）。params: len, y(管心高), yaw
static func _prop_duct(params: Dictionary) -> Node3D:
	var len := float(params.get("len", 10.0))
	var y := float(params.get("y", 4.8))
	var p := StaticBody3D.new()
	_box(p, Vector3(len, 0.5, 0.5), Vector3(0, y, 0), PAL["metal"])
	var ribs := int(len / 1.6) + 1
	for i in ribs:
		var x := -len * 0.5 + i * (len / float(maxi(ribs - 1, 1)))
		_box(p, Vector3(0.1, 0.56, 0.56), Vector3(x, y, 0), PAL["metal"])
	_col_box(p, Vector3(len, 0.56, 0.56), Vector3(0, y, 0))
	_yaw(p, params)
	return p


## beam: 天花横梁/吊车梁（工字钢形）。params: len, y(梁心高), yaw
static func _prop_beam(params: Dictionary) -> Node3D:
	var len := float(params.get("len", 10.0))
	var y := float(params.get("y", 5.4))
	var color: Color = params.get("color", PAL["metal"])
	var p := StaticBody3D.new()
	_box(p, Vector3(len, 0.32, 0.12), Vector3(0, y, 0), color)
	_box(p, Vector3(len, 0.08, 0.3), Vector3(0, y + 0.16, 0), color)
	_box(p, Vector3(len, 0.08, 0.3), Vector3(0, y - 0.16, 0), color)
	_col_box(p, Vector3(len, 0.42, 0.3), Vector3(0, y, 0))
	_yaw(p, params)
	return p


## lamp: 吊装工矿灯（灯杆 + 灯罩 + 自发光灯芯）。params: y(灯罩高), yaw, glow
static func _prop_lamp(params: Dictionary) -> Node3D:
	var y := float(params.get("y", 5.2))
	var glow: Color = params.get("glow", Color(1.0, 0.85, 0.55))
	var p := StaticBody3D.new()
	var rod := CylinderMesh.new()
	rod.top_radius = 0.03
	rod.bottom_radius = 0.03
	rod.height = 0.7
	_mesh_node(rod, PAL["metal"], Vector3(0, y + 0.55, 0), p)
	var shade := CylinderMesh.new()
	shade.top_radius = 0.1
	shade.bottom_radius = 0.36
	shade.height = 0.28
	_mesh_node(shade, PAL["metal"], Vector3(0, y + 0.14, 0), p)
	var bulb := SphereMesh.new()
	bulb.radius = 0.09
	bulb.height = 0.18
	var bm := StandardMaterial3D.new()
	bm.albedo_color = glow
	bm.emission_enabled = true
	bm.emission = glow
	bm.emission_energy_multiplier = 2.0
	var bi := MeshInstance3D.new()
	bi.mesh = bulb
	bi.material_override = bm
	bi.position = Vector3(0, y - 0.04, 0)
	p.add_child(bi)
	_col_cyl(p, 0.36, 0.32, Vector3(0, y + 0.14, 0))
	_yaw(p, params)
	return p


## rollup_door: 卷帘大门（关闭态，作厂房大门/电梯门面）。
## params: w, h, yaw, color
static func _prop_rollup_door(params: Dictionary) -> Node3D:
	var w := float(params.get("w", 5.0))
	var h := float(params.get("h", 4.0))
	var color: Color = params.get("color", PAL["metal"])
	var p := StaticBody3D.new()
	# 门板 + 横向凸棱（棱片贴在门板两面，碰撞体整片罩住）
	_box(p, Vector3(w, h, 0.12), Vector3(0, h * 0.5, 0), color)
	var ribs := int(h / 0.5)
	for i in ribs:
		_box(p, Vector3(w, 0.09, 0.05), Vector3(0, 0.25 + i * 0.5, 0.06), color)
		_box(p, Vector3(w, 0.09, 0.05), Vector3(0, 0.25 + i * 0.5, -0.06), color)
	_col_box(p, Vector3(w, h, 0.22), Vector3(0, h * 0.5, 0))
	# 顶部卷筒
	var drum := CylinderMesh.new()
	drum.top_radius = 0.22
	drum.bottom_radius = 0.22
	drum.height = w * 0.96
	var dm := _mesh_node(drum, PAL["metal"], Vector3(0, h + 0.2, 0), p)
	dm.rotation_degrees.z = 90.0
	_col_box(p, Vector3(w * 0.96, 0.44, 0.44), Vector3(0, h + 0.2, 0))
	# 两侧导轨
	for sx in [-1.0, 1.0]:
		_box(p, Vector3(0.12, h + 0.3, 0.2), Vector3(sx * (w * 0.5 + 0.06), (h + 0.3) * 0.5, 0), PAL["metal"])
		_col_box(p, Vector3(0.12, h + 0.3, 0.2), Vector3(sx * (w * 0.5 + 0.06), (h + 0.3) * 0.5, 0))
	_yaw(p, params)
	return p


## forklift: 叉车 — 车身 + 门架 + 货叉 + 车顶棚。params: yaw, color
static func _prop_forklift(params: Dictionary) -> Node3D:
	var color: Color = params.get("color", Color(0.75, 0.55, 0.1))
	var p := StaticBody3D.new()
	# 车身（车头朝局部 -Z）
	_box(p, Vector3(1.1, 0.75, 1.9), Vector3(0, 0.55, 0.3), color)
	_col_box(p, Vector3(1.1, 0.75, 1.9), Vector3(0, 0.55, 0.3))
	# 驾驶棚架
	for sx in [-1.0, 1.0]:
		for sz in [-0.2, 0.8]:
			_box(p, Vector3(0.08, 1.1, 0.08), Vector3(sx * 0.48, 1.45, sz), PAL["metal"])
	_box(p, Vector3(1.04, 0.08, 1.1), Vector3(0, 2.0, 0.3), PAL["metal"])
	_col_box(p, Vector3(1.04, 1.18, 1.1), Vector3(0, 1.45, 0.3))
	# 门架（前部双轨）
	for sx in [-1.0, 1.0]:
		_box(p, Vector3(0.12, 2.2, 0.12), Vector3(sx * 0.4, 1.1, -0.78), PAL["metal"])
	_col_box(p, Vector3(0.92, 2.2, 0.14), Vector3(0, 1.1, -0.78))
	# 货叉
	for sx in [-1.0, 1.0]:
		_box(p, Vector3(0.12, 0.08, 1.1), Vector3(sx * 0.32, 0.06, -1.35), PAL["metal"])
	_col_box(p, Vector3(0.8, 0.12, 1.1), Vector3(0, 0.07, -1.35))
	# 轮
	for off in [Vector3(-0.5, 0, -0.35), Vector3(0.5, 0, -0.35), Vector3(-0.5, 0, 0.9), Vector3(0.5, 0, 0.9)]:
		var wm := CylinderMesh.new()
		wm.top_radius = 0.26
		wm.bottom_radius = 0.26
		wm.height = 0.18
		var wi := _mesh_node(wm, PAL["asphalt"], Vector3(off.x, 0.26, off.z), p)
		wi.rotation_degrees.z = 90.0
	_yaw(p, params)
	return p


## floor_mark: 地面标线（通道线/警戒带，纯装饰无碰撞）。
## params: len, w, style:"lane"|"hazard", yaw
static func _prop_floor_mark(params: Dictionary) -> Node3D:
	var len := float(params.get("len", 10.0))
	var w := float(params.get("w", 0.3))
	var style := String(params.get("style", "lane"))
	var p := Node3D.new()
	if style == "hazard":
		# 黄黑相间警示带
		var seg := 0.5
		var n := int(len / seg)
		for i in n:
			var col: Color = PAL["marking"] if i % 2 == 0 else PAL["asphalt"]
			_box(p, Vector3(seg, 0.025, w), Vector3(-len * 0.5 + seg * (i + 0.5), 0.015, 0), col)
	else:
		# 单条通道线
		_box(p, Vector3(len, 0.025, w), Vector3(0, 0.015, 0), PAL["marking"])
	_yaw(p, params)
	return p
