extends CharacterBody3D

signal fired(origin: Vector3, direction: Vector3)

const SFX := preload("res://scripts/gameplay/sfx_kit.gd")

@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.5
@export var jump_velocity: float = 5.0
@export var mouse_sensitivity: float = 0.0022
@export_range(0.1, 1.0, 0.05) var grass_speed_multiplier: float = 0.8

var camera: Camera3D
var _capture_grace: float = 0.15
var in_grass: bool = false
var fixed_camera: bool = false
# frozen: loot UIs and death freeze movement, jumping, and firing.
var frozen: bool = false
var _step_m: float = 0.0   # 脚步：按水平位移累计，每 2m 响一步


func _ready() -> void:
	camera = get_node("Camera3D") as Camera3D
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	_capture_grace = maxf(0.0, _capture_grace - delta)


func _unhandled_input(event: InputEvent) -> void:
	if frozen:
		return
	# TEMP-TEST: arrow-key look for synthetic input (revert after testing)
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_LEFT:
			rotate_y(0.06)
		elif event.keycode == KEY_RIGHT:
			rotate_y(-0.06)
		elif event.keycode == KEY_UP:
			camera.rotate_x(0.05)
			camera.rotation.x = clampf(camera.rotation.x, -1.45, 1.45)
		elif event.keycode == KEY_DOWN:
			camera.rotate_x(-0.05)
			camera.rotation.x = clampf(camera.rotation.x, -1.45, 1.45)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif event.keycode == KEY_SPACE and is_on_floor():
			velocity.y = jump_velocity
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			_capture_grace = 0.15
		else:
			fired.emit(camera.global_position, -camera.global_basis.z)
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not fixed_camera:
		if _capture_grace > 0.0:
			return
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clampf(camera.rotation.x, -1.45, 1.45)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 14.0 * delta
	var horizontal := Vector2.ZERO
	if not frozen:
		if Input.is_physical_key_pressed(KEY_W): horizontal.y -= 1.0
		if Input.is_physical_key_pressed(KEY_S): horizontal.y += 1.0
		if Input.is_physical_key_pressed(KEY_A): horizontal.x -= 1.0
		if Input.is_physical_key_pressed(KEY_D): horizontal.x += 1.0
	horizontal = horizontal.normalized()
	var speed := sprint_speed if Input.is_physical_key_pressed(KEY_SHIFT) else walk_speed
	if in_grass:
		speed *= grass_speed_multiplier
	var direction := global_basis * Vector3(horizontal.x, 0.0, horizontal.y)
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	var prev := global_position
	move_and_slide()
	if is_on_floor():
		var moved := global_position - prev
		moved.y = 0.0
		_step_m += moved.length()
		var stride := 1.6 if speed < 6.0 else 2.2
		if _step_m >= stride:
			_step_m = 0.0
			SFX.play_2d(SFX.stream("sfx_footstep"), self, -16.0)
