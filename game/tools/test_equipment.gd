extends SceneTree

## 装备面板无头测试：槽位过滤/装备数值/背包收放/护甲减伤。
## 运行: godot --headless --path . -s res://tools/test_equipment.gd

const EQUIPMENT := preload("res://scripts/gameplay/equipment.gd")
const INVENTORY := preload("res://scripts/gameplay/inventory.gd")
const GAME_STATE := preload("res://scripts/gameplay/game_state.gd")
const HEALTH := preload("res://scripts/gameplay/health.gd")
const CATALOG := preload("res://scripts/gameplay/item_catalog.gd")
const INVENTORY_UI := preload("res://scripts/gameplay/inventory_ui.gd")

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_catalog()
	_check_accepts()
	_check_slot_filter()
	_check_equipment_values()
	_check_regrid()
	_check_pack_for_raid()
	_check_protection()
	_check_stash_pending()
	_check_transfer_target()
	print("[test_equipment] %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)


func _fail(msg: String) -> void:
	failures += 1
	printerr("  FAIL: " + msg)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_fail(msg)


func _check_catalog() -> void:
	for id in ["pm_pistol", "ak74", "mp133"]:
		_expect(EQUIPMENT.slot_of(id) == "weapon", "%s の slot が weapon でない" % id)
		_expect(not EQUIPMENT.weapon_id_for(id).is_empty(), "%s の weapon 字段缺失" % id)
	for id in ["light_armor", "plate_carrier"]:
		_expect(EQUIPMENT.slot_of(id) == "armor", "%s の slot が armor でない" % id)
	for id in ["scout_bag", "field_pack", "raid_pack"]:
		_expect(EQUIPMENT.slot_of(id) == "pack", "%s の slot が pack でない" % id)
	_expect(EQUIPMENT.slot_of("bandage") == "", "bandage が装備可能扱い")
	_expect(EQUIPMENT.weapon_id_for("pm_pistol") == "pm", "pm_pistol→pm 映射错误")
	_expect(EQUIPMENT.weapon_id_for("ak74") == "ak74", "ak74 映射错误")


func _check_accepts() -> void:
	_expect(EQUIPMENT.accepts("primary", "ak74"), "主武器应接受武器")
	_expect(EQUIPMENT.accepts("secondary", "pm_pistol"), "副武器应接受武器")
	_expect(not EQUIPMENT.accepts("primary", "bandage"), "主武器不应接受绷带")
	_expect(not EQUIPMENT.accepts("armor", "ak74"), "护甲不应接受武器")
	_expect(EQUIPMENT.accepts("armor", "plate_carrier"), "护甲应接受防弹背心")
	_expect(EQUIPMENT.accepts("pack", "scout_bag"), "背包槽应接受挎包")
	_expect(not EQUIPMENT.accepts("pack", "light_armor"), "背包槽不应接受护甲")
	_expect(not EQUIPMENT.accepts("bogus_slot", "ak74"), "未知槽位一律拒绝")


func _check_slot_filter() -> void:
	var dims := EQUIPMENT.slot_dims("armor")
	var slot_inv := INVENTORY.new(dims.x, dims.y)
	slot_inv.item_filter = func(id: String) -> bool:
		return EQUIPMENT.accepts("armor", id) and slot_inv.entry_count() == 0
	_expect(slot_inv.add_item("bandage", 1) == 1, "过滤器放行绷带")
	_expect(slot_inv.is_empty(), "过滤器后槽位仍被放入")
	_expect(not slot_inv.can_place("ak74", Vector2i(0, 0)), "can_place 放行武器进护甲槽")
	_expect(slot_inv.add_item("light_armor", 1) == 0, "过滤器拒绝合法护甲")
	_expect(EQUIPMENT.equipped_id(slot_inv) == "light_armor", "equipped_id 读不到护甲")
	# 一件为止: 格子还有空位同类品也被拒
	_expect(slot_inv.add_item("plate_carrier", 1) == 1, "槽位应只装一件")
	# 卸下后可再装
	slot_inv.clear()
	_expect(slot_inv.add_item("plate_carrier", 1) == 0, "卸下后不能再装备")


func _check_equipment_values() -> void:
	var loadout: Dictionary = {}
	for slot in EQUIPMENT.SLOTS:
		var dims := EQUIPMENT.slot_dims(slot)
		loadout[slot] = INVENTORY.new(dims.x, dims.y)
	loadout["armor"].add_item("light_armor", 1)
	_expect(absf(EQUIPMENT.armor_reduction(loadout) - 0.25) < 0.001, "简易护甲减伤非 0.25")
	loadout["armor"].clear()
	loadout["armor"].add_item("plate_carrier", 1)
	_expect(absf(EQUIPMENT.armor_reduction(loadout) - 0.45) < 0.001, "插板背心减伤非 0.45")
	loadout["pack"].add_item("field_pack", 1)
	_expect(EQUIPMENT.pack_grid(loadout) == Vector2i(8, 5), "野战背包格子非 8x5")
	_expect(absf(EQUIPMENT.pack_cap(loadout) - 40.0) < 0.001, "野战背包限重非 40")
	loadout["pack"].clear()
	_expect(EQUIPMENT.pack_grid(loadout) == EQUIPMENT.POCKET_GRID, "无背包应回退口袋格")
	_expect(absf(EQUIPMENT.pack_cap(loadout) - EQUIPMENT.POCKET_CAP) < 0.001, "无背包应回退口袋限重")
	loadout["primary"].add_item("ak74", 1)
	var weapons := EQUIPMENT.equipped_weapons(loadout)
	_expect(weapons[0] == "ak74" and weapons[1].is_empty(), "equipped_weapons 返回错误")


func _check_regrid() -> void:
	var inv := INVENTORY.new(8, 5, 40.0)
	inv.add_item("toolset", 1, Vector2i(0, 0))
	inv.add_item("gp_coin", 2, Vector2i(6, 4))
	# 回归 (PR#22 review): 缩容到更低限重 —— 超重物品须溢出而非塞回
	var heavy := INVENTORY.new(8, 5, 40.0)
	for i in 6:
		heavy.add_item("toolset", 1)  # 1.8kg x6 = 10.8kg
	var heavy_over: Array = heavy.regrid(Vector2i(8, 5), 5.0)
	_expect(heavy.total_weight() <= 5.0 + 0.001, "regrid 未执行新限重")
	var heavy_kept := heavy.count_of("toolset")
	var heavy_lost := 0
	for item in heavy_over:
		heavy_lost += int(item["count"])
	_expect(heavy_kept + heavy_lost == 6, "限重 regrid 丢物品(%d+%d)" % [heavy_kept, heavy_lost])
	# 缩小到 6x4: gp_coin at (6,4) 越界 → 退回 find_space(放 1x1 物件总还能找到) 或 overflow
	var overflow: Array = inv.regrid(Vector2i(6, 4), 25.0)
	_expect(inv.grid_size == Vector2i(6, 4), "regrid 未改格子")
	var kept_units := inv.count_of("toolset") + inv.count_of("gp_coin")
	var overflow_units := 0
	for item in overflow:
		overflow_units += int(item["count"])
	_expect(kept_units + overflow_units == 3, "regrid 丢物品(kept %d + overflow %d != 3)" % [kept_units, overflow_units])
	_expect(inv.count_of("toolset") == 1, "toolset 应保留")
	# 极端缩小: 3x2 放不下 2x2 工具组 → overflow 返回且不丢
	var inv2 := INVENTORY.new(8, 5, 40.0)
	inv2.add_item("toolset", 1)
	inv2.add_item("plate_carrier", 1)
	inv2.add_item("gp_coin", 1)
	var overflow2: Array = inv2.regrid(EQUIPMENT.POCKET_GRID, EQUIPMENT.POCKET_CAP)
	_expect(overflow2.size() >= 1, "缩容溢出未返回")
	var kept = inv2.entry_count()
	var lost = 3 - kept - overflow2.size()
	_expect(lost == 0, "regrid 有物品消失")
	for item in overflow2:
		_expect(item.has("id") and item.has("count"), "overflow 条目格式错误")


func _check_pack_for_raid() -> void:
	GAME_STATE.ensure()
	var stash := GAME_STATE.stash
	var pack := GAME_STATE.backpack
	var loadout: Dictionary = GAME_STATE.loadout_invs
	# 干净起点
	for slot in EQUIPMENT.SLOTS:
		loadout[slot].clear()
	stash.clear()
	pack.clear()
	# 装满大物换小挎包: 8 件 2x2 工具组装不进 6x4(最多 6 件) → 溢出回仓库
	GAME_STATE.stash_pending.clear()
	loadout["pack"].add_item("scout_bag", 1)
	for i in 8:
		pack.add_item("toolset", 1)
	var stash_before = stash.count_of("toolset")
	GAME_STATE.pack_for_raid()
	_expect(pack.grid_size == Vector2i(6, 4), "pack_for_raid 未按挎包缩容")
	_expect(absf(pack.weight_limit - 25.0) < 0.001, "pack_for_raid 未按挎包限重")
	var total = pack.count_of("toolset") + stash.count_of("toolset") - stash_before
	_expect(total == 8, "pack_for_raid 丢物品(%d)" % total)
	_expect(stash.count_of("toolset") > stash_before, "溢出物未回仓库")
	# 无装备背包 → 口袋格
	loadout["pack"].clear()
	pack.clear()
	stash.clear()
	GAME_STATE.pack_for_raid()
	_expect(pack.grid_size == EQUIPMENT.POCKET_GRID, "无背包未回退口袋格")
	# 恢复默认状态以免影响其他测试
	pack.clear()
	loadout["pack"].add_item("field_pack", 1)
	GAME_STATE.pack_for_raid()
	loadout["pack"].clear()
	pack.clear()


## 回归 (PR#22 review): 仓库满载时 pack_for_raid 溢出进 stash_pending 排队，
## 腾位后 drain 补齐 —— 绝不丢物品。
func _check_stash_pending() -> void:
	GAME_STATE.ensure()
	var stash := GAME_STATE.stash
	var pack := GAME_STATE.backpack
	GAME_STATE.stash_pending.clear()
	for slot in EQUIPMENT.SLOTS:
		GAME_STATE.loadout_invs[slot].clear()
	stash.clear()
	pack.clear()
	# 仓库缩到 1x1 并占满 → 溢出无处去只能排队
	stash.regrid(Vector2i(1, 1), -1.0)
	stash.add_item("gp_coin", 1)
	GAME_STATE.loadout_invs["pack"].add_item("scout_bag", 1)
	for i in 8:
		pack.add_item("toolset", 1)  # 6x4 只装 6 件 → 2 件溢出
	GAME_STATE.pack_for_raid()
	_expect(GAME_STATE.stash_pending.size() >= 1, "仓库满载溢出未入 stash_pending")
	var queued := 0
	for item in GAME_STATE.stash_pending:
		queued += int(item["count"])
	_expect(pack.count_of("toolset") + queued + stash.count_of("toolset") == 8, "缩容丢物品")
	# 腾位后 drain 归队（日常触发由 hideout 在空拖状态时调用）
	stash.take_at(Vector2i(0, 0))
	stash.regrid(Vector2i(10, 8), -1.0)
	GAME_STATE.drain_stash_pending()
	_expect(GAME_STATE.stash_pending.is_empty(), "drain 后仍有排队物")
	_expect(stash.count_of("toolset") >= queued, "drain 丢物品")
	for slot in EQUIPMENT.SLOTS:
		GAME_STATE.loadout_invs[slot].clear()
	stash.clear()
	pack.clear()


## 回归 (PR#22 review): 快捷转移应落到接受该品类的面板 —— 槽位面板只收装备品，
## 普通物右键必须进背包而不是被槽位吞掉。
func _check_transfer_target() -> void:
	var root := get_root()
	var stash_ui := INVENTORY_UI.new()
	var stash := INVENTORY.new(10, 8)
	stash.add_item("gp_coin", 1, Vector2i(0, 0))
	stash.add_item("light_armor", 1, Vector2i(2, 0))
	root.add_child(stash_ui)
	stash_ui.setup(stash, "stash")
	var pack_ui := INVENTORY_UI.new()
	var pack := INVENTORY.new(6, 4, 25.0)
	root.add_child(pack_ui)
	pack_ui.setup(pack, "pack")
	stash_ui.link(pack_ui)
	var slot_ui := INVENTORY_UI.new()
	var slot := INVENTORY.new(2, 3)
	slot.item_filter = func(id: String) -> bool:
		return EQUIPMENT.accepts("armor", id) and slot.entry_count() == 0
	root.add_child(slot_ui)
	slot_ui.setup(slot, "armor")
	stash_ui.link(slot_ui)  # linked=slot 面板 —— 回归: 普通物不能再被吞
	stash_ui.click_cell(Vector2i(0, 0), MOUSE_BUTTON_RIGHT)
	_expect(pack.count_of("gp_coin") == 1, "快捷转移未进背包")
	_expect(stash.count_of("gp_coin") == 0, "快捷转移未离开仓库")
	# 装備品右键 → 优先装进槽位面板（带过滤器的面板先选）
	stash_ui.click_cell(Vector2i(2, 0), MOUSE_BUTTON_RIGHT)
	_expect(slot.count_of("light_armor") == 1, "装备品未装进槽位")
	_expect(stash.count_of("light_armor") == 0, "装备品未离开仓库")
	# 槽位出发的右键 = 卸下 → 回无过滤面板（仓库），不去别的槽位
	var slot2_ui := INVENTORY_UI.new()
	var slot2 := INVENTORY.new(2, 3)
	slot2.item_filter = func(id: String) -> bool:
		return EQUIPMENT.accepts("armor", id) and slot2.entry_count() == 0
	root.add_child(slot2_ui)
	slot2_ui.setup(slot2, "armor2")
	stash_ui.link(slot2_ui)
	slot_ui.click_cell(Vector2i(0, 0), MOUSE_BUTTON_RIGHT)
	_expect(slot.count_of("light_armor") == 0, "卸下未离开槽位")
	_expect(slot2.count_of("light_armor") == 0, "卸下竟去了别的槽位")
	_expect(stash.count_of("light_armor") == 1 or pack.count_of("light_armor") == 1, "卸下未回普通容器")
	stash_ui.queue_free()
	pack_ui.queue_free()
	slot_ui.queue_free()
	slot2_ui.queue_free()


func _check_protection() -> void:
	var h := HEALTH.new()
	get_root().add_child(h)
	h.tick_enabled = false
	h.hp = 100.0
	h.max_hp = 100.0
	h.protection = 0.0
	_expect(absf(h.damage(20.0) - 20.0) < 0.001, "无护甲减伤异常")
	h.protection = 0.25
	_expect(absf(h.damage(20.0) - 15.0) < 0.001, "0.25 减伤未生效(实际 %s)" % str(h.damage(0.0)))
	_expect(absf(h.hp - 65.0) < 0.001, "减伤后 HP 错误")
	h.protection = 0.99  # clamp 0.9
	_expect(absf(h.damage(10.0) - 1.0) < 0.001, "protection 上限未 clamp")
	h.free()
