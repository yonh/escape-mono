extends RefCounted

## 工厂关卡（室内 CQB 厂房）—— 类塔科夫"工厂"图的复刻地图。
## 一座 48×36m 全封闭厂房：中央主车间（立柱阵+机床列+二层平台），
## 四周环形走廊，北侧办公区（办公室/会议室/机房/储藏间），西侧
## 更衣室/车间/库房，东侧危险品库/备件间，南侧装卸区。
## 三处撤离：正门 GATE-0（装卸区南墙）、东门 GATE-3（东廊）、
## 货运电梯（更衣室西墙）。多出生点随机。
## 布局数据在 LAYOUT：{zone, kind, pos, params}，与 raid_map 同约定；
## 灯光数据在 LIGHTS，由 build 一并实例化（室内图无昼夜）。

const PROP_KIT := preload("res://scripts/gameplay/prop_kit.gd")
const LOOT_CRATE := preload("res://scripts/gameplay/loot_crate.gd")
const INTERACTABLE := preload("res://scripts/gameplay/interactable.gd")
const UIFONT := preload("res://scripts/gameplay/ui_font.gd")

const MAP_MIN := Vector2(-24, -18)
const MAP_MAX := Vector2(24, 18)
const MAP_NAME := "工厂"

## 室内局时长（秒）：工厂快节奏 15 分钟（室外搜刮区 20 分钟）。
const RAID_SECONDS := 900.0

const SHELL_H := 6.0

## 区域定义：HUD 区域提示。rect 为 (min_x, min_z, w, h)；
## "二层平台" 由 zone_label_at 用 y 高度特判（在主车间上空）。
const ZONES := [
	{"id": "hall", "label": "主车间", "rect": Rect2(-8.5, -7.5, 22, 16)},
	{"id": "office_a", "label": "办公室", "rect": Rect2(-24, -18, 12, 6.4)},
	{"id": "office_b", "label": "会议室", "rect": Rect2(-12, -18, 14, 6.4)},
	{"id": "server", "label": "机房", "rect": Rect2(2, -18, 12, 6.4)},
	{"id": "store_ne", "label": "储藏间", "rect": Rect2(14, -18, 10, 6.4)},
	{"id": "locker", "label": "更衣室", "rect": Rect2(-24, -11.6, 12, 7.6)},
	{"id": "workshop", "label": "车间", "rect": Rect2(-24, -4, 12, 8)},
	{"id": "depot", "label": "库房", "rect": Rect2(-24, 4, 12, 8)},
	{"id": "hazmat", "label": "危险品库", "rect": Rect2(17.5, -4, 6.5, 8)},
	{"id": "spares", "label": "备件间", "rect": Rect2(17.5, 4, 6.5, 8.5)},
	{"id": "dock", "label": "装卸区", "rect": Rect2(-24, 12.5, 48, 5.5)},
	{"id": "corridor", "label": "走廊", "rect": Rect2(-24, -18, 48, 36)},
]


## 返回玩家所在区域的显示名（二层平台按高度优先判定）。
static func zone_label_at(pos: Vector3) -> String:
	if pos.y > 2.0:
		var hall: Rect2 = ZONES[0]["rect"]
		if hall.has_point(Vector2(pos.x, pos.z)):
			return "二层平台"
	for zone in ZONES:
		if zone["id"] == "corridor":
			continue
		var r: Rect2 = zone["rect"]
		if r.has_point(Vector2(pos.x, pos.z)):
			return String(zone["label"])
	return "走廊" if _inside_shell(pos) else "厂区外围"


static func _inside_shell(pos: Vector3) -> bool:
	return pos.x > MAP_MIN.x and pos.x < MAP_MAX.x \
		and pos.z > MAP_MIN.y and pos.z < MAP_MAX.y


