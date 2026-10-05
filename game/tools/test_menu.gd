extends SceneTree
## 主菜单冒烟：无档时 2 按钮（开始/退出）、有档时 3 按钮（+继续）、
## 新开始确认逻辑（有档首点不跳场景只提示）。
##
## cd game && timeout 60 "$HOME/godot47/..." --headless --path . -s res://tools/test_menu.gd

const SAVE_KIT := preload("res://scripts/gameplay/save_kit.gd")
const MENU_SCENE := preload("res://scenes/menu.tscn")

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("[FAIL] ", msg)


func _buttons(node: Node, acc: Array) -> void:
	if node is Button:
		acc.append(node)
	for c in node.get_children():
		_buttons(c, acc)


func _run() -> void:
	SAVE_KIT.SAVE_PATH = "user://test_menu_save.json"

	# 无档：2 按钮
	SAVE_KIT.wipe()
	var menu := MENU_SCENE.instantiate()
	get_root().add_child(menu)
	var btns: Array = []
	_buttons(menu, btns)
	_check(btns.size() == 2, "无档应 2 按钮，实际 %d" % btns.size())
	menu.queue_free()

	# 有档：3 按钮（继续/开始/退出）
	SAVE_KIT.save()
	menu = MENU_SCENE.instantiate()
	get_root().add_child(menu)
	btns = []
	_buttons(menu, btns)
	_check(btns.size() == 3, "有档应 3 按钮，实际 %d" % btns.size())

	# 有档点「新的开始」→ 只弹确认提示，不立即清档（_confirming=true）
	menu._on_new()
	_check(menu._confirming == true, "有档新开始未进入确认态")
	var foot: Label = menu._foot
	_check(foot != null and foot.text != "", "确认提示未显示")
	menu.queue_free()

	print("[DONE] test_menu: %d failure(s)" % _failures)
	quit(0 if _failures == 0 else 1)
