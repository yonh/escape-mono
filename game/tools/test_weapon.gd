extends SceneTree

## Weapon-system unit checks: fire-rate gate, magazine/reserve ammo, dry fire,
## whole-mag and per-shell reload, pellets, spread cone, serialization.
## godot --headless --path . -s res://tools/test_weapon.gd

const DATA := preload("res://scripts/gameplay/weapon_data.gd")
const WEAPON := preload("res://scripts/gameplay/weapon_controller.gd")

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)


func _run() -> void:
	# Data table integrity
	_check(DATA.all_ids().size() >= 3, "weapon table too small")
	for id: String in DATA.all_ids():
		_check(DATA.damage(id) > 0.0 and DATA.mag_size(id) > 0, "%s bad stats" % id)
		_check(DATA.ammo_id(id) != "", "%s missing ammo id" % id)

	var w := WEAPON.new()
	w.rand_seed = 7

	# Setup + fire-rate gate
	var fired_count := [0]
	var blocks: Array = []
	w.shot_fired.connect(func(_s: Array) -> void: fired_count[0] += 1)
	w.fire_blocked.connect(func(r: StringName) -> void: blocks.append(r))
	w.setup("ak74", 30, 90)
	_check(w.mag == 30 and w.reserve == 90, "setup ammo wrong")
	var shots: Array = w.try_fire(Vector3.FORWARD)
	_check(shots.size() == 1, "ak74 should fire exactly one ray")
	_check(fired_count[0] == 1, "shot_fired not emitted")
	_check(w.mag == 29, "magazine did not decrement")
	_check(w.try_fire(Vector3.FORWARD).is_empty(), "fire-rate gate ignored")

	# Cadence: 600 rpm -> 0.1 s between shots
	w.tick(0.1)
	_check(w.try_fire(Vector3.FORWARD).size() == 1, "follow-up shot too slow")

	# Spread cone stays within spread_deg of the aim direction
	var aim := Vector3(0.2, 0.3, -0.93).normalized()
	var spread := deg_to_rad(DATA.spread_deg("ak74")) + 0.001
	for i in 20:
		w.tick(0.1)
		var s: Array = w.try_fire(aim)
		_check(s.size() == 1 and aim.angle_to(s[0]["direction"]) <= spread, "pellet outside spread cone")

	# Dry fire blocks with &"magazine"
	w.mag = 0
	_check(w.try_fire(Vector3.FORWARD).is_empty(), "empty mag still fired")
	_check(blocks.has(&"magazine"), "dry fire did not emit magazine block")

	# Whole-mag reload: blocks firing until finished, drains reserve only
	w.setup("ak74", 4, 10)
	w.mag = 0
	_check(w.start_reload(), "reload refused")
	_check(w.reloading(), "reload state missing")
	_check(w.try_fire(Vector3.FORWARD).is_empty(), "fired during mag reload")
	_check(blocks.has(&"reloading"), "mag reload did not emit reloading block")
	w.tick(DATA.reload_time("ak74") + 0.01)
	_check(not w.reloading(), "reload never finished")
	_check(w.mag == 10 and w.reserve == 0, "reload moved wrong round count")

	# Reserve smaller than the gap only tops the mag up
	w.setup("ak74", 1, 3)
	_check(w.start_reload(), "top-up reload refused")
	w.tick(10.0)
	_check(w.mag == 4 and w.reserve == 0, "reserve drain wrong")

	# Per-shell reload: one round per tick, firing mid-reload cancels the rest
	w.setup("mp133", 0, 4)
	_check(w.start_reload(), "shell reload refused")
	w.tick(DATA.reload_time("mp133") + 0.01)
	_check(w.mag == 1 and w.reserve == 3, "per-shell reload not one-at-a-time")
	_check(w.reloading(), "pump should keep loading while reserve remains")
	var pump: Array = w.try_fire(Vector3.FORWARD)
	_check(pump.size() == DATA.pellets("mp133"), "pellet count wrong")
	_check(not w.reloading(), "firing did not cancel a pump reload")
	_check(pump[0]["damage"] == DATA.damage("mp133"), "pellet damage wrong")

	# Auto flag distinguishes hold-fire weapons
	_check(DATA.is_auto("ak74") and not DATA.is_auto("pm") and not DATA.is_auto("mp133"), "auto flags wrong")

	# give_ammo + ammo_text
	w.setup("pm", 8, 0)
	w.give_ammo(40)
	_check(w.reserve == 40, "give_ammo failed")
	_check(w.ammo_text() == "PM 手枪 8/40", "ammo_text wrong: %s" % w.ammo_text())

	# A cooldown restored after setup still gates firing (weapon-switch
	# stash restores _cooldown so swapping can't bypass the RPM limit).
	var w3 := WEAPON.new()
	w3.setup("mp133", 4, 12)
	w3.set("_cooldown", 0.4)
	_check(w3.try_fire(Vector3.FORWARD).is_empty(), "restored cooldown ignored")
	w3.tick(0.5)
	_check(w3.try_fire(Vector3.FORWARD).size() == 6, "cooldown did not clear")
	w3.free()

	# Serialization round-trip
	var saved = w.serialize()
	var w2 := WEAPON.new()
	w2.deserialize(saved)
	_check(w2.weapon_id == "pm" and w2.mag == 8 and w2.reserve == 40, "deserialize lost ammo state")
	w.free()
	w2.free()

	print("Weapon checks: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
