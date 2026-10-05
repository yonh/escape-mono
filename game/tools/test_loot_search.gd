extends SceneTree

## Headless checks for loot tables + the searchable component.

const LOOT := preload("res://scripts/gameplay/loot_table.gd")
const SEARCHABLE := preload("res://scripts/gameplay/searchable.gd")
const INVENTORY := preload("res://scripts/gameplay/inventory.gd")
const CATALOG := preload("res://scripts/gameplay/item_catalog.gd")

var failures: Array[String] = []


func check(cond: bool, label: String) -> void:
	if not cond:
		failures.append(label)
		push_error("FAIL: " + label)


func _init() -> void:
	var ids = LOOT.table_ids()
	for expected in ["cache", "medkit", "food", "toolbox", "valuable", "scav"]:
		check(ids.has(expected), "missing loot table %s" % expected)
	for issue in LOOT.validate():
		failures.append(issue)

	# Rolls produce catalog items within their declared count ranges.
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for roll_index in 30:
		for table_id in ids:
			var rolled = LOOT.roll(table_id, rng)
			check(not rolled.is_empty(), "%s roll %d returned items" % [table_id, roll_index])
			for item in rolled:
				check(CATALOG.has(String(item["id"])), "%s rolled unknown item %s" % [table_id, item["id"]])
				check(int(item["count"]) >= 1, "%s rolled non-positive count" % table_id)

	# Deterministic rng reproduces the same roll.
	var r1 := RandomNumberGenerator.new()
	r1.seed = 7
	var r2 := RandomNumberGenerator.new()
	r2.seed = 7
	check(LOOT.roll("cache", r1) == LOOT.roll("cache", r2), "same seed reproduces same roll")

	# Searchable lifecycle: idle -> searching -> looted.
	var s := SEARCHABLE.new()
	s.table_id = "medkit"
	s.search_time = 1.0
	s.rand_seed = 1
	root.add_child(s)
	s._ready()
	check(s.can_search(), "searchable starts available")
	check(s.begin_search(), "begin_search starts the timer")
	check(s.searching(), "searching flag set")
	check(not s.begin_search(), "cannot double-search")
	var progressed := []
	s.search_progress.connect(func(f: float) -> void: progressed.append(f))
	s.tick(0.4)
	check(absf(s.progress() - 0.4) < 0.01, "progress fraction advances")
	var done := []
	s.search_finished.connect(func(items: Array) -> void: done.append_array(items))
	s.tick(0.7)
	check(s.looted, "search completes after the timer")
	check(not done.is_empty(), "search_finished emits loot")
	check(not progressed.is_empty(), "search_progress emitted during search")
	check(not s.begin_search(), "looted container cannot be searched again")
	check(s.search_now().is_empty(), "search_now on looted container is empty")

	# Cancel aborts the search without loot.
	var c := SEARCHABLE.new()
	c.table_id = "cache"
	c.search_time = 5.0
	root.add_child(c)
	c._ready()
	var cancelled := []
	c.search_cancelled.connect(func() -> void: cancelled.append(true))
	c.begin_search()
	c.tick(1.0)
	c.cancel_search()
	check(not cancelled.is_empty(), "cancel_search emits signal")
	check(not c.searching() and not c.looted, "cancelled container is usable again")
	check(c.begin_search(), "re-search after cancel works")

	# BUG_0002: cancel_search inside a progress listener must not award loot.
	var k := SEARCHABLE.new()
	k.table_id = "cache"
	k.search_time = 1.0
	root.add_child(k)
	k._ready()
	var k_done := []
	k.search_finished.connect(func(items: Array) -> void: k_done.append_array(items))
	k.search_progress.connect(func(_f: float) -> void: k.cancel_search())
	k.begin_search()
	k.tick(0.1)  # emits progress -> listener cancels
	check(k_done.is_empty(), "cancelled search still emitted loot")
	check(not k.looted, "cancelled search marked looted")

	# BUG_0003: the finishing tick reports progress 1.0, not a jump back to 0.
	var p := SEARCHABLE.new()
	p.table_id = "food"
	p.search_time = 0.5
	root.add_child(p)
	p._ready()
	var last_progress := [-1.0]
	p.search_progress.connect(func(f: float) -> void: last_progress[0] = f)
	p.begin_search()
	p.tick(0.6)
	check(last_progress[0] == 1.0, "final progress not 1.0: %s" % last_progress[0])

	# search_now for instant results, feeding items into an inventory.
	var q := SEARCHABLE.new()
	q.table_id = "valuable"
	q.rand_seed = 3
	root.add_child(q)
	q._ready()
	var looted_items = q.search_now()
	check(q.looted and not looted_items.is_empty(), "search_now loots instantly")
	var inv := INVENTORY.new(6, 4)
	for item in looted_items:
		check(inv.add_item(String(item["id"]), int(item["count"])) == 0, "looted items fit in an inventory")
	check(not inv.is_empty(), "inventory holds the loot")

	s.free()
	c.free()
	k.free()
	p.free()
	q.free()

	quit(0 if failures.is_empty() else 1)
	if failures.is_empty():
		print("Loot search checks: PASS")
	else:
		print("Loot search checks: %d failures" % failures.size())