## 厂房布局：[kind, pos, params]。zone 字段仅作分块注释用。
const LAYOUT := [
	# ---- 外壳：四面混凝土外墙 + 分区吊顶 --------------------------------
	{"zone": "shell", "kind": &"concrete_wall", "pos": Vector3(0, 0, -18), "params": {"len": 48.5, "h": 6.0}},
	{"zone": "shell", "kind": &"concrete_wall", "pos": Vector3(0, 0, 18), "params": {"len": 48.5, "h": 6.0}},
	{"zone": "shell", "kind": &"concrete_wall", "pos": Vector3(-24, 0, 0), "params": {"len": 36.5, "h": 6.0, "yaw": 90}},
	{"zone": "shell", "kind": &"concrete_wall", "pos": Vector3(24, 0, 0), "params": {"len": 36.5, "h": 6.0, "yaw": 90}},
	# 吊顶：主车间 6m 高通高，其余房间/走廊 4m 顶，装卸区 5m 高跨。
	{"zone": "shell", "kind": &"ceiling", "pos": Vector3(2.5, 0, 0.5), "params": {"w": 22.4, "d": 16.4, "y": 6.0}},
	{"zone": "shell", "kind": &"ceiling", "pos": Vector3(0, 0, -14.8), "params": {"w": 48, "d": 6.6, "y": 4.0}},
	{"zone": "shell", "kind": &"ceiling", "pos": Vector3(-18, 0, 0.2), "params": {"w": 12.4, "d": 23.8, "y": 4.0}},
	{"zone": "shell", "kind": &"ceiling", "pos": Vector3(20.6, 0, 0.5), "params": {"w": 6.9, "d": 24.3, "y": 4.0}},
	{"zone": "shell", "kind": &"ceiling", "pos": Vector3(0, 0, -9.55), "params": {"w": 48, "d": 4.3, "y": 4.0}},
	{"zone": "shell", "kind": &"ceiling", "pos": Vector3(0, 0, 10.5), "params": {"w": 48, "d": 4.2, "y": 4.0}},
	{"zone": "shell", "kind": &"ceiling", "pos": Vector3(-10.4, 0, 0.5), "params": {"w": 4.1, "d": 24.3, "y": 4.0}},
	{"zone": "shell", "kind": &"ceiling", "pos": Vector3(15.5, 0, 0.5), "params": {"w": 4.2, "d": 24.3, "y": 4.0}},
	{"zone": "shell", "kind": &"ceiling", "pos": Vector3(0, 0, 15.2), "params": {"w": 48, "d": 5.7, "y": 5.0}},

	# ---- 主车间隔墙（h6 通顶，各面留门洞） ------------------------------
	{"zone": "hall", "kind": &"wall_door", "pos": Vector3(-8.5, 0, -3.5), "params": {"w": 8.0, "h": 6.0, "yaw": 90}},
	{"zone": "hall", "kind": &"wall_door", "pos": Vector3(-8.5, 0, 4.5), "params": {"w": 8.0, "h": 6.0, "yaw": 90}},
	{"zone": "hall", "kind": &"wall_door", "pos": Vector3(13.5, 0, -3.5), "params": {"w": 8.0, "h": 6.0, "yaw": 90}},
	{"zone": "hall", "kind": &"wall_door", "pos": Vector3(13.5, 0, 4.5), "params": {"w": 8.0, "h": 6.0, "yaw": 90}},
	{"zone": "hall", "kind": &"wall_door", "pos": Vector3(-3.0, 0, -7.5), "params": {"w": 11.0, "h": 6.0}},
	{"zone": "hall", "kind": &"wall_door", "pos": Vector3(8.0, 0, -7.5), "params": {"w": 11.0, "h": 6.0}},
	{"zone": "hall", "kind": &"wall_door", "pos": Vector3(-3.0, 0, 8.5), "params": {"w": 11.0, "h": 6.0}},
	{"zone": "hall", "kind": &"wall_door", "pos": Vector3(8.0, 0, 8.5), "params": {"w": 11.0, "h": 6.0}},

	# ---- 办公区隔墙（z -18..-11.6 一排四间，南墙开门通北廊） -----------
	{"zone": "office", "kind": &"wall_door", "pos": Vector3(-17.9, 0, -11.6), "params": {"w": 11.8, "h": 4.0}},
	{"zone": "office", "kind": &"wall_door", "pos": Vector3(-5.0, 0, -11.6), "params": {"w": 14.0, "h": 4.0}},
	{"zone": "office", "kind": &"wall_door", "pos": Vector3(8.0, 0, -11.6), "params": {"w": 12.0, "h": 4.0}},
	{"zone": "office", "kind": &"wall_door", "pos": Vector3(19.0, 0, -11.6), "params": {"w": 9.8, "h": 4.0}},
	{"zone": "office", "kind": &"concrete_wall", "pos": Vector3(-12, 0, -14.8), "params": {"len": 6.4, "h": 4.0, "yaw": 90}},
	{"zone": "office", "kind": &"concrete_wall", "pos": Vector3(2, 0, -14.8), "params": {"len": 6.4, "h": 4.0, "yaw": 90}},
	{"zone": "office", "kind": &"concrete_wall", "pos": Vector3(14, 0, -14.8), "params": {"len": 6.4, "h": 4.0, "yaw": 90}},

	# ---- 西翼：更衣室/车间/库房（东墙 x=-12 各留门，面向西廊） ---------
	{"zone": "west", "kind": &"wall_door", "pos": Vector3(-12, 0, -7.8), "params": {"w": 7.6, "h": 4.0, "yaw": 90}},
	{"zone": "west", "kind": &"wall_door", "pos": Vector3(-12, 0, 0), "params": {"w": 8.0, "h": 4.0, "yaw": 90}},
	{"zone": "west", "kind": &"wall_door", "pos": Vector3(-12, 0, 8), "params": {"w": 8.0, "h": 4.0, "yaw": 90}},
	{"zone": "west", "kind": &"concrete_wall", "pos": Vector3(-18, 0, -4), "params": {"len": 12.0, "h": 4.0}},
	{"zone": "west", "kind": &"concrete_wall", "pos": Vector3(-18, 0, 4), "params": {"len": 12.0, "h": 4.0}},

	# ---- 东翼：危险品库/备件间（西墙 x=17.5 各留门，面向东廊） ---------
	{"zone": "east", "kind": &"wall_door", "pos": Vector3(17.5, 0, 0), "params": {"w": 8.0, "h": 4.0, "yaw": 90}},
	{"zone": "east", "kind": &"wall_door", "pos": Vector3(17.5, 0, 8.25), "params": {"w": 8.5, "h": 4.0, "yaw": 90}},
	{"zone": "east", "kind": &"concrete_wall", "pos": Vector3(20.6, 0, -4), "params": {"len": 6.9, "h": 4.0}},
	{"zone": "east", "kind": &"concrete_wall", "pos": Vector3(20.6, 0, 4), "params": {"len": 6.9, "h": 4.0}},
	{"zone": "east", "kind": &"concrete_wall", "pos": Vector3(20.6, 0, 12.5), "params": {"len": 6.9, "h": 4.0}},

	# ---- 大门（卷帘门贴外墙内侧） --------------------------------------
	{"zone": "gate", "kind": &"rollup_door", "pos": Vector3(2, 0, 17.7), "params": {"w": 6.5, "h": 4.5}},
	{"zone": "gate", "kind": &"rollup_door", "pos": Vector3(23.7, 0, -8), "params": {"w": 4.0, "h": 3.6, "yaw": 90}},
	{"zone": "gate", "kind": &"rollup_door", "pos": Vector3(-23.7, 0, -9), "params": {"w": 3.2, "h": 3.2, "yaw": 90}},
	{"zone": "gate", "kind": &"floor_mark", "pos": Vector3(2, 0, 16.2), "params": {"len": 7.0, "w": 0.5, "style": "hazard"}},
	{"zone": "gate", "kind": &"floor_mark", "pos": Vector3(22.4, 0, -8), "params": {"len": 4.6, "w": 0.5, "style": "hazard", "yaw": 90}},
	{"zone": "gate", "kind": &"floor_mark", "pos": Vector3(-22.4, 0, -9), "params": {"len": 3.8, "w": 0.5, "style": "hazard", "yaw": 90}},

	# ---- 主车间内部 ----------------------------------------------------
	# 立柱阵 2×3
	{"zone": "hall", "kind": &"pillar", "pos": Vector3(-3, 0, -4), "params": {}},
	{"zone": "hall", "kind": &"pillar", "pos": Vector3(-3, 0, 0), "params": {}},
	{"zone": "hall", "kind": &"pillar", "pos": Vector3(-3, 0, 4), "params": {}},
	{"zone": "hall", "kind": &"pillar", "pos": Vector3(7, 0, -4), "params": {}},
	{"zone": "hall", "kind": &"pillar", "pos": Vector3(7, 0, 0), "params": {}},
	{"zone": "hall", "kind": &"pillar", "pos": Vector3(7, 0, 4), "params": {}},
	# 机床两列（面板对望形成中央巷道）
	{"zone": "hall", "kind": &"machine", "pos": Vector3(0.5, 0, -3.5), "params": {"yaw": 0}},
	{"zone": "hall", "kind": &"machine", "pos": Vector3(0.5, 0, 0.5), "params": {"yaw": 0}},
	{"zone": "hall", "kind": &"machine", "pos": Vector3(0.5, 0, 4.5), "params": {"yaw": 0}},
	{"zone": "hall", "kind": &"machine", "pos": Vector3(9.5, 0, -3.5), "params": {"yaw": 180}},
	{"zone": "hall", "kind": &"machine", "pos": Vector3(9.5, 0, 0.5), "params": {"yaw": 180}},
	{"zone": "hall", "kind": &"machine", "pos": Vector3(9.5, 0, 4.5), "params": {"yaw": 180}},
	# 化工储罐沿西墙（让开西墙两个门洞的出入通道）
	{"zone": "hall", "kind": &"tank", "pos": Vector3(-5.2, 0, -4.5), "params": {"r": 1.2}},
	{"zone": "hall", "kind": &"tank", "pos": Vector3(-5.2, 0, -0.5), "params": {"r": 1.3}},
	{"zone": "hall", "kind": &"tank", "pos": Vector3(-5.2, 0, 3.5), "params": {"r": 1.1}},
	# 二层平台（东墙内侧，西缘护栏；南端经大厅中央坡道上桥）
	{"zone": "hall", "kind": &"catwalk", "pos": Vector3(12.4, 0, 0.5), "params": {"len": 14.0, "elev": 2.7, "rails": "far", "yaw": 90}},
	{"zone": "hall", "kind": &"ramp", "pos": Vector3(8.9, 0, 6.0), "params": {"len": 6.0, "rise": 2.7, "w": 1.5, "yaw": -90}},
	{"zone": "hall", "kind": &"railing", "pos": Vector3(8.9, 0, 5.1), "params": {"len": 5.6, "yaw": 0}},
	# 吊车梁 + 通风管 + 工矿灯
	{"zone": "hall", "kind": &"beam", "pos": Vector3(2.5, 0, -4), "params": {"len": 21.5, "y": 5.4}},
	{"zone": "hall", "kind": &"beam", "pos": Vector3(2.5, 0, 4), "params": {"len": 21.5, "y": 5.4}},
	{"zone": "hall", "kind": &"duct", "pos": Vector3(2.5, 0, 0.5), "params": {"len": 20.0, "y": 4.8}},
	{"zone": "hall", "kind": &"lamp", "pos": Vector3(-4, 0, -4), "params": {"y": 5.2}},
	{"zone": "hall", "kind": &"lamp", "pos": Vector3(8, 0, -4), "params": {"y": 5.2}},
	{"zone": "hall", "kind": &"lamp", "pos": Vector3(-4, 0, 4), "params": {"y": 5.2}},
	{"zone": "hall", "kind": &"lamp", "pos": Vector3(8, 0, 4), "params": {"y": 5.2}},
	{"zone": "hall", "kind": &"lamp", "pos": Vector3(2, 0, 0.5), "params": {"y": 5.2}},
	# 地面通道标线
	{"zone": "hall", "kind": &"floor_mark", "pos": Vector3(5, 0, 0.5), "params": {"len": 15.0, "w": 0.3, "yaw": 90}},
	{"zone": "hall", "kind": &"floor_mark", "pos": Vector3(2, 0, -6.2), "params": {"len": 20.0, "w": 0.3}},
	{"zone": "hall", "kind": &"floor_mark", "pos": Vector3(2, 0, 7.2), "params": {"len": 20.0, "w": 0.3}},
	# 散件掩体
	{"zone": "hall", "kind": &"crate_stack", "pos": Vector3(4, 0, -5.5), "params": {"yaw": 20}},
	{"zone": "hall", "kind": &"crate_stack", "pos": Vector3(4.5, 0, 7.3), "params": {"yaw": -15}},
	{"zone": "hall", "kind": &"crate_stack", "pos": Vector3(-6.5, 0, 7), "params": {"yaw": 40}},
	{"zone": "hall", "kind": &"barrel", "pos": Vector3(-7, 0, -6.5), "params": {}},
	{"zone": "hall", "kind": &"barrel", "pos": Vector3(-6.4, 0, -6.9), "params": {"color": Color(0.3, 0.45, 0.3)}},
	{"zone": "hall", "kind": &"barrel", "pos": Vector3(-6.6, 0, -6.1), "params": {}},
	{"zone": "hall", "kind": &"scrap_pile", "pos": Vector3(11.5, 0, -6.2), "params": {"yaw": 30}},
	{"zone": "hall", "kind": &"sign", "pos": Vector3(-3, 0, -6.6), "params": {"text": "主车间", "yaw": 180}},

	# ---- 北廊（办公区门前） ---------------------------------------------
	{"zone": "corridor_n", "kind": &"duct", "pos": Vector3(0, 0, -9.6), "params": {"len": 44.0, "y": 3.6}},
	{"zone": "corridor_n", "kind": &"lamp", "pos": Vector3(-14, 0, -9.6), "params": {"y": 3.3}},
	{"zone": "corridor_n", "kind": &"lamp", "pos": Vector3(6, 0, -9.6), "params": {"y": 3.3}},
	{"zone": "corridor_n", "kind": &"lamp", "pos": Vector3(18, 0, -9.6), "params": {"y": 3.3}},
	{"zone": "corridor_n", "kind": &"sign", "pos": Vector3(-4, 0, -10.2), "params": {"text": "办公区", "yaw": 0}},
	{"zone": "corridor_n", "kind": &"crate_stack", "pos": Vector3(-20, 0, -10.5), "params": {"yaw": 60}},

	# ---- 办公室 A（综合办公） -------------------------------------------
	{"zone": "office_a", "kind": &"table", "pos": Vector3(-19, 0, -14.5), "params": {"yaw": 0}},
	{"zone": "office_a", "kind": &"table", "pos": Vector3(-15.5, 0, -14.5), "params": {"yaw": 0}},
	{"zone": "office_a", "kind": &"shelf", "pos": Vector3(-22.5, 0, -14), "params": {"yaw": 90}},
	{"zone": "office_a", "kind": &"lamp", "pos": Vector3(-18, 0, -14.5), "params": {"y": 3.3}},

	# ---- 会议室 B ------------------------------------------------------
	{"zone": "office_b", "kind": &"table", "pos": Vector3(-7, 0, -15), "params": {"yaw": 90}},
	{"zone": "office_b", "kind": &"table", "pos": Vector3(-4, 0, -15), "params": {"yaw": 90}},
	{"zone": "office_b", "kind": &"table", "pos": Vector3(-1, 0, -15), "params": {"yaw": 90}},
	{"zone": "office_b", "kind": &"locker", "pos": Vector3(-10, 0, -17.2), "params": {"n": 5}},
	{"zone": "office_b", "kind": &"lamp", "pos": Vector3(-5, 0, -14.5), "params": {"y": 3.3}},

	# ---- 机房 ----------------------------------------------------------
	{"zone": "server", "kind": &"shelf", "pos": Vector3(4, 0, -16.8), "params": {"yaw": 0}},
	{"zone": "server", "kind": &"shelf", "pos": Vector3(7, 0, -16.8), "params": {"yaw": 0}},
	{"zone": "server", "kind": &"shelf", "pos": Vector3(10, 0, -16.8), "params": {"yaw": 0}},
	{"zone": "server", "kind": &"machine", "pos": Vector3(12, 0, -14), "params": {"w": 1.8, "d": 1.2, "h": 1.6, "yaw": 90}},
	{"zone": "server", "kind": &"lamp", "pos": Vector3(8, 0, -14.5), "params": {"y": 3.3}},

	# ---- 东北储藏间 ----------------------------------------------------
	{"zone": "store_ne", "kind": &"shelf", "pos": Vector3(18, 0, -16.8), "params": {"yaw": 0}},
	{"zone": "store_ne", "kind": &"shelf", "pos": Vector3(21, 0, -16.8), "params": {"yaw": 0}},
	{"zone": "store_ne", "kind": &"crate_stack", "pos": Vector3(16.5, 0, -13.5), "params": {"yaw": 10}},
	{"zone": "store_ne", "kind": &"lamp", "pos": Vector3(19, 0, -14.5), "params": {"y": 3.3}},

	# ---- 更衣室（出生点之一；西墙内是货运电梯） -------------------------
	{"zone": "locker", "kind": &"locker", "pos": Vector3(-23.2, 0, -7), "params": {"n": 7, "yaw": 90}},
	{"zone": "locker", "kind": &"locker", "pos": Vector3(-16, 0, -11.2), "params": {"n": 6}},
	{"zone": "locker", "kind": &"table", "pos": Vector3(-18, 0, -7.5), "params": {"yaw": 0}},
	{"zone": "locker", "kind": &"sign", "pos": Vector3(-10.3, 0, -7.8), "params": {"text": "更衣室", "yaw": -90}},
	{"zone": "locker", "kind": &"lamp", "pos": Vector3(-18, 0, -8), "params": {"y": 3.3}},

	# ---- 西车间 --------------------------------------------------------
	{"zone": "workshop", "kind": &"machine", "pos": Vector3(-20, 0, -1), "params": {"w": 2.6, "d": 1.6, "h": 2.4, "yaw": 90}},
	{"zone": "workshop", "kind": &"table", "pos": Vector3(-16, 0, 1.5), "params": {"yaw": 90}},
	{"zone": "workshop", "kind": &"table", "pos": Vector3(-16, 0, -1.5), "params": {"yaw": 90}},
	{"zone": "workshop", "kind": &"barrel", "pos": Vector3(-21.5, 0, 2.5), "params": {}},
	{"zone": "workshop", "kind": &"lamp", "pos": Vector3(-18, 0, 0), "params": {"y": 3.3}},

	# ---- 库房 ----------------------------------------------------------
	{"zone": "depot", "kind": &"shelf", "pos": Vector3(-22.5, 0, 6), "params": {"yaw": 90}},
	{"zone": "depot", "kind": &"shelf", "pos": Vector3(-22.5, 0, 9), "params": {"yaw": 90}},
	{"zone": "depot", "kind": &"crate_stack", "pos": Vector3(-16, 0, 9.5), "params": {"yaw": 70}},
	{"zone": "depot", "kind": &"lamp", "pos": Vector3(-18, 0, 8), "params": {"y": 3.3}},

	# ---- 西廊 ----------------------------------------------------------
	{"zone": "corridor_w", "kind": &"duct", "pos": Vector3(-10.3, 0, -2), "params": {"len": 28.0, "y": 3.6, "yaw": 90}},
	{"zone": "corridor_w", "kind": &"lamp", "pos": Vector3(-10.3, 0, -6), "params": {"y": 3.3}},
	{"zone": "corridor_w", "kind": &"lamp", "pos": Vector3(-10.3, 0, 6), "params": {"y": 3.3}},

	# ---- 东廊 ----------------------------------------------------------
	{"zone": "corridor_e", "kind": &"duct", "pos": Vector3(15.5, 0, -2), "params": {"len": 28.0, "y": 3.6, "yaw": 90}},
	{"zone": "corridor_e", "kind": &"lamp", "pos": Vector3(15.5, 0, -6), "params": {"y": 3.3}},
	{"zone": "corridor_e", "kind": &"lamp", "pos": Vector3(15.5, 0, 6), "params": {"y": 3.3}},
	{"zone": "corridor_e", "kind": &"barrel", "pos": Vector3(16.5, 0, -10.5), "params": {}},
	{"zone": "corridor_e", "kind": &"crate_stack", "pos": Vector3(15.8, 0, 11.5), "params": {"yaw": 15}},

	# ---- 危险品库 ------------------------------------------------------
	{"zone": "hazmat", "kind": &"tank", "pos": Vector3(21.5, 0, -2), "params": {"r": 1.1, "color": Color(0.55, 0.5, 0.2)}},
	{"zone": "hazmat", "kind": &"barrel", "pos": Vector3(19.5, 0, 1.5), "params": {"color": Color(0.6, 0.4, 0.1)}},
	{"zone": "hazmat", "kind": &"barrel", "pos": Vector3(20.2, 0, 1.9), "params": {}},
	{"zone": "hazmat", "kind": &"barrel", "pos": Vector3(19.8, 0, 2.6), "params": {"color": Color(0.6, 0.4, 0.1)}},
	{"zone": "hazmat", "kind": &"lamp", "pos": Vector3(20.5, 0, 0), "params": {"y": 3.3, "glow": Color(1.0, 0.55, 0.4)}},

	# ---- 备件间 --------------------------------------------------------
	{"zone": "spares", "kind": &"shelf", "pos": Vector3(22.5, 0, 7), "params": {"yaw": 90}},
	{"zone": "spares", "kind": &"shelf", "pos": Vector3(22.5, 0, 10), "params": {"yaw": 90}},
	{"zone": "spares", "kind": &"lamp", "pos": Vector3(20.5, 0, 8), "params": {"y": 3.3}},

	# ---- 南廊 ----------------------------------------------------------
	{"zone": "corridor_s", "kind": &"duct", "pos": Vector3(0, 0, 10.5), "params": {"len": 44.0, "y": 3.6}},
	{"zone": "corridor_s", "kind": &"lamp", "pos": Vector3(-8, 0, 10.5), "params": {"y": 3.3}},
	{"zone": "corridor_s", "kind": &"lamp", "pos": Vector3(10, 0, 10.5), "params": {"y": 3.3}},
	{"zone": "corridor_s", "kind": &"sign", "pos": Vector3(4, 0, 11.8), "params": {"text": "装卸区 →", "yaw": 180}},

	# ---- 装卸区（南墙 GATE-0） -----------------------------------------
	{"zone": "dock", "kind": &"container", "pos": Vector3(-15, 0, 15), "params": {"yaw": 0, "color": Color(0.5, 0.3, 0.2)}},
	{"zone": "dock", "kind": &"container", "pos": Vector3(-15, 2.6, 15), "params": {"yaw": 0, "color": Color(0.55, 0.45, 0.2)}},
	{"zone": "dock", "kind": &"container", "pos": Vector3(-7, 0, 15.5), "params": {"yaw": 90, "color": Color(0.25, 0.4, 0.45)}},
	{"zone": "dock", "kind": &"container", "pos": Vector3(14, 0, 14.5), "params": {"yaw": 10, "color": Color(0.3, 0.32, 0.36)}},
	{"zone": "dock", "kind": &"forklift", "pos": Vector3(-2, 0, 13.8), "params": {"yaw": -30}},
	{"zone": "dock", "kind": &"crate_stack", "pos": Vector3(6, 0, 15), "params": {"yaw": 5}},
	{"zone": "dock", "kind": &"crate_stack", "pos": Vector3(20, 0, 16.5), "params": {"yaw": 80}},
	{"zone": "dock", "kind": &"barrel", "pos": Vector3(18.5, 0, 13.5), "params": {}},
	{"zone": "dock", "kind": &"floor_mark", "pos": Vector3(0, 0, 14.8), "params": {"len": 40.0, "w": 0.4}},
	{"zone": "dock", "kind": &"floor_mark", "pos": Vector3(2, 0, 13.2), "params": {"len": 8.0, "w": 4.0, "style": "hazard"}},
	{"zone": "dock", "kind": &"lamp", "pos": Vector3(-10, 0, 15), "params": {"y": 4.6}},
	{"zone": "dock", "kind": &"lamp", "pos": Vector3(8, 0, 15), "params": {"y": 4.6}},
	{"zone": "dock", "kind": &"sign", "pos": Vector3(-4.5, 0, 16.6), "params": {"text": "GATE-0 撤离", "yaw": 180}},
	{"zone": "dock", "kind": &"sign", "pos": Vector3(22.4, 0, -5.5), "params": {"text": "GATE-3 撤离", "yaw": -90}},
	{"zone": "dock", "kind": &"sign", "pos": Vector3(-22.4, 0, -11.4), "params": {"text": "货运电梯 撤离", "yaw": 90}},
]


