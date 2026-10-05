extends Node3D

## 工厂 raid 场景控制器：室内 CQB 图（factory_map）上的核心循环。
## F 交互（搜索/开箱/撤离） · I 背包 · R 换弹 · 1-2 切枪(装备槽位) · H 自伤测试
## Esc 释放鼠标 · 阵亡/超时自动回生存屋丢背包 · 撤离成功物资并入仓库。

const PLAYER_SCRIPT := preload("res://scripts/fps_controller.gd")
const GAME_STATE := preload("res://scripts/gameplay/game_state.gd")
const FACTORY_MAP := preload("res://scripts/gameplay/factory_map.gd")
const RAID_KIT := preload("res://scripts/gameplay/raid_kit.gd")
const EQUIPMENT := preload("res://scripts/gameplay/equipment.gd")
const LOOT_CRATE := preload("res://scripts/gameplay/loot_crate.gd")
const WEAPON_DATA := preload("res://scripts/gameplay/weapon_data.gd")
const WEAPON_CONTROLLER := preload("res://scripts/gameplay/weapon_controller.gd")
const HEALTH := preload("res://scripts/gameplay/health.gd")
const HEALTH_UI := preload("res://scripts/gameplay/health_ui.gd")
const INVENTORY_UI := preload("res://scripts/gameplay/inventory_ui.gd")
const HUD_KIT := preload("res://scripts/gameplay/hud_kit.gd")
const SFX := preload("res://scripts/gameplay/sfx_kit.gd")

const HIDEOUT_SCENE := "res://scenes/hideout.tscn"
const REACH := 3.0

var _player: CharacterBody3D
var _weapon: Node
var _health: Node
var _environment: Environment

var _prompt_label: Label
var _zone_label: Label
var _plan_label: Label
var _pack_label: Label
var _ammo_label: Label
var _clock_label: Label
var _banner_label: Label

var _container_layer: CanvasLayer = null
var _container_panels: Array = []
var _container_overflow: Node = null
var _extract_timer := -1.0
var _extract_pad: Node3D = null
var _dead := false
var _dead_timer := 0.0
var _raid_plan: Dictionary = {}
var _plan_banner_t := 0.0
var _map_id := "factory"
var _map_name := "工厂"
var _zone_label_fn: Callable = Callable()
var _raid_left := 0.0
var _foes_label: Label = null
var _foes_left := 0
var _amb_loop: AudioStreamPlayer = null
var _weapon_stash: Dictionary = {}  # slot index -> {mag, reserve, cooldown}
var _weapon_slots: Array[String] = ["pm", ""]  # KEY_1 主武器 / KEY_2 副武器
var _active_slot := 0


func _ready() -> void:
	GAME_STATE.ensure()
	_map_id = String(GAME_STATE.raid_map_id)
	# 工厂：室内固定设施——无昼夜太阳光，照明全部来自地图灯光表。
	_build_indoor_lighting()
	var built: Dictionary = FACTORY_MAP.build(self, GAME_STATE.raid_plan)
	_raid_plan = {"source": "factory"}
	_map_name = FACTORY_MAP.MAP_NAME
	_zone_label_fn = FACTORY_MAP.zone_label_at
	_raid_left = FACTORY_MAP.RAID_SECONDS
	_build_player(built.get("spawn", Vector3.ZERO), float(built.get("spawn_yaw", 0.0)))
	_hook_crate_auto_open()
	_hook_enemies()
	_build_hud()
	# 工厂环境底噪（机器嗡鸣+底噪循环），整场常驻。
	_amb_loop = SFX.loop_2d(SFX.stream("amb_factory_loop"), self, -18.0)
	print("[SPAWN] map=%s pos=(%.1f,%.1f) yaw=%.2f" % [_map_id, _player.global_position.x, _player.global_position.z, _player.rotation.y])


