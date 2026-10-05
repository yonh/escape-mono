extends CharacterBody3D

const SPEED := 4.0
const MOUSE_SENS := 0.0025
const PITCH_LIMIT := 1.45
const KB_LOOK := true
const NAV_LOG := true

@onready var camera: Camera3D = $Camera3D
@onready var ray: RayCast3D = $Camera3D/InteractRay
@onready var prompt: Label = $HUD/Prompt

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENS)
		camera.rotate_x(-event.relative.y * MOUSE_SENS)
		camera.rotation.x = clampf(camera.rotation.x, -PITCH_LIMIT, PITCH_LIMIT)
	elif KB_LOOK and event is InputEventKey and event.pressed:
		if event.keycode == KEY_LEFT:
			rotate_y(0.06)
		elif event.keycode == KEY_RIGHT:
			rotate_y(-0.06)
		elif event.keycode == KEY_UP:
			camera.rotate_x(0.05)
			camera.rotation.x = clampf(camera.rotation.x, -PITCH_LIMIT, PITCH_LIMIT)
		elif event.keycode == KEY_DOWN:
			camera.rotate_x(-0.05)
			camera.rotation.x = clampf(camera.rotation.x, -PITCH_LIMIT, PITCH_LIMIT)
	elif event.is_action_pressed("interact"):
		var target := ray.get_collider()
		if target is Interactable:
			target.interact()
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED
	move_and_slide()

func _process(_delta: float) -> void:
	var target := ray.get_collider()
	prompt.text = "[F] " + target.prompt if target is Interactable else ""
	if NAV_LOG and Engine.get_process_frames() % 15 == 0:
		var target_name: String = target.name if target else "-"
		print("[NAV] pos=(%.1f,%.1f) yaw=%.2f pitch=%.2f target=%s" % [
			global_position.x, global_position.z, rotation.y, camera.rotation.x, target_name])
