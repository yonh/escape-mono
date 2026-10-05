extends Control
## 主菜单：标题 + 继续行动（有存档时）/ 新的开始 / 退出。
## 读档在 hideout._ready 完成；新开始先 wipe 再走首局发物资流程。

const UIFONT = preload("res://scripts/gameplay/ui_font.gd")
const SAVE_KIT = preload("res://scripts/gameplay/save_kit.gd")

var _confirming := false
var _buttons: Array[Button] = []
var _foot: Label


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var bg := ColorRect.new()
	bg.color = Color(0.055, 0.06, 0.075)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := VBoxContainer.new()
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.custom_minimum_size = Vector2(360, 0)
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(center)

	var title := Label.new()
	title.text = "厂房行动\nFACTORY RAID"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	UIFONT.apply(title, 34)
	center.add_child(title)

	var sub := Label.new()
	sub.text = "塔科夫式搜打撤 · escape-mono"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color(0.55, 0.6, 0.68))
	UIFONT.apply(sub, 14)
	center.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	center.add_child(spacer)

	if SAVE_KIT.has_valid_save():
		_add_button(center, "继续行动（读取存档）", _on_continue)
	_add_button(center, "新的开始", _on_new)
	_add_button(center, "退出", func(): get_tree().quit())

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 24)
	center.add_child(spacer2)

	_foot = Label.new()
	_foot.text = ""
	_foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_foot.add_theme_color_override("font_color", Color(0.75, 0.4, 0.35))
	UIFONT.apply(_foot, 13)
	center.add_child(_foot)


func _add_button(parent: Control, text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 46)
	b.add_theme_font_size_override("font_size", 20)
	b.theme = Theme.new()
	b.theme.set_font("font", "Button", UIFONT.font())
	b.pressed.connect(on_press)
	parent.add_child(b)
	_buttons.append(b)
	return b


func _on_continue() -> void:
	get_tree().change_scene_to_file("res://scenes/hideout.tscn")


func _on_new() -> void:
	# 有存档时新开始=覆盖：先二次确认，避免误清进度。
	if SAVE_KIT.has_save() and not _confirming:
		_confirming = true
		_foot.text = "再次点击「新的开始」确认清空存档"
		return
	if not SAVE_KIT.wipe():
		_foot.text = "存档删除失败，无法开始新局"
		return
	get_tree().change_scene_to_file("res://scenes/hideout.tscn")
