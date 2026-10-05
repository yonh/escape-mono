extends Node

## Logic-only firearm: fire-rate gate, spread cone, pellets, magazine +
## reserve ammo, and reload (whole-mag or per-shell). `try_fire` returns the
## shots to raycast as {direction, damage} pairs; the owning scene performs
## the raycasts and applies damage.
##
## Set `rand_seed` non-zero for deterministic spread in tests.

signal shot_fired(shots: Array)
signal fire_blocked(reason: StringName)
signal reload_started()
signal reload_finished(rounds: int)
signal ammo_changed(mag: int, reserve: int)
signal weapon_changed(id: String)

const DATA := preload("res://scripts/gameplay/weapon_data.gd")

var weapon_id := ""
var mag := 0
var reserve := 0
var rand_seed := 0

var _cooldown := 0.0
var _reload_left := 0.0
var _rng := RandomNumberGenerator.new()


func setup(id: String, mag_rounds: int = -1, reserve_rounds: int = 0) -> void:
	assert(DATA.has(id), "unknown weapon %s" % id)
	weapon_id = id
	mag = DATA.mag_size(id) if mag_rounds < 0 else clampi(mag_rounds, 0, DATA.mag_size(id))
	reserve = maxi(0, reserve_rounds)
	_cooldown = 0.0
	_reload_left = 0.0
	if rand_seed != 0:
		_rng.seed = rand_seed
	else:
		_rng.randomize()
	ammo_changed.emit(mag, reserve)
	weapon_changed.emit(id)


func _process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if _reload_left <= 0.0:
		return
	_reload_left -= delta
	if _reload_left > 0.0:
		return
	if DATA.reload_per_shell(weapon_id):
		_load_one_shell()
	else:
		_finish_reload()


func reloading() -> bool:
	return _reload_left > 0.0


func reload_progress() -> float:
	var total := DATA.reload_time(weapon_id)
	if not reloading() or total <= 0.0:
		return 0.0
	return 1.0 - _reload_left / total


func start_reload() -> bool:
	if reloading() or weapon_id.is_empty() or reserve <= 0 or mag >= DATA.mag_size(weapon_id):
		return false
	_reload_left = DATA.reload_time(weapon_id)
	reload_started.emit()
	return true


## Fires if the weapon is ready. Returns the shots to raycast
## (Array[{direction: Vector3, damage: float}]) or [] when blocked;
## `fire_blocked` reports &"magazine" (empty) or &"reloading".
func try_fire(direction: Vector3) -> Array:
	if reloading():
		# A pump reload is interrupted by firing; a mag reload is not.
		if DATA.reload_per_shell(weapon_id) and mag > 0:
			_reload_left = 0.0
		else:
			fire_blocked.emit(&"reloading")
			return []
	if mag <= 0:
		fire_blocked.emit(&"magazine")
		return []
	if _cooldown > 0.0:
		return []
	mag -= 1
	_cooldown = 60.0 / DATA.rpm(weapon_id)
	var shots: Array = []
	for i in DATA.pellets(weapon_id):
		shots.append({
			"direction": _spread_dir(direction),
			"damage": DATA.damage(weapon_id),
			"range_m": DATA.range_m(weapon_id),
		})
	ammo_changed.emit(mag, reserve)
	shot_fired.emit(shots)
	return shots


func give_ammo(rounds: int) -> void:
	reserve = maxi(0, reserve + rounds)
	ammo_changed.emit(mag, reserve)


func ammo_text() -> String:
	return "%s %d/%d" % [DATA.display_name(weapon_id), mag, reserve]


func _finish_reload() -> void:
	var rounds := mini(DATA.mag_size(weapon_id) - mag, reserve)
	mag += rounds
	reserve -= rounds
	ammo_changed.emit(mag, reserve)
	reload_finished.emit(rounds)


func _load_one_shell() -> void:
	mag += 1
	reserve -= 1
	ammo_changed.emit(mag, reserve)
	reload_finished.emit(1)
	if mag < DATA.mag_size(weapon_id) and reserve > 0:
		_reload_left = DATA.reload_time(weapon_id)


func _spread_dir(direction: Vector3) -> Vector3:
	# Uniform cone: random azimuth around the aim axis, deviation <= spread_deg.
	var spread := deg_to_rad(DATA.spread_deg(weapon_id))
	var axis := direction.cross(Vector3.UP)
	if axis.length_squared() < 0.001:
		axis = direction.cross(Vector3.RIGHT)
	var side := axis.normalized().rotated(direction, _rng.randf_range(0.0, TAU))
	return direction.rotated(side, _rng.randf_range(0.0, spread)).normalized()


func serialize() -> Dictionary:
	return {"weapon_id": weapon_id, "mag": mag, "reserve": reserve}


func deserialize(data: Dictionary) -> void:
	setup(String(data.get("weapon_id", "pm")), int(data.get("mag", -1)), int(data.get("reserve", 0)))
