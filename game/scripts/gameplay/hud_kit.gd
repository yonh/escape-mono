extends RefCounted

## HUD 组件工厂：统一游戏内 HUD 的字体、投影和鼠标过滤。
## 规则：HUD 元素一律 MOUSE_FILTER_IGNORE（否则全屏/小块控件会吞掉
## 鼠标事件，见 PR #18）；需要点按的界面元素才用默认 STOP。

const UIFONT := preload("res://scripts/gameplay/ui_font.gd")


## 全屏 HUD 根节点（Control，IGNORE，不吞鼠标）。
static func overlay(canvas: CanvasLayer) -> Control:
	var hud := Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(hud)
	return hud


## 带投影阴影的文字标签。anchor 预设传 preset（如 PRESET_CENTER）。
static func label(parent: Control, text: String, pos: Vector2, size: int = 15, color: Color = Color.WHITE, centered := false) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if centered:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.set_anchors_preset(Control.PRESET_CENTER)
	l.position = pos
	UIFONT.apply(l, size)
	l.modulate = color
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	parent.add_child(l)
	return l


## 半透明底衬信息条（区域名/背包等长驻信息）。
static func info_chip(parent: Control, pos: Vector2, text: String, size: int = 14) -> Label:
	var l := label(parent, " " + text + " ", pos, size)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.10, 0.55)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	l.add_theme_stylebox_override("normal", style)
	return l


## 左下角操作帮助行。
static func help_line(parent: Control, text: String, y: float = 700) -> Label:
	return label(parent, text, Vector2(20, y), 13, Color(0.8, 0.8, 0.75))
