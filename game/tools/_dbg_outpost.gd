extends SceneTree
## debug: 跳过生存屋直接进外围哨站 raid（截图/巡检用）。

const GAME_STATE := preload("res://scripts/gameplay/game_state.gd")

func _init() -> void:
	call_deferred("_go")

func _go() -> void:
	GAME_STATE.ensure()
	GAME_STATE.raid_map_id = "outpost"
	GAME_STATE.raid_plan = {"source": "outpost", "spawn_idx": 0}
	change_scene_to_file("res://scenes/raid.tscn")
