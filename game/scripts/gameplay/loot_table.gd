extends RefCounted

## Weighted loot tables per container type. `roll()` returns
## Array[{id, count}] — every id must exist in item_catalog.

const CATALOG := preload("res://scripts/gameplay/item_catalog.gd")

const TABLES: Dictionary = {
	"cache": {  # 武器箱
		"rolls": 3,
		"entries": [
			{"id": "pm_pistol", "weight": 12, "min": 1, "max": 1},
			{"id": "ak74", "weight": 6, "min": 1, "max": 1},
			{"id": "mp133", "weight": 8, "min": 1, "max": 1},
			{"id": "ammo_9x18", "weight": 20, "min": 8, "max": 24},
			{"id": "ammo_545", "weight": 18, "min": 15, "max": 45},
			{"id": "ammo_12g", "weight": 15, "min": 4, "max": 10},
			{"id": "pm_mag", "weight": 12, "min": 1, "max": 2},
			{"id": "ak_mag", "weight": 9, "min": 1, "max": 2},
		],
	},
	"medkit": {  # 医疗箱
		"rolls": 3,
		"entries": [
			{"id": "bandage", "weight": 30, "min": 1, "max": 3},
			{"id": "ai2_medkit", "weight": 20, "min": 1, "max": 1},
			{"id": "salewa", "weight": 14, "min": 1, "max": 1},
			{"id": "painkillers", "weight": 22, "min": 1, "max": 2},
		],
	},
	"food": {  # 食品箱
		"rolls": 3,
		"entries": [
			{"id": "canned_beef", "weight": 26, "min": 1, "max": 2},
			{"id": "crackers", "weight": 30, "min": 1, "max": 3},
			{"id": "water_bottle", "weight": 24, "min": 1, "max": 2},
			{"id": "energy_drink", "weight": 20, "min": 1, "max": 2},
		],
	},
	"toolbox": {  # 工具箱
		"rolls": 3,
		"entries": [
			{"id": "scrap_metal", "weight": 24, "min": 1, "max": 2},
			{"id": "wire", "weight": 22, "min": 1, "max": 2},
			{"id": "bolts", "weight": 24, "min": 2, "max": 4},
			{"id": "duct_tape", "weight": 20, "min": 1, "max": 2},
			{"id": "toolset", "weight": 10, "min": 1, "max": 1},
		],
	},
	"valuable": {  # 贵重品藏匿点
		"rolls": 2,
		"entries": [
			{"id": "gold_chain", "weight": 18, "min": 1, "max": 1},
			{"id": "roler_watch", "weight": 14, "min": 1, "max": 1},
			{"id": "mil_circuit", "weight": 22, "min": 1, "max": 1},
			{"id": "gp_coin", "weight": 26, "min": 1, "max": 2},
			{"id": "dorm_key", "weight": 8, "min": 1, "max": 1},
			{"id": "keycard_red", "weight": 4, "min": 1, "max": 1},
		],
	},
}


static func has_table(id: String) -> bool:
	return TABLES.has(id)


static func table_ids() -> Array:
	return TABLES.keys()


## Roll `rolls` weighted picks. rng may be null (fresh random) or seeded for
## deterministic tests. Duplicate picks stay separate — stacking is the
## inventory's job.
static func roll(table_id: String, rng: RandomNumberGenerator = null) -> Array:
	var table: Dictionary = TABLES.get(table_id, {})
	var entries: Array = table.get("entries", [])
	var rolls := int(table.get("rolls", 0))
	if entries.is_empty() or rolls <= 0:
		return []
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var total := 0.0
	for e in entries:
		total += float(e.get("weight", 0.0))
	var out: Array = []
	for i in rolls:
		var pick := rng.randf() * total
		var acc := 0.0
		for e in entries:
			acc += float(e.get("weight", 0.0))
			if pick <= acc:
				out.append({
					"id": String(e["id"]),
					"count": rng.randi_range(int(e.get("min", 1)), int(e.get("max", 1))),
				})
				break
	return out


## Every table entry must point at a real catalog item with a sane count range.
static func validate() -> Array[String]:
	var problems: Array[String] = []
	for table_id in TABLES:
		for e in TABLES[table_id].get("entries", []):
			var id := String(e.get("id", ""))
			if not CATALOG.has(id):
				problems.append("%s: unknown item %s" % [table_id, id])
			if int(e.get("min", 1)) < 1 or int(e.get("min", 1)) > int(e.get("max", 1)):
				problems.append("%s: bad count range on %s" % [table_id, id])
			if float(e.get("weight", 0.0)) <= 0.0:
				problems.append("%s: non-positive weight on %s" % [table_id, id])
	return problems
