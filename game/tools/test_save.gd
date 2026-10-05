extends SceneTree

## M5 持久化：save_kit 写盘/读回/坏档/清档。重定向 SAVE_PATH 到测试档。

const GAME_STATE := preload("res://scripts/gameplay/game_state.gd")
const SAVE_KIT := preload("res://scripts/gameplay/save_kit.gd")
const EQUIPMENT := preload("res://scripts/gameplay/equipment.gd")

var _fails: Array = []


func _check(ok: bool, msg: String) -> void:
	if not ok:
		_fails.append(msg)
		push_error(msg)


func _init() -> void:
	_run.call_deferred()


func _stash_ids() -> Array:
	var ids: Array = []
	for e in GAME_STATE.stash._entries:
		ids.append(String(e["id"]))
	return ids


func _run() -> void:
	SAVE_KIT.SAVE_PATH = "user://test_save.json"
	SAVE_KIT.wipe()

	# 无档 → has_save false / load false
	_check(not SAVE_KIT.has_save(), "wipe 后仍有档")
	_check(not SAVE_KIT.load_save(), "无档 load 应为 false")

	# 造状态 → 写盘
	GAME_STATE.ensure()
	GAME_STATE.stash.add_item("ak74", 1)
	GAME_STATE.stash.add_item("canned_beef", 4)
	GAME_STATE.backpack.add_item("bandage", 2)
	GAME_STATE.loadout_invs["armor"].add_item("light_armor", 1)
	GAME_STATE.raids_departed = 3
	GAME_STATE.raids_completed = 1
	GAME_STATE.stash_pending = [{"id": "gp_coin", "count": 2, "rotated": false}]
	_check(SAVE_KIT.save(), "save 返回 false")
	_check(SAVE_KIT.has_save(), "save 后无档")

	# 清内存 → 读回
	GAME_STATE.stash.clear()
	GAME_STATE.backpack.clear()
	for slot in GAME_STATE.loadout_invs:
		GAME_STATE.loadout_invs[slot].clear()
	GAME_STATE.raids_departed = 0
	GAME_STATE.raids_completed = 0
	GAME_STATE.stash_pending = []
	_check(SAVE_KIT.load_save(), "load_save 返回 false")
	var ids := _stash_ids()
	_check(ids.has("ak74"), "仓库 ak74 未恢复: %s" % ids)
	_check(ids.has("canned_beef"), "仓库罐头未恢复: %s" % ids)
	_check(GAME_STATE.backpack.entry_count() == 1, "背包件数错: %d" % GAME_STATE.backpack.entry_count())
	_check(GAME_STATE.loadout_invs["armor"].entry_count() == 1, "护甲槽未恢复")
	_check(EQUIPMENT.equipped_id(GAME_STATE.loadout_invs["armor"]) == "light_armor", "装备 id 错")
	_check(GAME_STATE.raids_departed == 3, "departed 未恢复: %d" % GAME_STATE.raids_departed)
	_check(GAME_STATE.raids_completed == 1, "completed 未恢复")
	# stash_pending 在序列化前的 ensure() 里会被 drain：有空间即并入 stash——
	# 语义是「物品不丢」，不是「必须还在队列」。gp_coin 应在仓库或仍排队。
	ids = _stash_ids()
	_check(ids.has("gp_coin") or GAME_STATE.stash_pending.size() == 1,
		"pending 物品丢失: stash=%s pending=%s" % [ids, GAME_STATE.stash_pending])

	# 仓库塞满时 pending 无处可去 → 必须原样存活
	SAVE_KIT.wipe()
	GAME_STATE.ensure()
	var guard := 0
	while GAME_STATE.stash.find_space("ak74", false) != Vector2i(-1, -1) and guard < 64:
		GAME_STATE.stash.add_item("ak74", 1)
		guard += 1
	# 大件剩下的碎片格用 1×1 不可堆叠金币填死——真满仓才有 pending。
	guard = 0
	while GAME_STATE.stash.find_space("gp_coin", false) != Vector2i(-1, -1) and guard < 128:
		GAME_STATE.stash.add_item("gp_coin", 1)
		guard += 1
	GAME_STATE.stash_pending = [{"id": "ai2_medkit", "count": 1, "rotated": false}]
	SAVE_KIT.save()
	GAME_STATE.stash_pending = []
	SAVE_KIT.load_save()
	_check(GAME_STATE.stash_pending.size() == 1 and \
		String(GAME_STATE.stash_pending[0]["id"]) == "ai2_medkit",
		"满仓 pending 未恢复: %s" % [GAME_STATE.stash_pending])

	# 坏档 → false 不崩
	var f := FileAccess.open("user://test_save.json", FileAccess.WRITE)
	f.store_string("{broken json")
	f.close()
	_check(not SAVE_KIT.load_save(), "坏档应返回 false")

	# wipe → 状态清空 + 删档
	SAVE_KIT.wipe()
	_check(GAME_STATE.stash.is_empty(), "wipe 后仓库非空")
	_check(GAME_STATE.raids_departed == 0, "wipe 后 departed 非 0")
	_check(not SAVE_KIT.has_save(), "wipe 后仍有档")

	print("Save checks: %s" % ("PASS" if _fails.is_empty() else str(_fails)))
	quit(0 if _fails.is_empty() else 1)