## 物资箱：固定设施固定点位（工厂的节奏依赖熟悉的箱位）。
const CRATES := [
	{"table": "valuable", "pos": Vector3(8, 0, -15.5), "color": Color(0.5, 0.4, 0.15)},
	{"table": "cache", "pos": Vector3(20, 0, -13.5), "color": Color(0.3, 0.38, 0.22)},
	{"table": "cache", "pos": Vector3(12.4, 2.82, 2.0), "color": Color(0.3, 0.38, 0.22)},
	{"table": "medkit", "pos": Vector3(-19, 0, -10.5), "color": Color(0.55, 0.25, 0.2)},
	{"table": "toolbox", "pos": Vector3(-19.5, 0, 1.0), "color": Color(0.32, 0.32, 0.36)},
	{"table": "food", "pos": Vector3(-19, 0, 8.5), "color": Color(0.42, 0.36, 0.2)},
	{"table": "toolbox", "pos": Vector3(20.5, 0, 9.5), "color": Color(0.32, 0.32, 0.36)},
	{"table": "cache", "pos": Vector3(21, 0, 0.5), "color": Color(0.3, 0.38, 0.22)},
	{"table": "food", "pos": Vector3(-19.5, 0, -15.5), "color": Color(0.42, 0.36, 0.2)},
	{"table": "medkit", "pos": Vector3(-6, 0, -16.5), "color": Color(0.55, 0.25, 0.2)},
	{"table": "toolbox", "pos": Vector3(-4, 0, 15.5), "color": Color(0.32, 0.32, 0.36)},
	{"table": "food", "pos": Vector3(10.5, 0, 16.5), "color": Color(0.42, 0.36, 0.2)},
	{"table": "cache", "pos": Vector3(-7.2, 0, -5.4), "color": Color(0.3, 0.38, 0.22)},
]


