extends RefCounted

## Static item definitions for the survival-loot gameplay systems.
## size: inventory grid cells (x = wide, y = tall). weight: kg per unit.
## max_stack: per-cell stack limit. value: rough barter worth in roubles.
## color: UI placeholder tint until real icons exist.

const CATEGORY_NAMES := {
	"weapon": "武器",
	"ammo": "弹药",
	"medical": "医疗",
	"food": "食物",
	"material": "材料",
	"valuable": "贵重品",
	"key": "钥匙",
	"container": "容器",
	"armor": "护甲",
	"pack": "背包",
}

const DEFS := {
	# Weapons — slot="weapon" + weapon 字段(对应 weapon_data 的 id) 使其可装入武器槽位
	"pm_pistol": {"name": "PM 手枪", "size": Vector2i(2, 1), "weight": 0.73, "max_stack": 1, "value": 6000, "category": "weapon", "slot": "weapon", "weapon": "pm", "color": Color(0.45, 0.45, 0.5)},
	"ak74": {"name": "AK-74 步枪", "size": Vector2i(4, 2), "weight": 3.3, "max_stack": 1, "value": 42000, "category": "weapon", "slot": "weapon", "weapon": "ak74", "color": Color(0.4, 0.32, 0.22)},
	"mp133": {"name": "MP-133 霰弹枪", "size": Vector2i(4, 1), "weight": 3.2, "max_stack": 1, "value": 18000, "category": "weapon", "slot": "weapon", "weapon": "mp133", "color": Color(0.42, 0.35, 0.25)},
	# Ammo
	"ammo_9x18": {"name": "9x18 弹药", "size": Vector2i(1, 1), "weight": 0.01, "max_stack": 60, "value": 30, "category": "ammo", "color": Color(0.7, 0.6, 0.3)},
	"ammo_545": {"name": "5.45 弹药", "size": Vector2i(1, 1), "weight": 0.01, "max_stack": 60, "value": 45, "category": "ammo", "color": Color(0.72, 0.62, 0.32)},
	"ammo_12g": {"name": "12 号霰弹", "size": Vector2i(1, 1), "weight": 0.05, "max_stack": 20, "value": 60, "category": "ammo", "color": Color(0.75, 0.4, 0.25)},
	# Magazines
	"pm_mag": {"name": "PM 弹匣", "size": Vector2i(1, 1), "weight": 0.12, "max_stack": 4, "value": 1200, "category": "ammo", "color": Color(0.5, 0.5, 0.55)},
	"ak_mag": {"name": "AK 弹匣", "size": Vector2i(1, 2), "weight": 0.23, "max_stack": 4, "value": 2500, "category": "ammo", "color": Color(0.5, 0.42, 0.35)},
	# Medical
	"bandage": {"name": "绷带", "size": Vector2i(1, 1), "weight": 0.05, "max_stack": 4, "value": 800, "category": "medical", "color": Color(0.85, 0.85, 0.8)},
	"ai2_medkit": {"name": "AI-2 急救包", "size": Vector2i(1, 1), "weight": 0.4, "max_stack": 1, "value": 3500, "category": "medical", "color": Color(0.85, 0.4, 0.2)},
	"salewa": {"name": "Salewa 医疗包", "size": Vector2i(2, 1), "weight": 0.6, "max_stack": 1, "value": 9000, "category": "medical", "color": Color(0.8, 0.25, 0.2)},
	"painkillers": {"name": "止痛药", "size": Vector2i(1, 1), "weight": 0.1, "max_stack": 6, "value": 2200, "category": "medical", "color": Color(0.9, 0.8, 0.6)},
	# Food & drink
	"canned_beef": {"name": "牛肉罐头", "size": Vector2i(1, 1), "weight": 0.45, "max_stack": 4, "value": 1500, "category": "food", "color": Color(0.6, 0.5, 0.35)},
	"crackers": {"name": "压缩饼干", "size": Vector2i(1, 1), "weight": 0.2, "max_stack": 4, "value": 900, "category": "food", "color": Color(0.75, 0.65, 0.45)},
	"water_bottle": {"name": "瓶装水", "size": Vector2i(1, 2), "weight": 0.6, "max_stack": 1, "value": 1200, "category": "food", "color": Color(0.4, 0.6, 0.8)},
	"energy_drink": {"name": "能量饮料", "size": Vector2i(1, 1), "weight": 0.25, "max_stack": 4, "value": 1600, "category": "food", "color": Color(0.9, 0.7, 0.1)},
	# Materials
	"scrap_metal": {"name": "废金属", "size": Vector2i(1, 2), "weight": 1.2, "max_stack": 4, "value": 1800, "category": "material", "color": Color(0.5, 0.52, 0.55)},
	"wire": {"name": "电线", "size": Vector2i(1, 1), "weight": 0.15, "max_stack": 8, "value": 1400, "category": "material", "color": Color(0.8, 0.5, 0.2)},
	"bolts": {"name": "螺栓", "size": Vector2i(1, 1), "weight": 0.3, "max_stack": 10, "value": 1000, "category": "material", "color": Color(0.55, 0.55, 0.6)},
	"duct_tape": {"name": "胶带", "size": Vector2i(1, 1), "weight": 0.12, "max_stack": 4, "value": 2500, "category": "material", "color": Color(0.6, 0.6, 0.65)},
	"toolset": {"name": "工具组", "size": Vector2i(2, 2), "weight": 1.8, "max_stack": 1, "value": 15000, "category": "material", "color": Color(0.65, 0.45, 0.3)},
	# Valuables
	"gold_chain": {"name": "金项链", "size": Vector2i(1, 1), "weight": 0.08, "max_stack": 1, "value": 22000, "category": "valuable", "color": Color(0.95, 0.8, 0.2)},
	"roler_watch": {"name": "Roler 手表", "size": Vector2i(1, 1), "weight": 0.12, "max_stack": 1, "value": 38000, "category": "valuable", "color": Color(0.9, 0.85, 0.5)},
	"mil_circuit": {"name": "军用电路板", "size": Vector2i(2, 1), "weight": 0.3, "max_stack": 1, "value": 26000, "category": "valuable", "color": Color(0.3, 0.6, 0.45)},
	"gp_coin": {"name": "GP 金币", "size": Vector2i(1, 1), "weight": 0.05, "max_stack": 1, "value": 30000, "category": "valuable", "color": Color(0.98, 0.85, 0.35)},
	# Keys
	"dorm_key": {"name": "宿舍钥匙", "size": Vector2i(1, 1), "weight": 0.02, "max_stack": 1, "value": 12000, "category": "key", "color": Color(0.75, 0.65, 0.4)},
	"keycard_red": {"name": "红色钥匙卡", "size": Vector2i(1, 1), "weight": 0.02, "max_stack": 1, "value": 85000, "category": "key", "color": Color(0.85, 0.15, 0.15)},
	# Armor — slot="armor" + reduction(减伤比例 0..1) 使其可装入护甲槽位
	"light_armor": {"name": "简易护甲", "size": Vector2i(2, 2), "weight": 3.6, "max_stack": 1, "value": 15000, "category": "armor", "slot": "armor", "reduction": 0.25, "color": Color(0.35, 0.42, 0.4)},
	"plate_carrier": {"name": "防弹插板背心", "size": Vector2i(2, 3), "weight": 5.8, "max_stack": 1, "value": 45000, "category": "armor", "slot": "armor", "reduction": 0.45, "color": Color(0.25, 0.32, 0.38)},
	# Packs — slot="pack" + pack_grid(背包格数)/pack_cap(限重kg) 使其可装入背包槽位
	"scout_bag": {"name": "侦查挎包", "size": Vector2i(3, 2), "weight": 0.9, "max_stack": 1, "value": 8000, "category": "pack", "slot": "pack", "pack_grid": [6, 4], "pack_cap": 25.0, "color": Color(0.4, 0.45, 0.3)},
	"field_pack": {"name": "野战背包", "size": Vector2i(3, 3), "weight": 1.8, "max_stack": 1, "value": 26000, "category": "pack", "slot": "pack", "pack_grid": [8, 5], "pack_cap": 40.0, "color": Color(0.35, 0.38, 0.28)},
	"raid_pack": {"name": "突击背囊", "size": Vector2i(4, 3), "weight": 2.6, "max_stack": 1, "value": 60000, "category": "pack", "slot": "pack", "pack_grid": [9, 6], "pack_cap": 55.0, "color": Color(0.3, 0.33, 0.25)},
}


static func has(id: String) -> bool:
	return DEFS.has(id)


static func get_def(id: String) -> Dictionary:
	var def: Dictionary = DEFS.get(id, {})
	return def


static func item_name(id: String) -> String:
	return String(DEFS.get(id, {}).get("name", id))


static func size(id: String) -> Vector2i:
	return DEFS.get(id, {}).get("size", Vector2i.ONE)


static func weight(id: String) -> float:
	return float(DEFS.get(id, {}).get("weight", 0.0))


static func max_stack(id: String) -> int:
	return int(DEFS.get(id, {}).get("max_stack", 1))


static func value(id: String) -> int:
	return int(DEFS.get(id, {}).get("value", 0))


static func category(id: String) -> String:
	return String(DEFS.get(id, {}).get("category", "material"))


static func ui_color(id: String) -> Color:
	return DEFS.get(id, {}).get("color", Color(0.5, 0.5, 0.5))


static func category_label(id: String) -> String:
	return String(CATEGORY_NAMES.get(category(id), category(id)))


static func all_ids() -> Array:
	return DEFS.keys()


static func ids_in_category(cat: String) -> Array[String]:
	var out: Array[String] = []
	for id: String in DEFS:
		if category(id) == cat:
			out.append(id)
	return out
