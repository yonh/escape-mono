extends SceneTree

## M4 音效 smoke：sfx_kit 加载/播放/清理。headless 用 dummy 音频驱动，
## 不产出声音但验证 stream 可载、player 创建与播放状态、match 选枪声。

const SFX := preload("res://scripts/gameplay/sfx_kit.gd")

var _fails: Array = []


func _check(ok: bool, msg: String) -> void:
	if not ok:
		_fails.append(msg)
		push_error(msg)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var files := ["sfx_shot_pm", "sfx_shot_ak", "sfx_shot_sg", "sfx_shot_scav",
		"sfx_hit", "sfx_bodyfall", "sfx_reload", "sfx_footstep", "sfx_search",
		"sfx_crate_open", "amb_factory_loop", "sfx_extract_done", "sfx_death",
		"sfx_door_open", "sfx_door_denied"]
	for f in files:
		var s := SFX.stream(f)
		_check(s != null, "stream 缺失: %s" % f)

	# 枪声按武器选型
	_check(SFX.gunshot_for("ak74") == SFX.stream("sfx_shot_ak"), "ak74 选错枪声")
	_check(SFX.gunshot_for("mp133") == SFX.stream("sfx_shot_sg"), "mp133 选错枪声")
	_check(SFX.gunshot_for("pm") == SFX.stream("sfx_shot_pm"), "pm 应回退手枪声")
	_check(SFX.gunshot_for("unknown_x") == SFX.stream("sfx_shot_pm"), "未知武器应回退")

	# 播放节点创建/自清理/循环
	var host := Node3D.new()
	root.add_child(host)
	var p2 := SFX.play_2d(SFX.stream("sfx_shot_pm"), host, -4.0)
	_check(p2 != null and p2.get_parent() == host, "play_2d 未挂到 host")
	_check(p2.playing or p2.stream != null, "play_2d 未初始化 stream")
	var p3 := SFX.play_3d(SFX.stream("sfx_hit"), host, Vector3(1, 2, 3), -6.0, 25.0)
	_check(p3 is AudioStreamPlayer3D, "play_3d 类型错")
	_check(p3.position == Vector3(1, 2, 3), "play_3d 位置错: %s" % p3.position)
	_check(p3.max_distance == 25.0, "play_3d max_distance 未生效")
	var lp := SFX.loop_2d(SFX.stream("amb_factory_loop"), host, -18.0)
	_check(lp.stream is AudioStreamWAV, "loop stream 类型错")
	_check((lp.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD,
		"循环模式未置 LOOP_FORWARD")
	lp.stop()
	lp.queue_free()

	# searchable 自管循环音（仓库通用）
	const SEARCHABLE := preload("res://scripts/gameplay/searchable.gd")
	var s := SEARCHABLE.new()
	s.table_id = "cache"
	s.search_time = 0.05
	root.add_child(s)
	s.begin_search()
	_check(s.get("_sfx_search") != null, "搜索循环音未创建")
	for i in 20:
		await process_frame
		if not s.searching():
			break
	_check(s.get("_sfx_search") == null, "搜索结束循环音未清理")

	print("SFX checks: %s" % ("PASS" if _fails.is_empty() else str(_fails)))
	quit(0 if _fails.is_empty() else 1)
