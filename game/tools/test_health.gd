extends SceneTree

## Health-system unit checks: damage/heal clamps, death edge, bleed drains,
## status expiry and cure, revive, serialization.
## godot --headless --path . -s res://tools/test_health.gd

const HEALTH := preload("res://scripts/gameplay/health.gd")

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)


func _new_health(max_hp: float = 100.0) -> Node:
	var h: Node = HEALTH.new()
	h.max_hp = max_hp
	h.hp = max_hp
	return h


func _run() -> void:
	# Damage clamps and death edge
	var h := _new_health()
	root.add_child(h)
	_check(h.damage(30.0) == 30.0 and h.hp == 70.0, "damage bookkeeping wrong")
	var deaths := [0]
	h.died.connect(func(): deaths[0] += 1)
	_check(h.damage(200.0) == 70.0 and h.hp == 0.0, "overkill not clamped")
	_check(deaths[0] == 1, "death signal missing")
	h.damage(10.0)
	_check(deaths[0] == 1, "death emitted twice")
	_check(h.is_dead() and not h.is_alive(), "state flags wrong")
	_check(h.heal(10.0) == 0.0, "healing the dead should fail")

	# Revive
	h.revive(0.5)
	_check(h.is_alive() and h.hp == 50.0, "revive failed")

	# Heal clamp
	_check(h.heal(999.0) == 50.0 and h.hp == 100.0, "overheal not clamped")

	# Bleed drains over time; cure stops it
	h.apply_status("light_bleed")
	_check(h.has_status("light_bleed"), "status not applied")
	var before = h.hp
	for i in 10:
		h.tick(0.1)
	_check(h.hp < before, "bleed did not drain")
	var drained = before - h.hp
	_check(absf(drained - 0.4) < 0.02, "light bleed rate wrong: %f" % drained)
	h.cure_status("light_bleed")
	before = h.hp
	for i in 10:
		h.tick(0.1)
	_check(h.hp == before, "cured status still draining")

	# Heavy bleed expires by itself
	h.apply_status("heavy_bleed")
	for i in 130:
		h.tick(0.1)
	_check(not h.has_status("heavy_bleed"), "timed status did not expire")

	# Bleed can kill
	h.apply_status("heavy_bleed", -1.0)
	h._statuses["heavy_bleed"] = -1.0  # permanent variant for the check
	for i in 200:
		h.tick(0.5)
	_check(h.is_dead(), "fatal bleed did not kill")

	# BUG_0001: spawning with zero HP is dead from the start
	var h4: Node = HEALTH.new()
	h4.max_hp = 100.0
	h4.hp = 0.0
	root.add_child(h4)  # _ready() runs here
	_check(h4.is_dead(), "zero-hp spawn not dead")
	_check(h4.damage(1.0) == 0.0, "dead actor took damage")
	# died is deferred so listeners connecting after add_child still see it
	var late_deaths := [0]
	h4.died.connect(func(): late_deaths[0] += 1)
	await process_frame
	_check(late_deaths[0] == 1, "late-bound died listener missed zero-hp spawn")

	# BUG_0002: a bleed's drain is capped at its remaining lifetime — a
	# frame delta past expiry must not deal a whole frame of damage.
	var h5 := _new_health()
	root.add_child(h5)
	h5.apply_status("heavy_bleed", 0.05)  # 0.05s left at 1.2 dps
	before = h5.hp
	h5.tick(1.0)  # one big frame long past expiry
	_check(absf(before - h5.hp - 0.06) < 0.001, "expired bleed drained full delta")
	_check(not h5.has_status("heavy_bleed"), "expired bleed still active")

	# Serialize round-trip
	var h2 := _new_health(90.0)
	root.add_child(h2)
	h2.damage(25.0)
	h2.apply_status("pain", 8.0)
	var data = h2.serialize()
	var h3 := _new_health()
	root.add_child(h3)
	h3.deserialize(data)
	_check(h3.max_hp == 90.0 and h3.hp == 65.0, "hp not restored")
	_check(h3.has_status("pain") and h3.status_remaining("pain") > 0.0, "status not restored")

	# UI binds without errors
	var hud: Control = (load("res://scripts/gameplay/health_ui.gd") as GDScript).new()
	root.add_child(hud)
	hud.bind(h3)
	_check(hud.get("health") == h3, "hud not bound")
	hud.queue_free()

	print("Health checks: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
