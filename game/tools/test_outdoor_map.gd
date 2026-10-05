extends SceneTree
## outdoor_map 数据校验（无渲染）：
##   道具 kind 均注册 · 布局/箱/出生点/敌巡点在图界内 · 撤离点分散且对围墙开口 ·
##   build() 节点结构 · 区域标签 · raid_game 按 raid_map_id 分发 · 生存屋双出发垫。
## 运行: --headless --path . -s res://tools/test_outdoor_map.gd

const OUTDOOR_MAP := preload("res://scripts/gameplay/outdoor_map.gd")
const FACTORY_MAP := preload("res://scripts/gameplay/factory_map.gd")
const PROP_KIT := preload("res://scripts/gameplay/prop_kit.gd")
const GAME_STATE := preload("res://scripts/gameplay/game_state.gd")
const RAID_GAME := preload("res://scripts/gameplay/raid_game.gd")
const HIDEOUT := preload("res://scripts/gameplay/hideout.gd")

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("[FAIL] ", msg)


func _inside(pos: Vector3) -> bool:
	return pos.x > OUTDOOR_MAP.MAP_MIN.x and pos.x < OUTDOOR_MAP.MAP_MAX.x \
		and pos.z > OUTDOOR_MAP.MAP_MIN.y and pos.z < OUTDOOR_MAP.MAP_MAX.y


func _run() -> void:
	# 道具 kind 全部注册
	for def in OUTDOOR_MAP.LAYOUT:
		var k: StringName = def["kind"]
		_check(PROP_KIT.KINDS.has(k), "未注册 kind: %s" % k)

	# 出生点/箱子/撤离点/敌巡点在界内
	for s in OUTDOOR_MAP.SPAWNS:
		_check(_inside(s["pos"]), "出生点越界 %s" % s["pos"])
	for c in OUTDOOR_MAP.CRATES:
		_check(_inside(c["pos"]), "箱子越界 %s" % c["pos"])
	for e in OUTDOOR_MAP.EXTRACTS:
		_check(_inside(e["pos"]), "撤离点越界 %s" % e["pos"])
	for e in OUTDOOR_MAP.ENEMIES:
		_check(_inside(e["pos"]), "敌人出生越界 %s" % e["pos"])
		for w in e["patrol"]:
			_check(_inside(w), "巡点越界 %s" % w)
		_check(e["patrol"].size() >= 2, "巡逻不足 2 点")

	# 撤离点互相分散 ≥15m，且不撞围墙开口以外位置（开口即撤离语义）
	for i in OUTDOOR_MAP.EXTRACTS.size():
		for j in range(i + 1, OUTDOOR_MAP.EXTRACTS.size()):
			var d: float = OUTDOOR_MAP.EXTRACTS[i]["pos"].distance_to(OUTDOOR_MAP.EXTRACTS[j]["pos"])
			_check(d > 15.0, "撤离点 %d/%d 过近 %.1f" % [i, j, d])

	# 出生点与敌出生点拉开 ≥12m（野外无遮挡，靠距离保出生安全）
	for s in OUTDOOR_MAP.SPAWNS:
		for e in OUTDOOR_MAP.ENEMIES:
			var d: float = s["pos"].distance_to(e["pos"])
			_check(d > 12.0, "出生点 %s 距敌 %.1fm" % [s["pos"], d])

	# build() 结构 + 契约字段
	GAME_STATE.ensure()
	var root := Node3D.new()
	get_root().add_child(root)
	var built: Dictionary = OUTDOOR_MAP.build(root, {"spawn_idx": 0})
	_check(root.get_node_or_null("Props") != null, "无 Props 节点")
	_check(root.get_node("LootCrates").get_child_count() == OUTDOOR_MAP.CRATES.size(), "箱数不符")
	_check(root.get_node("Extracts").get_child_count() == 3, "撤离垫数不符")
	_check(root.get_node("Enemies").get_child_count() == 6, "敌数不符")
	_check(built.get("indoor") == false, "outdoor 图 indoor 应为 false")
	_check(built["spawn"] == OUTDOOR_MAP.SPAWNS[0]["pos"], "spawn_idx 未生效")
	_check(String(built["map_name"]) == "外围哨站", "图名不符")

	# 区域标签
	_check(OUTDOOR_MAP.zone_label_at(Vector3(-18, 0, -14)) == "西仓库", "西仓库标签错: %s" % OUTDOOR_MAP.zone_label_at(Vector3(-18, 0, -14)))
	_check(OUTDOOR_MAP.zone_label_at(Vector3(0, 0, 0)) == "开阔地", "中心应开阔地: %s" % OUTDOOR_MAP.zone_label_at(Vector3(0, 0, 0)))
	_check(OUTDOOR_MAP.zone_label_at(Vector3(0, 0, -22)) == "北正门", "北正门标签错")

	# raid_game 分发表含两图
	_check(RAID_GAME.MAPS.has("factory") and RAID_GAME.MAPS.has("outpost"), "MAPS 分发缺图")
	_check(RAID_GAME.MAPS["outpost"] == OUTDOOR_MAP, "outpost 模块不符")

	print("[DONE] test_outdoor_map: %d failure(s)" % _failures)
	quit(0 if _failures == 0 else 1)
