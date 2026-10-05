extends SceneTree

## Hideout checks: GameState persistence, starter kit, room contents,
## interactable markers.

const GAME_STATE := preload("res://scripts/gameplay/game_state.gd")
const HIDEOUT_SCENE := "res://scenes/hideout.tscn"

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)


func _run() -> void:
	# GameState lazily creates stash + backpack.
	GAME_STATE.stash = null
	GAME_STATE.backpack = null
	GAME_STATE.raids_completed = 0
	GAME_STATE.ensure()
	_check(GAME_STATE.stash != null and GAME_STATE.backpack != null, "ensure() did not create inventories")
	_check(GAME_STATE.stash.is_empty() and GAME_STATE.backpack.is_empty(), "fresh inventories not empty")

	# Stash/backpack survive across "scene changes" (statics on the script).
	var stash_ref: RefCounted = GAME_STATE.stash
	GAME_STATE.ensure()
	_check(GAME_STATE.stash == stash_ref, "ensure() recreated the stash")

	# Hideout scene loads and builds the room.
	var scene = load(HIDEOUT_SCENE)
	_check(scene != null, "hideout.tscn failed to load")
	if scene == null:
		print("Hideout checks: ", failures)
		quit(1)
		return
	var hideout = scene.instantiate()
	root.add_child(hideout)
	await process_frame  # let _ready build the room

	# Starter kit landed in the stash on first run.
	_check(GAME_STATE.stash.count_of("bandage") == 3, "starter kit missing from stash")
	_check(GAME_STATE.backpack.count_of("pm_pistol") == 1, "starter pistol missing from backpack")

	# Room has walls/floor and the player spawned.
	_check(hideout.get_node_or_null("Floor") != null, "room floor missing")
	var player: Node = hideout.get("_player")
	_check(player != null and player is CharacterBody3D, "player not built")

	# Four interactables: stash + equip bench + 工厂出发垫 + 哨站出发垫。
	var interactables := get_nodes_in_group("interactable")
	var actions := []
	for n in interactables:
		actions.append(StringName(n.get("action")))
	_check(actions.size() == 4, "expected 4 interactables, got %d" % actions.size())
	_check(actions.has(&"stash") and actions.has(&"equip")
		and actions.has(&"depart_factory") and actions.has(&"depart_outpost"),
		"interactable actions wrong: %s" % str(actions))

	# Second hideout "visit" must not re-seed the starter kit.
	hideout.call("_seed_stash_first_run")
	_check(GAME_STATE.stash.count_of("bandage") == 3, "starter kit re-seeded again")

	# But an emptied stash + backpack seeds again (fresh profile semantics).
	for entry in GAME_STATE.stash.entries():
		GAME_STATE.stash.take_at(entry["pos"], -1)
	GAME_STATE.backpack = null
	GAME_STATE.ensure()
	hideout.call("_seed_stash_first_run")
	_check(GAME_STATE.stash.count_of("bandage") == 3, "empty profile did not re-seed")

	# 回归 (PR#23 review): stash_pending 补队跳过拖拽中的持物（腾出的格子
	# 可能被放回取消，抢先补队会把持物挤成无家可归）。
	hideout.call("_open_stash")
	var panels: Array = hideout.get("_stash_panels")
	_check(panels.size() >= 2, "stash panels missing")
	for entry in GAME_STATE.stash.entries():
		GAME_STATE.stash.take_at(entry["pos"], -1)
	GAME_STATE.stash_pending.clear()
	GAME_STATE.stash.regrid(Vector2i(2, 2), -1.0)
	GAME_STATE.stash.add_item("gp_coin", 1, Vector2i(0, 0))
	GAME_STATE.stash.add_item("gp_coin", 1, Vector2i(1, 0))
	GAME_STATE.stash_pending.append({"id": "bandage", "count": 1, "rotated": false})
	var drag: Dictionary = panels[0].get("_drag")
	drag["held"] = {"id": "gp_coin", "count": 1}
	GAME_STATE.stash.take_at(Vector2i(0, 0))
	await process_frame  # drain は 1 フレーム遅延 — 持物確定を待つ
	_check(GAME_STATE.stash_pending.size() == 1, "拖拽中 drain 挤占了腾出的格子")
	drag["held"] = {}
	GAME_STATE.stash.take_at(Vector2i(1, 0))
	await process_frame
	_check(GAME_STATE.stash_pending.is_empty(), "空手腾位未自动补队")
	_check(GAME_STATE.stash.count_of("bandage") == 1, "补队物品未入仓库")
	GAME_STATE.stash.regrid(Vector2i(10, 8), -1.0)
	GAME_STATE.stash.clear()
	GAME_STATE.stash_pending.clear()
	hideout.call("_close_stash")

	# 回归 (review BUG_0004): 装备台所有面板必须在 960x600 窗口内可见。
	hideout.call("_open_equipment")
	var eq_panels: Array = hideout.get("_stash_panels")
	_check(eq_panels.size() == 6, "装备台面板数不对: %d" % eq_panels.size())
	for p in eq_panels:
		var bottom: float = p.position.y + p.size.y
		_check(bottom <= 600.0, "面板超出窗口: %s bottom=%.0f" % [p.get("_title"), bottom])
	hideout.call("_close_stash")

	# 回归 (review BUG_0002): 仓库持物兜底只回仓库/手上——绝不自动塞进背包
	# （背包会随阵亡清空）。
	hideout.call("_open_stash")
	panels = hideout.get("_stash_panels")
	GAME_STATE.stash.regrid(Vector2i(1, 1), -1.0)
	GAME_STATE.stash.add_item("gp_coin", 1)
	var hold_drag: Dictionary = panels[0].get("_drag")
	hold_drag["held"] = {"id": "gp_coin", "count": 1}
	hold_drag["from_inv"] = GAME_STATE.stash
	hideout.call("_release_held_loot")
	_check(GAME_STATE.backpack.count_of("gp_coin") == 0, "仓库持物误入背包")
	_check(GAME_STATE.raid_pending.size() == 1, "无家可归持物未留在手上")
	GAME_STATE.raid_pending.clear()
	GAME_STATE.stash.regrid(Vector2i(10, 8), -1.0)
	GAME_STATE.stash.clear()
	hideout.call("_close_stash")

	hideout.queue_free()
	print("Hideout checks: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
