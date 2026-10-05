extends RefCounted

## 持久化存档：stash/背包/装备槽/统计/待入队 → user://save.json。
## 塔科夫循环的核心是「仓库跨会话留存」——静态变量只活一局进程，
## 重启即丢。保存点：撤离结算后 / 阵亡·MIA 回屋前 / 出发时 / 生存屋关窗。
## 中途退 raid = 弃局（背包按 MIA 语义丢，不写盘）。

const GAME_STATE := preload("res://scripts/gameplay/game_state.gd")

## 存档路径：static var 非 const——测试可重定向到独立文件，不污染真实档。
static var SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1


## 当前状态序列化（JSON 可写：只含 int/float/String/Array/Dictionary）。
## strip_raid：出发时的在局快照——背包/raid_pending 剥为空 + in_raid 标记，
## 中途弃局重启 = MIA 丢包语义（review BUG_0001：否则背包永保出发时值）。
static func serialize(strip_raid: bool = false) -> Dictionary:
	GAME_STATE.ensure()
	var loadout := {}
	for slot in GAME_STATE.loadout_invs:
		loadout[String(slot)] = GAME_STATE.loadout_invs[slot].serialize()
	return {
		"version": SAVE_VERSION,
		"stash": GAME_STATE.stash.serialize(),
		"backpack": {} if strip_raid else GAME_STATE.backpack.serialize(),
		"loadout": loadout,
		"stash_pending": GAME_STATE.stash_pending.duplicate(),
		"raid_pending": [] if strip_raid else GAME_STATE.raid_pending.duplicate(),
		"raids_completed": GAME_STATE.raids_completed,
		"raids_departed": GAME_STATE.raids_departed,
		"raid_map_id": String(GAME_STATE.raid_map_id),
		"in_raid": strip_raid,
		"saved_at": Time.get_unix_time_from_system(),
	}


## 写盘。返回是否成功（不抛——存档失败不该崩游戏，记 [SAVE] 日志）。
static func save() -> bool:
	return _write(serialize())


## 出发专用：写入「在局中」快照（背包剥离），弃局重启即 MIA。
static func save_inraid() -> bool:
	return _write(serialize(true))


static func _write(blob: Dictionary) -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("[SAVE] open for write failed: %s" % FileAccess.get_open_error())
		return false
	f.store_string(JSON.stringify(blob))
	f.close()
	print("[SAVE] written stash=%d pack=%d" % [GAME_STATE.stash.entry_count(), GAME_STATE.backpack.entry_count()])
	return true


static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## 菜单「继续」门槛：文件在且能解析、版本兼容——坏档不应显示可继续
## （review BUG_0001：坏档点继续→读档失败→发初始物资→还可能覆盖原档）。
static func has_valid_save() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	return typeof(data) == TYPE_DICTIONARY and data.get("version", 0) == SAVE_VERSION


## 读盘恢复。无档/坏档返回 false（调用方按新档走发物资流程）。
static func load_save() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY or data.get("version", 0) != SAVE_VERSION:
		push_warning("[SAVE] incompatible/corrupt save ignored")
		return false
	GAME_STATE.ensure()
	GAME_STATE.stash.load_data(data.get("stash", {}))
	# 突击背囊会让背包扩大到 9×6/55kg：先按存档的尺寸/限重 regrid 再装，
	# 否则超过默认 8×5/40 的物资装不下被丢（review BUG_0002）。
	var bd: Dictionary = data.get("backpack", {})
	if not bd.is_empty():
		var grid: Array = bd.get("grid", [8, 5])
		GAME_STATE.backpack.regrid(
			Vector2i(int(grid[0]), int(grid[1])),
			float(bd.get("weight_limit", 40.0)))
	var loadout: Dictionary = data.get("loadout", {})
	for slot in loadout:
		if GAME_STATE.loadout_invs.has(StringName(slot)):
			GAME_STATE.loadout_invs[StringName(slot)].load_data(loadout[slot])
	var pack_left: Array = GAME_STATE.backpack.load_data(bd)
	GAME_STATE.stash_pending = data.get("stash_pending", [])
	GAME_STATE.raid_pending = data.get("raid_pending", [])
	# 装不下的背包物进待入队——必须在 pending 赋档值之后追加，否则被覆盖。
	for it in pack_left:
		GAME_STATE.stash_pending.append(it)  # 装不下的进待入队，永不丢
	GAME_STATE.raids_completed = int(data.get("raids_completed", 0))
	GAME_STATE.raids_departed = int(data.get("raids_departed", 0))
	GAME_STATE.raid_map_id = String(data.get("raid_map_id", "factory"))
	print("[SAVE] loaded stash=%d pack=%d departed=%d" % [
		GAME_STATE.stash.entry_count(), GAME_STATE.backpack.entry_count(), GAME_STATE.raids_departed])
	return true


## 新档/重置：删档 + 清内存态（重开新周目）。返回删档是否成功——
## 失败时调用方应拦下（否则旧档仍在，读档链会恢复旧进度，review BUG_0002）。
static func wipe() -> bool:
	if has_save():
		var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		if err != OK:
			push_warning("[SAVE] wipe failed: %s" % error_string(err))
			return false
	GAME_STATE.ensure()
	GAME_STATE.stash.clear()
	GAME_STATE.backpack.clear()
	for slot in GAME_STATE.loadout_invs:
		GAME_STATE.loadout_invs[slot].clear()
	GAME_STATE.stash_pending = []
	GAME_STATE.raid_pending = []
	GAME_STATE.raids_completed = 0
	GAME_STATE.raids_departed = 0
	print("[SAVE] wiped")
	return true