func _process(delta: float) -> void:
	# Held-LMB auto fire; every shot routes through _fire_from's guards
	# (alive, no loot UI, cursor captured, capture grace elapsed).
	if _weapon != null and WEAPON_DATA.is_auto(_weapon.weapon_id) \
			and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_fire_from(-_player.get_node("Camera3D").global_basis.z)
	for slot_idx in _weapon_stash:
		var st: Dictionary = _weapon_stash[slot_idx]
		st["cooldown"] = maxf(0.0, float(st.get("cooldown", 0.0)) - delta)
	_update_interact_prompt()
	# raid 倒计时：归零判 MIA（等同阵亡——丢背包回生存屋）。
	# 必须先于撤离结算：同帧双归零时超时优先，否则能绕过 MIA 惩罚成功撤离。
	if _raid_left > 0.0:
		_raid_left -= delta
		if _raid_left <= 0.0 and not _dead:
			_on_mia()
		_update_clock_hud()
	if _extract_timer >= 0.0 and _extract_pad != null:
		if _player.global_position.distance_to(_extract_pad.global_position) > 4.0:
			_extract_timer = -1.0
		else:
			_extract_timer -= delta
			if _extract_timer <= 0.0:
				_do_extract()
	if _plan_banner_t > 0.0:
		_plan_banner_t -= delta
		if _plan_banner_t <= 0.0 and _plan_label != null:
			_plan_label.text = ""
	if _dead and _dead_timer > 0.0:
		_dead_timer -= delta
		if _dead_timer <= 0.0:
			RAID_KIT.clear_backpack(GAME_STATE.backpack)
			GAME_STATE.raid_pending.clear()
			get_tree().change_scene_to_file(HIDEOUT_SCENE)
	_update_pack_hud()
	_update_zone_hud()
	if Engine.get_process_frames() % 10 == 0 and _player != null:
		var t := _interact_target()
		var tp := "-"
		if t != null:
			tp = String(t.display_prompt()) if t.has_method("display_prompt") else String(t.get("prompt"))
		print("[NAV] pos=(%.1f,%.2f,%.1f) yaw=%.2f pitch=%.2f zone=%s left=%.0f fps=%d foes=%d target=%s" % [
			_player.global_position.x, _player.global_position.y, _player.global_position.z,
			_player.rotation.y, _player.get_node("Camera3D").rotation.x,
			String(_zone_label_fn.call(_player.global_position)) if _zone_label_fn.is_valid() else "?",
			_raid_left, Engine.get_frames_per_second(), _foes_left, tp])


func _unhandled_input(event: InputEvent) -> void:
	if _container_layer != null:
		if event is InputEventKey and event.pressed and not event.echo \
				and event.keycode in [KEY_F, KEY_ESCAPE, KEY_I]:
			_close_container()
			get_viewport().set_input_as_handled()
		return
	if _dead:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				if _weapon != null:
					_scavenge_ammo()
					_weapon.start_reload()
			KEY_F:
				_on_interact()
			KEY_I:
				_toggle_backpack_view()
			KEY_H:
				if _health != null:
					_health.damage(15.0, "debug")
			KEY_1, KEY_2:
				_switch_weapon(event.keycode - KEY_1)


# --- scene construction -------------------------------------------------------

## 室内图光照：无天空/太阳/昼夜——深色环境底光 + 地图 OmniLight 阵列。
func _build_indoor_lighting() -> void:
	var world := WorldEnvironment.new()
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = Color(0.035, 0.035, 0.045)
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color(0.55, 0.58, 0.62)
	_environment.ambient_light_energy = 0.25
	world.environment = _environment
	add_child(world)


func _build_player(spawn: Vector3, yaw: float) -> void:
	_player = CharacterBody3D.new()
	_player.name = "Player"
	_player.set_script(PLAYER_SCRIPT)
	_player.position = spawn
	_player.rotation.y = yaw
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.31
	capsule.height = 1.75
	collision.shape = capsule
	collision.position.y = 0.875
	_player.add_child(collision)
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.position.y = 1.64
	camera.fov = 62.0
	camera.far = 160.0
	camera.current = true
	_player.add_child(camera)
	add_child(_player)
	_weapon = WEAPON_CONTROLLER.new()
	_weapon.name = "WeaponController"
	_player.add_child(_weapon)
	_apply_loadout()
	_weapon.ammo_changed.connect(func(_m: int, _r: int) -> void: _update_ammo_hud())
	_weapon.reload_started.connect(func() -> void:
		_update_ammo_hud()
		SFX.play_2d(SFX.stream("sfx_reload"), self, -10.0))
	_weapon.reload_finished.connect(func(_n: int) -> void: _update_ammo_hud())
	_weapon.weapon_changed.connect(func(_id: String) -> void: _update_ammo_hud())
	_player.fired.connect(func(_o: Vector3, dir: Vector3) -> void: _fire_from(dir))
	_health = HEALTH.new()
	_health.name = "Health"
	_player.add_child(_health)
	_health.protection = GAME_STATE.armor_reduction()
	_health.died.connect(_on_player_died)
	_health.damaged.connect(func(_a: float, _s: String) -> void:
		SFX.play_2d(SFX.stream("sfx_hit"), self, -10.0))


