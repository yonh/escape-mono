extends RefCounted

## Cross-scene state. Statics live on the script class, so the stash and
## backpack inventories survive scene switches between 生存屋 and the raid
## map without an autoload.

const INVENTORY := preload("res://scripts/gameplay/inventory.gd")
const EQUIPMENT := preload("res://scripts/gameplay/equipment.gd")

## Stash: big hideout warehouse, no weight cap.
static var stash: RefCounted = null
## Backpack: what the player carries into a raid.
static var backpack: RefCounted = null
## Loadout slots: 主武器/副武器/护甲/背包 — each a 1×1 inventory that only
## accepts its item kind. Equipped gear lives in these grids and persists
## across scenes (and deaths, for now).
static var loadout_invs: Dictionary = {}
## Stacks sitting "in the player's hands" between loot-view sessions:
## released from a closed view but with no grid that could take them.
## Extracted loot rules apply — carried out on extract, lost on death.
static var raid_pending: Array = []
## Completed raid runs (successful extracts).
static var raids_completed := 0
## Raid 出发次数（含阵亡局）。首局种子用它判定“是否第一次玩”，
## 因为 completed 只算成功撤离、无法区分新手与连败。
static var raids_departed := 0
## Items that could not return into a full stash (e.g. pack_for_raid
## overflow). Queued, never dropped — drained whenever the stash changes.
static var stash_pending: Array = []
## 本局 raid 的地图方案（出发前写入，raid_game 读取；空 = 默认）。
static var raid_plan: Dictionary = {}
## 本局 raid 的地图 id：当前仅 "factory" 工厂。
## 出发前由生存屋写入，raid_game 依此分发 build。
static var raid_map_id := "factory"
static var _draining_stash := false


## Lazily build both inventories; called by every scene that touches them.
static func ensure() -> void:
	if stash == null:
		stash = INVENTORY.new(10, 8)
	if backpack == null:
		backpack = INVENTORY.new(8, 5, 40.0)
	if loadout_invs.is_empty():
		for slot in EQUIPMENT.SLOTS:
			var dims := EQUIPMENT.slot_dims(slot)
			var slot_inv := INVENTORY.new(dims.x, dims.y)
			# 品类 + 一件为止（拖拽时持物已离开格子 → 此时空格才算可放）。
			slot_inv.item_filter = func(id: String) -> bool:
				return EQUIPMENT.accepts(slot, id) and slot_inv.entry_count() == 0
			loadout_invs[slot] = slot_inv
	# 场景入口先尝试补队；日常腾位的即时补队由 hideout 在确认没有拖拽中
	# 持物后触发（直接挂 changed 会在取物腾格瞬间把格子再占掉）。
	drain_stash_pending()


## Equipped item id in a slot ("" when empty).
static func equipped_id(slot: String) -> String:
	return EQUIPMENT.equipped_id(loadout_invs.get(slot))


## Armor reduction from the equipped armor (0 when none).
static func armor_reduction() -> float:
	return EQUIPMENT.armor_reduction(loadout_invs)


## Equipped weapon ids (primary, secondary; "" when the slot is empty).
static func equipped_weapons() -> Array[String]:
	return EQUIPMENT.equipped_weapons(loadout_invs)


## Resize the raid backpack to the equipped pack before departure.
## Entries that no longer fit go back to the stash — never dropped.
static func pack_for_raid() -> void:
	var dims := EQUIPMENT.pack_grid(loadout_invs)
	var cap := EQUIPMENT.pack_cap(loadout_invs)
	if backpack.grid_size == dims and backpack.weight_limit == cap:
		return
	var leftovers: Array = backpack.regrid(dims, cap)
	for item in leftovers:
		var left = stash.add_item(String(item["id"]), int(item["count"]), Vector2i(-1, -1), bool(item.get("rotated", false)))
		if left > 0:
			# 仓库已满也绝不丢物品 —— 排队等下次腾位。
			stash_pending.append({"id": String(item["id"]), "count": left, "rotated": bool(item.get("rotated", false))})


## Retry queued stash overflow: place what fits now, keep the rest queued.
## Reentrancy-guarded — hooked to stash.changed, which its own adds re-fire.
static func drain_stash_pending() -> void:
	if _draining_stash or stash == null or stash_pending.is_empty():
		return
	_draining_stash = true
	var rest: Array = []
	for item in stash_pending:
		var left = stash.add_item(String(item["id"]), int(item["count"]), Vector2i(-1, -1), bool(item.get("rotated", false)))
		if left > 0:
			rest.append({"id": String(item["id"]), "count": left, "rotated": bool(item.get("rotated", false))})
	stash_pending = rest
	_draining_stash = false


## Replace an inventory's contents with a serialized blob (empty = reset).
static func restore(inv: RefCounted, data: Dictionary) -> void:
	inv.load_data(data)