## 撤离点：[label, pos]。三处全在墙边门面前。
const EXTRACTS := [
	{"label": "正门 GATE-0", "pos": Vector3(2, 0, 16.2)},
	{"label": "东门 GATE-3", "pos": Vector3(22.6, 0, -8)},
	{"label": "货运电梯", "pos": Vector3(-22.4, 0, -9)},
]


## 出生点：更衣室 / 装卸区东南角 / 东北走廊口 —— 随机或 plan["spawn_idx"]。
const SPAWNS := [
	{"pos": Vector3(-16, 0.05, -9.5), "yaw": -90.0},
	{"pos": Vector3(10, 0.05, 14.2), "yaw": 0.0},
	{"pos": Vector3(19, 0.05, -10.2), "yaw": 90.0},
]


## 室内照明（OmniLight，无阴影保帧率）。lamp 道具负责发光外观。
const LIGHTS := [
	# 主车间暖色高压钠灯
	{"pos": Vector3(-4, 5.1, -4), "energy": 1.5, "range": 11.0, "color": Color(1.0, 0.82, 0.55)},
	{"pos": Vector3(8, 5.1, -4), "energy": 1.5, "range": 11.0, "color": Color(1.0, 0.82, 0.55)},
	{"pos": Vector3(-4, 5.1, 4), "energy": 1.5, "range": 11.0, "color": Color(1.0, 0.82, 0.55)},
	{"pos": Vector3(8, 5.1, 4), "energy": 1.5, "range": 11.0, "color": Color(1.0, 0.82, 0.55)},
	{"pos": Vector3(2, 5.1, 0.5), "energy": 1.3, "range": 10.0, "color": Color(1.0, 0.82, 0.55)},
	# 走廊冷白灯管
	{"pos": Vector3(-14, 3.4, -9.6), "energy": 1.0, "range": 7.0, "color": Color(0.8, 0.9, 1.0)},
	{"pos": Vector3(6, 3.4, -9.6), "energy": 1.0, "range": 7.0, "color": Color(0.8, 0.9, 1.0)},
	{"pos": Vector3(18, 3.4, -9.6), "energy": 1.0, "range": 7.0, "color": Color(0.8, 0.9, 1.0)},
	{"pos": Vector3(-8, 3.4, 10.5), "energy": 1.0, "range": 7.0, "color": Color(0.8, 0.9, 1.0)},
	{"pos": Vector3(10, 3.4, 10.5), "energy": 1.0, "range": 7.0, "color": Color(0.8, 0.9, 1.0)},
	{"pos": Vector3(-10.3, 3.4, -6), "energy": 0.9, "range": 6.0, "color": Color(0.8, 0.9, 1.0)},
	{"pos": Vector3(-10.3, 3.4, 6), "energy": 0.9, "range": 6.0, "color": Color(0.8, 0.9, 1.0)},
	{"pos": Vector3(15.5, 3.4, -6), "energy": 0.9, "range": 6.0, "color": Color(0.8, 0.9, 1.0)},
	{"pos": Vector3(15.5, 3.4, 6), "energy": 0.9, "range": 6.0, "color": Color(0.8, 0.9, 1.0)},
	# 房间
	{"pos": Vector3(-18, 3.4, -14.5), "energy": 0.9, "range": 6.0, "color": Color(0.95, 0.95, 0.9)},
	{"pos": Vector3(-5, 3.4, -14.5), "energy": 0.9, "range": 6.0, "color": Color(0.95, 0.95, 0.9)},
	{"pos": Vector3(8, 3.4, -14.5), "energy": 0.9, "range": 6.0, "color": Color(0.95, 0.95, 0.9)},
	{"pos": Vector3(19, 3.4, -14.5), "energy": 0.9, "range": 6.0, "color": Color(0.95, 0.95, 0.9)},
	{"pos": Vector3(-18, 3.4, -8), "energy": 0.9, "range": 6.0, "color": Color(1.0, 0.85, 0.6)},
	{"pos": Vector3(-18, 3.4, 0), "energy": 0.9, "range": 6.0, "color": Color(0.95, 0.95, 0.9)},
	{"pos": Vector3(-18, 3.4, 8), "energy": 0.9, "range": 6.0, "color": Color(0.95, 0.95, 0.9)},
	{"pos": Vector3(20.5, 3.4, 0), "energy": 0.8, "range": 5.5, "color": Color(1.0, 0.6, 0.45)},
	{"pos": Vector3(20.5, 3.4, 8), "energy": 0.9, "range": 6.0, "color": Color(0.95, 0.95, 0.9)},
	# 装卸区
	{"pos": Vector3(-10, 4.6, 15), "energy": 1.3, "range": 9.0, "color": Color(1.0, 0.85, 0.6)},
	{"pos": Vector3(8, 4.6, 15), "energy": 1.3, "range": 9.0, "color": Color(1.0, 0.85, 0.6)},
]