## 装备生效: 主武器/副武器来自装备槽位（未装备主武器时给一把 PM 手枪兜底），
## 护甲减伤走 health.protection；背包格子已在出发时按背包品目收放。
func _apply_loadout() -> void:
	var equipped := GAME_STATE.equipped_weapons()
	_weapon_slots = [equipped[0] if not equipped[0].is_empty() else "pm", equipped[1]]
	_weapon.setup(_weapon_slots[0], -1, 90)
	_active_slot = 0
	if not _weapon_slots[1].is_empty():
		_weapon_stash[1] = {"mag": -1, "reserve": 60, "cooldown": 0.0}
	_scavenge_ammo()


## Each crate auto-opens its grid when the search ends and the player is
## still facing it.
func _hook_crate_auto_open() -> void:
	for crate in get_node("LootCrates").get_children():
		crate.searchable.search_finished.connect(func(_items: Array) -> void:
			if _interact_target() == crate and _container_layer == null:
				_open_crate(crate))


func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var hud := HUD_KIT.overlay(canvas)
	_zone_label = HUD_KIT.info_chip(hud, Vector2(20, 20), _map_name)
	HUD_KIT.help_line(hud, "WASD 移动 | F 交互 | I 背包 | R 换弹 | 1-2 切枪 | Esc 释放鼠标")
	_clock_label = HUD_KIT.label(hud, "", Vector2(20, 50), 14, Color(0.85, 0.85, 0.8))
	_pack_label = HUD_KIT.label(hud, "", Vector2(20, 76), 14, Color(0.8, 0.9, 0.8))
	_ammo_label = HUD_KIT.label(hud, "", Vector2(-160, -46), 22, Color(1.0, 0.9, 0.6))
	_ammo_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_prompt_label = HUD_KIT.label(hud, "", Vector2(-140, 30), 18, Color(0.95, 0.95, 0.8), true)
	_banner_label = HUD_KIT.label(hud, "", Vector2(-160, -60), 26, Color(1.0, 0.5, 0.4), true)
	_plan_label = HUD_KIT.label(hud, "", Vector2(-160, -28), 18, Color(0.7, 0.9, 1.0), true)
	_plan_label.text = "行动方案：工厂（固定设施 · 室内CQB）"
	_plan_banner_t = 6.0
	var health_widget := HEALTH_UI.new()
	health_widget.position = Vector2(20, 110)
	health_widget.bind(_health)
	hud.add_child(health_widget)
	_foes_label = HUD_KIT.label(hud, "", Vector2(20, 160), 14, Color(1.0, 0.6, 0.5))
	_update_foes_hud()
	_update_ammo_hud()


# --- combat -------------------------------------------------------------------

# 槽位索引切枪 —— 主副武器同型时各自保留独立弹匣/冷却（KEY_1/KEY_2）
func _switch_weapon(slot_idx: int) -> void:
	if _weapon == null or _dead or slot_idx == _active_slot or slot_idx >= _weapon_slots.size():
		return
	var target: String = _weapon_slots[slot_idx]
	if target.is_empty():
		return
	_weapon_stash[_active_slot] = {
		"mag": _weapon.mag,
		"reserve": _weapon.reserve,
		"cooldown": _weapon.get("_cooldown"),
	}
	var st: Dictionary = _weapon_stash.get(slot_idx, {})
	_weapon.setup(target, int(st.get("mag", -1)), int(st.get("reserve", 90)))
	_weapon.set("_cooldown", float(st.get("cooldown", 0.0)))
	_active_slot = slot_idx
	_scavenge_ammo()
	print("[WPN] slot=%d id=%s mag=%d reserve=%d" % [_active_slot, _weapon.weapon_id, _weapon.mag, _weapon.reserve])
	_update_ammo_hud()


