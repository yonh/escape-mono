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
static func serialize() -> Dictionary:
	GAME_STATE.ensure()
	var loadout := {}
	for slot in GAME_STATE.loadout_invs:
		loadout[String(slot)] = GAME_STATE.loadout_invs[slot].serialize()
	return {
		"version": SAVE_VERSION,
		"stash": GAME_STATE.stash.serialize(),
		"backpack": GAME_STATE.backpack.serialize(),
		"loadout": loadout,
		"stash_pending": GAME_STATE.stash_pending.duplicate(),
		"raid_pending": GAME_STATE.raid_pending.duplicate(),
		"raids_completed": GAME_STATE.raids_completed,
		"raids_departed": GAME_STATE.raids_departed,
		"raid_map_id": String(GAME_STATE.raid_map_id),
		"saved_at": Time.get_unix_time_from_system(),
	}


## 写盘。返回是否成功（不抛——存档失败不该崩游戏，记 [SAVE] 日志）。
static func save() -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("[SAVE] open for write failed: %s" % FileAccess.get_open_error())
		return false
	f.store_string(JSON.stringify(serialize()))
	f.close()
	print("[SAVE] written stash=%d pack=%d" % [GAME_STATE.stash.entry_count(), GAME_STATE.backpack.entry_count()])
	return true


static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


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
	GAME_STATE.backpack.load_data(data.get("backpack", {}))
	var loadout: Dictionary = data.get("loadout", {})
	for slot in loadout:
		if GAME_STATE.loadout_invs.has(StringName(slot)):
			GAME_STATE.loadout_invs[StringName(slot)].load_data(loadout[slot])
	GAME_STATE.stash_pending = data.get("stash_pending", [])
	GAME_STATE.raid_pending = data.get("raid_pending", [])
	GAME_STATE.raids_completed = int(data.get("raids_completed", 0))
	GAME_STATE.raids_departed = int(data.get("raids_departed", 0))
	GAME_STATE.raid_map_id = String(data.get("raid_map_id", "factory"))
	print("[SAVE] loaded stash=%d pack=%d departed=%d" % [
		GAME_STATE.stash.entry_count(), GAME_STATE.backpack.entry_count(), GAME_STATE.raids_departed])
	return true


## 新档/重置：删档 + 清内存态（重开新周目）。
static func wipe() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
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
