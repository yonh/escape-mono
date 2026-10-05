extends Node

## Health component (生命系统): attach to a player or AI. Holds HP, timed
## status effects with per-second drains (light/heavy bleeding, pain), and
## emits lifecycle signals. `tick` runs in _process; use `tick_enabled` to
## drive it manually in tests.

signal health_changed(hp: float, max_hp: float)
signal damaged(amount: float, source: String)
signal healed(amount: float)
signal status_applied(id: String)
signal status_cured(id: String)
signal died

## Status table: drain_per_sec damages HP every second the status is active;
## default_duration <= 0 means the status persists until cured.
const STATUS_DEFS := {
	"light_bleed": {"name": "轻度出血", "drain_per_sec": 0.4, "default_duration": 20.0, "color": Color(0.9, 0.35, 0.3)},
	"heavy_bleed": {"name": "重度出血", "drain_per_sec": 1.2, "default_duration": 12.0, "color": Color(0.75, 0.1, 0.1)},
	"pain": {"name": "疼痛", "drain_per_sec": 0.0, "default_duration": 15.0, "color": Color(0.95, 0.7, 0.2)},
	"fracture": {"name": "骨折", "drain_per_sec": 0.0, "default_duration": -1.0, "color": Color(0.7, 0.55, 0.4)},
}

@export var max_hp: float = 100.0
@export var hp: float = 100.0
@export var tick_enabled: bool = true

## Armor-like flat damage reduction (0..0.9): equipment sets it on raid
## entry from the equipped armor's `reduction`; damage() multiplies through.
var protection := 0.0

var _statuses: Dictionary = {}  # id -> remaining seconds (-1 = until cured)
var _dead := false


func _ready() -> void:
	hp = clampf(hp, 0.0, max_hp)
	# Spawning with no HP (or max_hp 0) means starting dead — same
	# convention deserialize() uses. Deferred so parents binding signals
	# after add_child() still see it.
	if hp <= 0.0:
		_dead = true
		died.emit.call_deferred()


func _process(delta: float) -> void:
	if tick_enabled:
		tick(delta)


func tick(delta: float) -> void:
	if _dead:
		return
	var expired: Array[String] = []
	for id: String in _statuses:
		var def: Dictionary = STATUS_DEFS.get(id, {})
		var remaining := float(_statuses[id])
		# Timed statuses only drain for their remaining lifetime — a frame
		# delta past expiry must not deal a whole frame of damage.
		var step := delta if remaining <= 0.0 else minf(delta, remaining)
		var drain := float(def.get("drain_per_sec", 0.0)) * step
		if drain > 0.0:
			_apply_hp(hp - drain)
		if remaining > 0.0:
			remaining -= delta
			_statuses[id] = remaining
			if remaining <= 0.0:
				expired.append(id)
		if _dead:
			return
	for id in expired:
		cure_status(id)


func _apply_hp(value: float) -> void:
	var clamped := clampf(value, 0.0, max_hp)
	if clamped == hp:
		return
	hp = clamped
	health_changed.emit(hp, max_hp)
	if hp <= 0.0 and not _dead:
		_dead = true
		died.emit()


func is_alive() -> bool:
	return not _dead


func is_dead() -> bool:
	return _dead


## Apply damage. `source` labels the attacker/cause for the damaged signal.
## `protection` (equipped armor) reduces the incoming amount first.
## Returns the amount actually removed.
func damage(amount: float, source: String = "") -> float:
	if _dead or amount <= 0.0:
		return 0.0
	var before := hp
	_apply_hp(hp - amount * (1.0 - clampf(protection, 0.0, 0.9)))
	var dealt := before - hp
	if dealt > 0.0:
		damaged.emit(dealt, source)
	return dealt


func heal(amount: float) -> float:
	if _dead or amount <= 0.0:
		return 0.0
	var before := hp
	_apply_hp(hp + amount)
	var gained := hp - before
	if gained > 0.0:
		healed.emit(gained)
	return gained


## Activate a status. `duration` < 0 uses the table default (which may itself
## be permanent until cured). Returns false for unknown status ids.
func apply_status(id: String, duration: float = -1.0) -> bool:
	if _dead or not STATUS_DEFS.has(id):
		return false
	var secs := duration
	if secs < 0.0:
		secs = float(STATUS_DEFS[id].get("default_duration", -1.0))
	_statuses[id] = secs
	status_applied.emit(id)
	return true


func cure_status(id: String) -> bool:
	if not _statuses.has(id):
		return false
	_statuses.erase(id)
	status_cured.emit(id)
	return true


func has_status(id: String) -> bool:
	return _statuses.has(id)


func statuses() -> Array:
	return _statuses.keys()


func status_remaining(id: String) -> float:
	return float(_statuses.get(id, 0.0))


func revive(fraction: float = 0.35) -> void:
	_dead = false
	_statuses.clear()
	_apply_hp(max_hp * clampf(fraction, 0.0, 1.0))


func serialize() -> Dictionary:
	return {"hp": hp, "max_hp": max_hp, "statuses": _statuses.duplicate()}


func deserialize(data: Dictionary) -> void:
	max_hp = float(data.get("max_hp", max_hp))
	hp = clampf(float(data.get("hp", hp)), 0.0, max_hp)
	_statuses = (data.get("statuses", {}) as Dictionary).duplicate()
	_dead = hp <= 0.0