## 搜刮弹药生效：把背包里当前武器口径的弹药并入储备弹。
## 出发/换弹/切枪各收一次——储备弹就是「装在枪上的弹药」。
func _scavenge_ammo() -> void:
	if _weapon == null or GAME_STATE.backpack == null:
		return
	var ammo_id := WEAPON_DATA.ammo_id(_weapon.weapon_id)
	if ammo_id.is_empty():
		return
	var pulled := 0
	for entry in GAME_STATE.backpack.entries():
		if String(entry["id"]) != ammo_id:
			continue
		var taken: Dictionary = GAME_STATE.backpack.take_at(entry["pos"], -1)
		pulled += int(taken.get("count", 0))
	if pulled > 0:
		_weapon.give_ammo(pulled)
		print("[WPN] ammo +%d (%s)" % [pulled, ammo_id])


func _fire_from(direction: Vector3) -> void:
	if _weapon == null or _dead or _container_layer != null \
			or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED \
			or float(_player.get("_capture_grace")) > 0.0:
		return
	var shots: Array = _weapon.try_fire(direction)
	if shots.is_empty():
		return
	# 实际击发才结束出生保护（空枪/换弹点击不解除——review BUG_0001）。
	_end_enemy_grace()
	SFX.play_2d(SFX.gunshot_for(_weapon.weapon_id), self, -4.0)
	print("[FIRE] shots=%d id=%s" % [shots.size(), _weapon.weapon_id])
	_update_ammo_hud()
	var space := get_world_3d().direct_space_state
	var cam: Camera3D = _player.get_node("Camera3D")
	for shot in shots:
		var dir: Vector3 = shot["direction"]
		var range_m := float(shot.get("range_m", 80.0))
		var query := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position + dir * range_m)
		query.exclude = [_player.get_rid()]  # exclude は RID 配列 — Node を渡すとレイが失敗する
		var hit := space.intersect_ray(query)
		if not hit.is_empty() and hit["collider"].has_method("take_damage"):
			hit["collider"].take_damage(float(shot.get("damage", WEAPON_DATA.damage(_weapon.weapon_id))))


func _update_ammo_hud() -> void:
	if _ammo_label != null and _weapon != null:
		_ammo_label.text = _weapon.ammo_text()


func _on_player_died() -> void:
	_fail_raid("阵亡 —— 背包物资丢失，返回生存屋…")


## 行动超时（MIA）：同阵亡惩罚——背包清空、计 departed 不计 completed。
func _on_mia() -> void:
	_fail_raid("行动超时 MIA —— 背包物资丢失，返回生存屋…")


