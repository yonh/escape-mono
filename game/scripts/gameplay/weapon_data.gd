extends RefCounted

## Static weapon stat table. Far simpler than Tarkov: one ammo type per
## weapon, no attachments or durability. Stats are per-shot; `pellets` fans a
## shot into multiple rays (shotguns).
## Pure data — same pattern as item_catalog.gd.

const DEFS: Dictionary = {
	"pm": {
		"name": "PM 手枪",
		"item_id": "pm_pistol",
		"damage": 14.0,
		"rpm": 360,
		"mag_size": 8,
		"reload_time": 1.4,
		"spread_deg": 1.4,
		"recoil_deg": 1.2,
		"pellets": 1,
		"auto": false,
		"ammo_id": "ammo_9x18",
		"range_m": 60.0,
	},
	"ak74": {
		"name": "AK-74",
		"item_id": "ak74",
		"damage": 22.0,
		"rpm": 600,
		"mag_size": 30,
		"reload_time": 2.4,
		"spread_deg": 1.7,
		"recoil_deg": 0.9,
		"pellets": 1,
		"auto": true,
		"ammo_id": "ammo_545",
		"range_m": 140.0,
	},
	"mp133": {
		"name": "MP-133",
		"item_id": "mp133",
		"damage": 9.0,
		"rpm": 70,
		"mag_size": 4,
		"reload_time": 0.7,
		"reload_per_shell": true,
		"spread_deg": 4.5,
		"recoil_deg": 3.2,
		"pellets": 6,
		"auto": false,
		"ammo_id": "ammo_12g",
		"range_m": 40.0,
	},
}


static func has(id: String) -> bool:
	return DEFS.has(id)


static func get_def(id: String) -> Dictionary:
	return DEFS.get(id, {})


static func item_id(id: String) -> String:
	return String(get_def(id).get("item_id", ""))


static func display_name(id: String) -> String:
	return String(get_def(id).get("name", id))


static func damage(id: String) -> float:
	return float(get_def(id).get("damage", 10.0))


static func rpm(id: String) -> float:
	return float(get_def(id).get("rpm", 300.0))


static func mag_size(id: String) -> int:
	return int(get_def(id).get("mag_size", 1))


static func reload_time(id: String) -> float:
	return float(get_def(id).get("reload_time", 1.5))


static func reload_per_shell(id: String) -> bool:
	return bool(get_def(id).get("reload_per_shell", false))


static func spread_deg(id: String) -> float:
	return float(get_def(id).get("spread_deg", 1.0))


static func recoil_deg(id: String) -> float:
	return float(get_def(id).get("recoil_deg", 1.0))


static func pellets(id: String) -> int:
	return int(get_def(id).get("pellets", 1))


static func is_auto(id: String) -> bool:
	return bool(get_def(id).get("auto", false))


static func ammo_id(id: String) -> String:
	return String(get_def(id).get("ammo_id", ""))


static func range_m(id: String) -> float:
	return float(get_def(id).get("range_m", 80.0))


static func all_ids() -> Array:
	return DEFS.keys()
