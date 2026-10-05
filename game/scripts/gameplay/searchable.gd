extends Node

## Searchable container: Tarkov-style timed search. `begin_search()` starts a
## countdown; `tick()` advances it; finishing emits the rolled loot once and
## marks the container looted. `cancel_search()` aborts (interrupted search).

signal search_started
signal search_progress(fraction: float)
signal search_finished(items: Array)
signal search_cancelled

const LOOT := preload("res://scripts/gameplay/loot_table.gd")

@export var table_id := "cache"
@export var search_time := 2.5

var looted := false
var rand_seed := 0

var _left := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if rand_seed != 0:
		_rng.seed = rand_seed
	else:
		_rng.randomize()


func _process(delta: float) -> void:
	tick(delta)


func searching() -> bool:
	return _left > 0.0


func progress() -> float:
	if searching():
		return 1.0 - _left / maxf(search_time, 0.001)
	return 1.0 if looted else 0.0


func can_search() -> bool:
	return not looted and not searching()


func begin_search() -> bool:
	if not can_search():
		return false
	_left = search_time
	search_started.emit()
	return true


func cancel_search() -> void:
	if not searching():
		return
	_left = 0.0
	search_cancelled.emit()


func tick(delta: float) -> void:
	if not searching():
		return
	_left -= delta
	if _left <= 0.0:
		# Finishing path: emit completion (1.0), then the loot. A listener
		# cannot cancel here — cancel_search() already requires searching().
		_left = 0.0
		looted = true
		search_progress.emit(1.0)
		search_finished.emit(LOOT.roll(table_id, _rng))
		return
	search_progress.emit(progress())
	# A listener may have cancelled inside search_progress: _left is now
	# 0, so the next tick's early return drops the search with no loot.


## Debug/test: finish instantly without waiting out the timer.
func search_now() -> Array:
	if not can_search():
		return []
	_left = 0.0
	looted = true
	var items: Array = LOOT.roll(table_id, _rng)
	search_progress.emit(1.0)
	search_finished.emit(items)
	return items
