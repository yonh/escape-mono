extends RefCounted

## Shared UI font with CJK coverage: the engine default covers Latin only, so
## Chinese labels use a system font with per-platform fallbacks.

static var _font: Font


static func font() -> Font:
	if _font == null:
		if DisplayServer.get_name() == "headless":
			_font = ThemeDB.fallback_font
			return _font
		var font := SystemFont.new()
		# PingFang resolves to a system-reserved .ttc that FreeType cannot read;
		# keep it last so readable fonts win on every platform.
		font.font_names = PackedStringArray(["Heiti TC", "Hiragino Sans GB", "Songti SC", "Microsoft YaHei", "Noto Sans CJK SC", "Noto Sans SC", "WenQuanYi Micro Hei", "PingFang SC", "sans-serif"])
		font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		_font = font
	return _font


static func apply(control: Control, size: int = 0) -> void:
	control.add_theme_font_override("font", font())
	if size > 0:
		control.add_theme_font_size_override("font_size", size)