## 出生点选择：plan["spawn_idx"] 指定，否则随机。
static func pick_spawn(plan: Dictionary) -> Dictionary:
	var idx := int(plan.get("spawn_idx", -1))
	if idx >= 0 and idx < SPAWNS.size():
		return SPAWNS[idx]
	return SPAWNS[randi() % SPAWNS.size()]


## 把整张工厂图搭进 root。plan 只取 spawn_idx（固定设施无变体）。
## 返回 {"crates","extracts","spawn","spawn_yaw","indoor":true,"map_name"}。
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
	var lights := Node3D.new()
	lights.name = "Lights"
	root.add_child(lights)
	for def in LIGHTS:
		lights.add_child(_omni(def))
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
	var spawn: Dictionary = pick_spawn(plan)
	return {
		"crates": crates,
		"extracts": extracts,
		"lights": lights,
		"spawn": spawn["pos"],
		"spawn_yaw": deg_to_rad(float(spawn["yaw"])),
		"indoor": true,
		"map_name": MAP_NAME,
	}


static func _ground(root: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "Ground"
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(MAP_MAX.x - MAP_MIN.x + 8, 0.4, MAP_MAX.y - MAP_MIN.y + 8)
	col.shape = shape
	col.position = Vector3(0, -0.2, 0)
	body.add_child(col)
	root.add_child(body)
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(MAP_MAX.x - MAP_MIN.x + 8, MAP_MAX.y - MAP_MIN.y + 8)
	mesh.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.30, 0.30, 0.31)  # 水磨石地面
	mat.roughness = 0.95
	mesh.material_override = mat
	mesh.position.y = 0.001
	root.add_child(mesh)


static func _omni(def: Dictionary) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = def["pos"]
	l.light_color = def.get("color", Color(1, 1, 1))
	l.light_energy = float(def.get("energy", 1.0))
	l.omni_range = float(def.get("range", 7.0))
	l.omni_attenuation = 1.2
	l.shadow_enabled = false
	return l


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