func _fail_raid(banner: String) -> void:
	if _dead:
		return
	_dead = true
	_dead_timer = 3.5
	_extract_timer = -1.0  # dying mid-countdown cancels extraction
	_player.set("frozen", true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _container_layer != null:
		_release_held_loot()
		_container_layer.queue_free()
		_container_layer = null
		_container_panels = []
		_container_overflow = null
	SFX.play_2d(SFX.stream("sfx_death"), self, -4.0)
	_banner_label.text = banner


# --- raid loop: interact / loot / extract --------------------------------------

func _interact_target() -> Node3D:
	if _player == null:
		return null
	var cam: Camera3D = _player.get_node("Camera3D")
	var from := cam.global_position
	var to := from + -cam.global_basis.z * REACH
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var body = hit.get("collider")
	return body if body != null and body.is_in_group("interactable") else null


func _update_interact_prompt() -> void:
	if _prompt_label == null:
		return
	if _dead or _container_layer != null:
		_prompt_label.text = ""
		return
	if _extract_timer >= 0.0:
		_prompt_label.text = "撤离中 %.0f…（离开即取消）" % _extract_timer
		return
	var target := _interact_target()
	if target == null:
		_prompt_label.text = ""
		return
	if target.has_method("display_prompt"):
		_prompt_label.text = "[F] %s" % String(target.display_prompt())
	else:
		_prompt_label.text = "[F] %s" % String(target.get("prompt"))


func _on_interact() -> void:
	var target := _interact_target()
	if target == null:
		return
	print("[INTERACT] %s | %s" % [target.get("action"), String(target.get("prompt"))])
	match StringName(target.get("action")):
		&"loot":
			var crate: Node = target
			if crate.searching():
				return
			if not crate.searched():
				crate.begin_search()
			else:
				_open_crate(crate)
		&"extract":
			if _extract_timer < 0.0:
				_extract_pad = target
				_extract_timer = 8.0
		&"locked_door":
			target.try_open()


## 敌人接线：巡逻 scav 索敌目标 = 玩家；阵亡掉尸体箱挂进 LootCrates，
## 沿用同一个「搜索完自动开格」的钩子。
func _hook_enemies() -> void:
	var group := get_node_or_null("Enemies")
	if group == null:
		return
	for scav in group.get_children():
		scav.set_target(_player)
		scav.died.connect(_on_enemy_died)
	_foes_left = group.get_child_count()


func _end_enemy_grace() -> void:
	var group := get_node_or_null("Enemies")
	if group == null:
		return
	for scav in group.get_children():
		if scav.has_method("end_grace"):
			scav.end_grace()


func _on_enemy_died(scav: Node3D, corpse: Node3D) -> void:
	get_node("LootCrates").add_child(corpse)
	corpse.searchable.search_finished.connect(func(_items: Array) -> void:
		if _interact_target() == corpse and _container_layer == null:
			_open_crate(corpse))
	_foes_left = maxi(0, _foes_left - 1)
	_update_foes_hud()


func _update_foes_hud() -> void:
	if _foes_label != null:
		_foes_label.text = "敌人 %d" % _foes_left


func _open_crate(crate: Node) -> void:
	SFX.play_2d(SFX.stream("sfx_crate_open"), self, -8.0)
	crate.drain_pending()
	_player.set("frozen", true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_container_layer = CanvasLayer.new()
	_container_panels = []
	_container_overflow = crate
	_container_layer.layer = 50
	add_child(_container_layer)
	var crate_ui := INVENTORY_UI.new()
	crate_ui.position = Vector2(60, 170)
	_container_layer.add_child(crate_ui)
	_container_panels.append(crate_ui)
	crate_ui.setup(crate.inventory, "容器 CRATE")
	var pack_ui := INVENTORY_UI.new()
	pack_ui.position = Vector2(540, 170)
	_container_layer.add_child(pack_ui)
	_container_panels.append(pack_ui)
	pack_ui.setup(GAME_STATE.backpack, "背包 BACKPACK")
	crate_ui.link(pack_ui)
	_restore_cursor_load()
	HUD_KIT.label(_panel_host(), "拖到背包带走（限重 40kg）。F/Esc/I 关闭。", Vector2(60, 640), 15)


func _panel_host() -> Control:
	# HUD_KIT.label needs a Control parent; wrap the canvas in a full-rect
	# IGNORE control so hints sit under the same rule as the HUD.
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container_layer.add_child(host)
	return host


func _toggle_backpack_view() -> void:
	_player.set("frozen", true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_container_layer = CanvasLayer.new()
	_container_panels = []
	_container_overflow = null
	_container_layer.layer = 50
	add_child(_container_layer)
	var pack_ui := INVENTORY_UI.new()
	pack_ui.position = Vector2(300, 170)
	_container_layer.add_child(pack_ui)
	_container_panels.append(pack_ui)
	pack_ui.setup(GAME_STATE.backpack, "背包 BACKPACK")
	_restore_cursor_load()
	HUD_KIT.label(_panel_host(), "检查背包。I/F/Esc 关闭。", Vector2(300, 640), 15)


func _close_container() -> void:
	_release_held_loot()
	_container_panels = []
	_container_overflow = null
	_container_layer.queue_free()
	_container_layer = null
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_player.set("_capture_grace", 0.15)
	if not _dead:
		_player.set("frozen", false)


## Cursor load must outlive the loot view — a stack already out of its grid
## would vanish with the freed panels. Homes: source grid, then every shown
## panel's inventory; leftovers park on the crate or ride in-hand
## (GAME_STATE.raid_pending) until the next view opens / extract.
func _release_held_loot() -> void:
	if _container_panels.is_empty():
		return
	var drag: Dictionary = _container_panels[0].get("_drag")
	var stacks: Array = []
	var held: Dictionary = drag.get("held", {})
	if not held.is_empty():
		stacks.append(held)
	stacks.append_array(drag.get("queued", []))
	drag["held"] = {}
	drag["queued"] = []
	var from_inv = drag.get("from_inv")
	drag["from_inv"] = null
	for stack in stacks:
		var leftover := int(stack["count"])
		var homes: Array = []
		if from_inv != null:
			homes.append(from_inv)
		for p in _container_panels:
			var inv = p.get("inventory")
			if inv == null or homes.has(inv):
				continue
			# 容器格子不是玩家的家——背包物塞回箱子，撤离时随箱子留在图里无声遗失。
			if inv != GAME_STATE.backpack and inv != from_inv:
				continue
			homes.append(inv)
		for inv in homes:
			leftover = inv.add_item(String(stack["id"]), leftover, Vector2i(-1, -1), bool(stack.get("rotated", false)))
			if leftover <= 0:
				break
		if leftover > 0:
			var parked := {"id": stack["id"], "count": leftover, "rotated": stack.get("rotated", false)}
			var crate_inv: Variant = _container_overflow.get("inventory") if _container_overflow != null else null
			if crate_inv != null and crate_inv == from_inv:
				# 箱子自己的物退回箱子（提示「还有 N 件未取」）。
				_container_overflow.pending.append(parked)
			else:
				# 玩家的物留在手上：撤离 merge_pending 入库、阵亡随背包消失。
				GAME_STATE.raid_pending.append(parked)


## Stacks left in-hand when a loot view closed ride back onto the cursor
## the next time any inventory view opens.
func _restore_cursor_load() -> void:
	if GAME_STATE.raid_pending.is_empty() or _container_panels.is_empty():
		return
	var drag: Dictionary = _container_panels[0].get("_drag")
	var waiting: Array = drag.get("queued", [])
	waiting.append_array(GAME_STATE.raid_pending)
	drag["queued"] = waiting
	GAME_STATE.raid_pending.clear()
	_container_panels[0].call("_promote_queued")


func _do_extract() -> void:
	_extract_timer = -1.0
	_extract_pad = null
	_release_held_loot()
	# 挂到 SceneTree root（跨场景存活的 viewport）：player 随 raid 场景释放
	# 不会把提示音截断——review BUG（撤离音切场景被截）。
	SFX.play_2d(SFX.stream("sfx_extract_done"), get_tree().root, -4.0)
	var result: Dictionary = RAID_KIT.merge_into_stash(GAME_STATE.backpack, GAME_STATE.stash)
	var pending_result: Dictionary = RAID_KIT.merge_pending_into_stash(GAME_STATE.raid_pending, GAME_STATE.stash)
	GAME_STATE.raids_completed += 1
	print("[Raid] extracted: %d moved, %d dropped (hands: %d/%d)" % [
		result["moved"], result["dropped"], pending_result["moved"], pending_result["dropped"]])
	get_tree().change_scene_to_file(HIDEOUT_SCENE)


func _update_pack_hud() -> void:
	if _pack_label == null or GAME_STATE.backpack == null:
		return
	_pack_label.text = "背包 %d 件 / %.1fkg" % [GAME_STATE.backpack.entry_count(), GAME_STATE.backpack.total_weight()]


func _update_zone_hud() -> void:
	if _zone_label == null or _player == null:
		return
	var zone := String(_zone_label_fn.call(_player.global_position)) if _zone_label_fn.is_valid() else ""
	_zone_label.text = " %s · %s " % [_map_name, zone]


func _update_clock_hud() -> void:
	if _clock_label == null:
		return
	_clock_label.text = "剩余时间 %s" % _fmt_left(_raid_left)


## mm:ss 倒计时文本（静态，供测试直接调用）。
static func _fmt_left(seconds: float) -> String:
	var total := int(maxf(seconds, 0.0))
	return "%02d:%02d" % [total / 60, total % 60]
