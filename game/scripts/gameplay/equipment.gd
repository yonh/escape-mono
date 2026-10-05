extends RefCounted

## 装备槽位系统（装备面板）: 主武器/副武器/护甲/背包 四个槽位的规则与效果。
## 槽位本身是 game_state.loadout_invs 里的 1×1 inventory（带 item_filter），
## 这里只做「什么物品能进哪个槽位 / 装备产生什么数值」的纯函数。
##
## 物品通过 item_catalog 的 `slot` 字段声明类型:
##   "weapon" → 可进主武器或副武器槽位（`weapon` 字段给出 weapon_data id）
##   "armor"  → 护甲槽位（`reduction` = 减伤比例）
##   "pack"   → 背包槽位（`pack_grid`/`pack_cap` = 出 raid 时的背包格数与限重）

const CATALOG := preload("res://scripts/gameplay/item_catalog.gd")

const SLOT_WEAPON := &"weapon"
const SLOT_ARMOR := &"armor"
const SLOT_PACK := &"pack"

## 槽位 id → 显示名（中文）。
const SLOT_NAMES := {
	"primary": "主武器",
	"secondary": "副武器",
	"armor": "护甲",
	"pack": "背包",
}
## 槽位 id → 接受的物品 slot 类型。
const SLOT_ACCEPTS := {
	"primary": SLOT_WEAPON,
	"secondary": SLOT_WEAPON,
	"armor": SLOT_ARMOR,
	"pack": SLOT_PACK,
}
const SLOTS: Array[String] = ["primary", "secondary", "armor", "pack"]

## 槽位面板的格子尺寸（能放下该品类最大物品；每件只能放一件，
## 「一件为止」由槽位 inventory 的 entry_count==0 过滤约束）。
const SLOT_DIMS := {
	"primary": Vector2i(4, 2),
	"secondary": Vector2i(4, 2),
	"armor": Vector2i(2, 3),
	"pack": Vector2i(4, 3),
}

## 未装备背包时的口袋容量（没有背包只能带很少东西）。
const POCKET_GRID := Vector2i(3, 2)
const POCKET_CAP := 8.0


## 槽位面板的格子尺寸。
static func slot_dims(slot: String) -> Vector2i:
	return SLOT_DIMS.get(slot, Vector2i.ONE)


## 物品声明的槽位类型（"weapon"/"armor"/"pack"，无则为 ""）。
static func slot_of(item_id: String) -> String:
	return String(CATALOG.get_def(item_id).get("slot", ""))


## 槽位 `slot` 能否装物品 `item_id`。
static func accepts(slot: String, item_id: String) -> bool:
	var want: StringName = SLOT_ACCEPTS.get(slot, &"")
	return want != &"" and slot_of(item_id) == String(want)


## 槽位 inventory 里当前装备的物品 id（无则 ""）。
static func equipped_id(slot_inv: RefCounted) -> String:
	if slot_inv == null or slot_inv.is_empty():
		return ""
	return String(slot_inv.entries()[0]["id"])


## 武器物品 → weapon_data 的 id（非武器返回 ""）。
static func weapon_id_for(item_id: String) -> String:
	return String(CATALOG.get_def(item_id).get("weapon", ""))


## 装备栏护甲给的减伤比例（无护甲 0.0，clamp 0.9 上限）。
static func armor_reduction(loadout_invs: Dictionary) -> float:
	var id := equipped_id(loadout_invs.get("armor"))
	return clampf(float(CATALOG.get_def(id).get("reduction", 0.0)), 0.0, 0.9)


## 出 raid 时的背包格数（未装备背包 → 口袋）。
static func pack_grid(loadout_invs: Dictionary) -> Vector2i:
	var id := equipped_id(loadout_invs.get("pack"))
	var grid: Array = CATALOG.get_def(id).get("pack_grid", [])
	if grid.size() == 2:
		return Vector2i(int(grid[0]), int(grid[1]))
	return POCKET_GRID


## 出 raid 时的背包限重（未装备背包 → 口袋）。
static func pack_cap(loadout_invs: Dictionary) -> float:
	var id := equipped_id(loadout_invs.get("pack"))
	return float(CATALOG.get_def(id).get("pack_cap", POCKET_CAP))


## 主/副武器槽位装的武器 id 列表（槽位顺序）。
static func equipped_weapons(loadout_invs: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for slot in ["primary", "secondary"]:
		var wid := weapon_id_for(equipped_id(loadout_invs.get(slot)))
		out.append(wid)
	return out
