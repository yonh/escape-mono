extends Control

## Compact health HUD widget: HP bar with numeric readout plus status chips
## for each active effect. `bind(health)` wires it to a Health node.

const UIFONT := preload("res://scripts/gameplay/ui_font.gd")

const W := 220.0
const BAR_H := 14.0
const CHIP_H := 20.0

var health: Node
var _bar_color := Color(0.35, 0.75, 0.4)
var _flash := 0.0


func _init() -> void:
	# HUD 不拦点击——鼠标释放后点生命条区域要能重新捕获。
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func bind(h: Node) -> void:
	health = h
	custom_minimum_size = Vector2(W, BAR_H + CHIP_H + 14)
	size = custom_minimum_size
	health.health_changed.connect(func(_a, _b): queue_redraw())
	health.damaged.connect(func(_a, _s): _flash = 0.35)
	health.status_applied.connect(func(_i): queue_redraw())
	health.status_cured.connect(func(_i): queue_redraw())
	queue_redraw()


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
		queue_redraw()
	# Timed status chips count down every second — keep redrawing while
	# any countdown is on screen so the numbers don't freeze.
	elif health != null and not health.statuses().is_empty():
		queue_redraw()


func _draw() -> void:
	if health == null:
		return
	var font := UIFONT.font()
	var frac = health.hp / health.max_hp
	var bar := Rect2(0, 10, W, BAR_H)
	draw_rect(bar, Color(0.1, 0.1, 0.12, 0.85))
	var fill := Rect2(bar.position, Vector2(W * frac, BAR_H))
	var color := _bar_color.lerp(Color(0.9, 0.25, 0.2), 1.0 - frac)
	if _flash > 0.0:
		color = color.lerp(Color.WHITE, _flash)
	draw_rect(fill, color)
	draw_rect(bar, Color(0.4, 0.4, 0.42), false, 1.0)
	var text := "生命 %d/%d" % [int(ceil(health.hp)), int(health.max_hp)]
	draw_string(font, Vector2(0, 9), text, HORIZONTAL_ALIGNMENT_LEFT, W, 12, Color.WHITE)
	var x := 0.0
	for id: String in health.statuses():
		var def: Dictionary = health.STATUS_DEFS.get(id, {})
		var chip := Rect2(x, 10 + BAR_H + 3, 64, CHIP_H)
		var c: Color = def.get("color", Color(0.8, 0.3, 0.3))
		draw_rect(chip, c.darkened(0.45))
		draw_rect(chip, c, false, 1.0)
		var label := String(def.get("name", id))
		var secs = health.status_remaining(id)
		if secs > 0.0:
			label += " %ds" % int(ceil(secs))
		draw_string(font, chip.position + Vector2(4, 14), label, HORIZONTAL_ALIGNMENT_LEFT, chip.size.x - 4, 11, Color.WHITE)
		x += 70
