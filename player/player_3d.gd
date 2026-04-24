extends CharacterBody3D

@export_group("Movement")
@export var move_speed := 8.0
@export var acceleration := 20.0
@export var rotation_speed := 12.0
@export var jump_impulse := 12.0

@export_group("Dust")
@export_range(0.0, 1.0, 0.01) var dust_amount_ratio := 1
@export_range(0.01, 1.0, 0.01) var dust_scale_min := 0.3
@export_range(0.01, 1.0, 0.01) var dust_scale_max := 0.6
@export_range(0.0, 5.0, 0.05) var dust_speed_scale := 1.0
@export_range(0.0, 3.0, 0.05) var dust_trigger_speed := 0.15

@export_group("Camera")
@export_range(0.0, 1.0) var mouse_sensitivity := 0.25
@export var tilt_upper_limit := PI / 3.0
@export var tilt_lower_limit := -PI / 6.0

var _camera_input_direction := Vector2.ZERO
var _last_movement_direction := Vector3.BACK
var _gravity := -30.0
var _controls_locked := false

@onready var _camera_pivot: Node3D = %CameraPivot
@onready var _camera: Camera3D = %Camera3D
@onready var _skin: SophiaSkin = %SophiaSkin
@onready var _dust_particles: GPUParticles3D = %DustParticles
@onready var _dust_process_material := _dust_particles.process_material as ParticleProcessMaterial


func _ready():
	_configure_dust_particles()
	_set_dust_emitting(false)


func _input(event: InputEvent):
	if _controls_locked:
		return

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event.is_action_pressed("left_click"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent):
	if _controls_locked:
		return

	var is_camera_motion := (
		event is InputEventMouseMotion and
		Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	)
	if is_camera_motion:
		_camera_input_direction = event.screen_relative * mouse_sensitivity


func _physics_process(delta: float):
	if _controls_locked:
		_set_dust_emitting(false)
		_camera_input_direction = Vector2.ZERO
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y += _gravity * delta
			move_and_slide()
		else:
			velocity.y = 0.0
			_skin.idle()
		return

	_camera_pivot.rotation.x += _camera_input_direction.y * delta
	_camera_pivot.rotation.x = clamp(_camera_pivot.rotation.x, tilt_lower_limit, tilt_upper_limit)
	_camera_pivot.rotation.y -= _camera_input_direction.x * delta

	_camera_input_direction = Vector2.ZERO

	var raw_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var forward := _camera.global_basis.z
	var right := _camera.global_basis.x
	var move_direction := forward * raw_input.y + right * raw_input.x
	move_direction.y = 0.0
	move_direction = move_direction.normalized()

	var y_velocity := velocity.y
	velocity.y = 0.0
	velocity = velocity.move_toward(move_direction * move_speed, acceleration * delta)
	velocity.y = y_velocity + _gravity * delta

	var is_starting_jump := Input.is_action_just_pressed("jump") and is_on_floor()
	if is_starting_jump:
		velocity.y += jump_impulse

	move_and_slide()

	if move_direction.length() > 0.2:
		_last_movement_direction = move_direction
	var target_angle := Vector3.BACK.signed_angle_to(_last_movement_direction, Vector3.UP)
	_skin.global_rotation.y = lerp_angle(_skin.global_rotation.y, target_angle, rotation_speed * delta)

	if is_starting_jump:
		_skin.jump()
		_set_dust_emitting(false)
	elif not is_on_floor() and velocity.y < 0:
		_skin.fall()
		_set_dust_emitting(false)
	elif is_on_floor():
		var ground_speed := Vector2(velocity.x, velocity.z).length()
		if ground_speed > 0.0:
			_skin.move()
		else:
			_skin.idle()

		_update_dust_particles(ground_speed)
	else:
		_set_dust_emitting(false)


func set_controls_locked(is_locked: bool):
	_controls_locked = is_locked
	_camera_input_direction = Vector2.ZERO
	if is_locked:
		_set_dust_emitting(false)
		velocity = Vector3.ZERO
		_skin.idle()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _configure_dust_particles():
	if _dust_process_material == null:
		return

	_dust_process_material.scale_min = dust_scale_min
	_dust_process_material.scale_max = dust_scale_max


func _update_dust_particles(ground_speed: float):
	if ground_speed <= dust_trigger_speed:
		_set_dust_emitting(false)
		return

	var speed_ratio := clampf(ground_speed / move_speed, 0.0, 1.0)
	_dust_particles.amount_ratio = dust_amount_ratio * speed_ratio
	_dust_particles.speed_scale = dust_speed_scale
	_set_dust_emitting(_dust_particles.amount_ratio > 0.01)


func _set_dust_emitting(is_emitting: bool):
	if _dust_particles.emitting == is_emitting:
		return

	_dust_particles.emitting = is_emitting
