extends CharacterBody3D

const LEDGE_GRAB_GROUP := "ledge_grab_target"
const WALL_SLIDE_GROUP := "wall_slide_target"
const WALL_JUMP_GROUP := "wall_jump_target"

enum MovementMode {
	NORMAL,
	LEDGE_HANG,
	LEDGE_CLIMB,
	WALL_SLIDE,
}

@export_group("Movement")
@export var move_speed := 8.0
@export var acceleration := 20.0
@export var rotation_speed := 12.0
@export var jump_impulse := 12.0

@export_group("Ledge Grab")
@export var ledge_grab_enabled := true
@export_range(0.2, 2.0, 0.05) var ledge_wall_probe_distance := 1.05
@export_range(0.2, 2.5, 0.05) var ledge_wall_probe_height := 0.90
@export_range(0.2, 3.0, 0.05) var ledge_head_probe_height := 1.80
@export_range(0.2, 3.0, 0.05) var ledge_top_probe_height := 2.25
@export_range(0.1, 1.5, 0.05) var ledge_top_probe_forward := 0.70
@export_range(0.5, 4.0, 0.05) var ledge_top_probe_drop := 3.35
@export_range(0.0, 4.0, 0.05) var ledge_max_grab_vertical_speed := 2.50
@export_range(0.2, 2.5, 0.05) var ledge_min_top_height := 0.20
@export_range(0.2, 2.5, 0.05) var ledge_max_top_height := 1.85
@export_range(0.1, 1.2, 0.05) var ledge_hang_outward_offset := 0.70
@export_range(0.4, 2.0, 0.05) var ledge_hang_vertical_offset := 1.05
@export_range(0.1, 1.2, 0.05) var ledge_climb_inset := 0.38
@export_range(0.1, 1.0, 0.05) var ledge_climb_height_offset := 0.35
@export_range(0.05, 0.5, 0.01) var ledge_climb_duration := 0.30
@export_range(0.05, 1.0, 0.01) var ledge_regrab_cooldown := 0.05
@export_range(0.1, 1.0, 0.05) var ledge_clearance_radius := 0.22
@export_range(0.2, 2.0, 0.05) var ledge_clearance_height := 0.95

@export_group("Wall Slide")
@export var wall_slide_enabled := true
@export_range(0.2, 2.0, 0.05) var wall_probe_distance := 0.65
@export_range(0.2, 2.5, 0.05) var wall_probe_height := 0.90
@export_range(0.05, 1.0, 0.05) var wall_hold_min_input_dot := 0.18
@export_range(0.0, 4.0, 0.05) var wall_attach_max_vertical_speed := 1.10
@export_range(0.5, 8.0, 0.05) var wall_slide_max_fall_speed := 3.70
@export_range(0.0, 1.0, 0.05) var wall_slide_gravity_scale := 0.18
@export_range(0.5, 12.0, 0.1) var wall_stick_strength := 5.40
@export_range(1.0, 14.0, 0.1) var wall_jump_push_impulse := 8.40
@export_range(1.0, 16.0, 0.1) var wall_jump_up_impulse := 10.80
@export_range(0.05, 1.0, 0.01) var wall_regrab_cooldown := 0.0

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
var _movement_mode := MovementMode.NORMAL
var _ledge_cooldown_remaining := 0.0
var _ledge_hang_position := Vector3.ZERO
var _ledge_climb_target_position := Vector3.ZERO
var _ledge_wall_normal := Vector3.ZERO
var _ledge_climb_elapsed := 0.0
var _ledge_clearance_shape := SphereShape3D.new()
var _wall_slide_normal := Vector3.ZERO
var _wall_slide_collider_rid := RID()
var _blocked_wall_rid := RID()
var _wall_regrab_remaining := 0.0
var _wall_slide_travel_direction := Vector3.ZERO
var _wall_slide_forward_speed := 0.0

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

	_update_camera(delta)
	_ledge_cooldown_remaining = maxf(0.0, _ledge_cooldown_remaining - delta)
	_wall_regrab_remaining = maxf(0.0, _wall_regrab_remaining - delta)

	match _movement_mode:
		MovementMode.LEDGE_HANG:
			_process_ledge_hang()
			return
		MovementMode.LEDGE_CLIMB:
			_process_ledge_climb(delta)
			return
		MovementMode.WALL_SLIDE:
			_process_wall_slide(delta)
			return

	_process_normal_movement(delta)


func set_controls_locked(is_locked: bool):
	_controls_locked = is_locked
	_camera_input_direction = Vector2.ZERO
	reset_movement_state()
	if is_locked:
		_set_dust_emitting(false)
		velocity = Vector3.ZERO
		_skin.idle()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func reset_movement_state() -> void:
	_movement_mode = MovementMode.NORMAL
	_ledge_cooldown_remaining = 0.0
	_ledge_climb_elapsed = 0.0
	_ledge_hang_position = Vector3.ZERO
	_ledge_climb_target_position = Vector3.ZERO
	_ledge_wall_normal = Vector3.ZERO
	_wall_slide_normal = Vector3.ZERO
	_wall_slide_collider_rid = RID()
	_blocked_wall_rid = RID()
	_wall_regrab_remaining = 0.0
	_wall_slide_travel_direction = Vector3.ZERO
	_wall_slide_forward_speed = 0.0


func _update_camera(delta: float) -> void:
	_camera_pivot.rotation.x += _camera_input_direction.y * delta
	_camera_pivot.rotation.x = clamp(_camera_pivot.rotation.x, tilt_lower_limit, tilt_upper_limit)
	_camera_pivot.rotation.y -= _camera_input_direction.x * delta
	_camera_input_direction = Vector2.ZERO


func _process_normal_movement(delta: float) -> void:
	var raw_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var move_direction := _get_move_direction(raw_input)

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

	if _try_start_ledge_grab():
		return
	if _try_start_wall_slide(move_direction):
		return

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


func _process_ledge_hang() -> void:
	velocity = Vector3.ZERO
	global_position = _ledge_hang_position
	_set_dust_emitting(false)

	if Input.is_action_just_pressed("move_down"):
		_release_ledge()
		return

	if Input.is_action_just_pressed("jump"):
		_start_ledge_climb()
		return

	_skin.edge_grab()


func _process_ledge_climb(delta: float) -> void:
	_ledge_climb_elapsed += delta
	var duration := maxf(ledge_climb_duration, 0.01)
	var t := clampf(_ledge_climb_elapsed / duration, 0.0, 1.0)
	var eased_t := t * t * (3.0 - 2.0 * t)

	velocity = Vector3.ZERO
	global_position = _ledge_hang_position.lerp(_ledge_climb_target_position, eased_t)
	_set_dust_emitting(false)
	_skin.jump()

	if t >= 1.0:
		_movement_mode = MovementMode.NORMAL
		_ledge_cooldown_remaining = ledge_regrab_cooldown
		velocity = Vector3.ZERO


func _process_wall_slide(delta: float) -> void:
	var raw_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var travel_intent := -raw_input.y

	var wall_hit := _find_wall_hit_from_normal(_wall_slide_normal)
	if not _is_valid_wall_slide_hit(wall_hit):
		_stop_wall_slide()
		return

	var wall_normal: Vector3 = wall_hit.get("normal", Vector3.ZERO)
	_wall_slide_normal = wall_normal
	var wall_collider := wall_hit.get("collider") as CollisionObject3D
	if wall_collider != null:
		_wall_slide_collider_rid = wall_collider.get_rid()

	if Input.is_action_just_pressed("jump") and wall_collider != null and wall_collider.is_in_group(WALL_JUMP_GROUP):
		_start_wall_jump()
		return

	var slide_velocity_y := velocity.y + _gravity * wall_slide_gravity_scale * delta
	velocity = -wall_normal * wall_stick_strength
	if absf(travel_intent) > 0.05 and _wall_slide_travel_direction.length_squared() > 0.0001:
		velocity += _wall_slide_travel_direction * (_wall_slide_forward_speed * travel_intent)
	velocity.y = maxf(slide_velocity_y, -wall_slide_max_fall_speed)
	move_and_slide()

	if is_on_floor():
		_stop_wall_slide()
		_skin.idle()
		return

	if absf(travel_intent) > 0.05 and _wall_slide_travel_direction.length_squared() > 0.0001:
		_last_movement_direction = _wall_slide_travel_direction * signf(travel_intent)
	else:
		_last_movement_direction = -wall_normal
	var visual_direction := _last_movement_direction
	var target_angle := Vector3.BACK.signed_angle_to(visual_direction, Vector3.UP)
	_skin.global_rotation.y = lerp_angle(_skin.global_rotation.y, target_angle, rotation_speed * delta)
	_skin.wall_slide()
	_set_dust_emitting(false)


func _try_start_wall_slide(move_direction: Vector3) -> bool:
	if not wall_slide_enabled:
		return false
	if _movement_mode != MovementMode.NORMAL:
		return false
	if is_on_floor() or move_direction.length_squared() <= 0.0001:
		return false
	if velocity.y > wall_attach_max_vertical_speed:
		return false

	var wall_hit := _find_wall_hit_from_direction(move_direction)
	if not _is_valid_wall_slide_hit(wall_hit):
		return false

	var wall_collider := wall_hit.get("collider") as CollisionObject3D
	if wall_collider == null or not wall_collider.is_in_group(WALL_SLIDE_GROUP):
		return false
	if _wall_regrab_remaining > 0.0 and _blocked_wall_rid.is_valid() and wall_collider.get_rid() == _blocked_wall_rid:
		return false

	var wall_normal: Vector3 = wall_hit.get("normal", Vector3.ZERO)
	if move_direction.dot(-wall_normal) < wall_hold_min_input_dot:
		return false

	_movement_mode = MovementMode.WALL_SLIDE
	_wall_slide_normal = wall_normal
	_wall_slide_collider_rid = wall_collider.get_rid()
	_wall_slide_travel_direction = _resolve_wall_slide_travel_direction(wall_collider, wall_normal, move_direction)
	_wall_slide_forward_speed = _resolve_wall_slide_forward_speed(wall_collider)
	velocity = Vector3.ZERO
	_set_dust_emitting(false)
	_skin.wall_slide()
	return true


func _stop_wall_slide() -> void:
	_movement_mode = MovementMode.NORMAL
	_wall_slide_normal = Vector3.ZERO
	_wall_slide_collider_rid = RID()
	_wall_slide_travel_direction = Vector3.ZERO
	_wall_slide_forward_speed = 0.0
	velocity.x = 0.0
	velocity.z = 0.0


func _start_wall_jump() -> void:
	var jump_normal := _wall_slide_normal
	var jump_source_rid := _wall_slide_collider_rid
	_stop_wall_slide()

	_wall_regrab_remaining = wall_regrab_cooldown
	_blocked_wall_rid = jump_source_rid
	velocity = jump_normal * wall_jump_push_impulse
	velocity.y = wall_jump_up_impulse
	_last_movement_direction = Vector3(jump_normal.x, 0.0, jump_normal.z).normalized()
	_skin.jump()


func _try_start_ledge_grab() -> bool:
	if not ledge_grab_enabled:
		return false
	if _movement_mode != MovementMode.NORMAL:
		return false
	if is_on_floor() or _ledge_cooldown_remaining > 0.0:
		return false
	if velocity.y > ledge_max_grab_vertical_speed:
		return false

	var probe_forward := _get_probe_forward()
	if probe_forward.length_squared() <= 0.0001:
		return false

	var wall_from := global_position + Vector3.UP * ledge_wall_probe_height
	var wall_to := wall_from + probe_forward * ledge_wall_probe_distance
	var wall_hit := _raycast(wall_from, wall_to)
	if wall_hit.is_empty():
		return false

	var wall_collider := wall_hit.get("collider") as Node
	if wall_collider == null or not wall_collider.is_in_group(LEDGE_GRAB_GROUP):
		return false

	var wall_normal: Vector3 = wall_hit.get("normal", Vector3.ZERO)
	if absf(wall_normal.y) > 0.25:
		return false
	if wall_normal.dot(-probe_forward) < 0.45:
		return false

	var head_from := global_position + Vector3.UP * ledge_head_probe_height
	var head_to := head_from + probe_forward * ledge_wall_probe_distance
	var head_hit := _raycast(head_from, head_to)
	if not head_hit.is_empty():
		return false

	var top_from := global_position + Vector3.UP * ledge_top_probe_height + probe_forward * ledge_top_probe_forward
	var top_to := top_from + Vector3.DOWN * ledge_top_probe_drop
	var top_hit := _raycast(top_from, top_to)
	if top_hit.is_empty():
		return false
	if top_hit.get("collider") != wall_collider:
		return false

	var top_normal: Vector3 = top_hit.get("normal", Vector3.ZERO)
	if top_normal.dot(Vector3.UP) < 0.8:
		return false

	var top_position: Vector3 = top_hit.get("position", Vector3.ZERO)
	var ledge_height := top_position.y - global_position.y
	if ledge_height < ledge_min_top_height or ledge_height > ledge_max_top_height:
		return false

	var hang_position := top_position + wall_normal * ledge_hang_outward_offset + Vector3.DOWN * ledge_hang_vertical_offset
	var climb_position := top_position - wall_normal * ledge_climb_inset + Vector3.UP * ledge_climb_height_offset
	if not _has_ledge_clearance(climb_position):
		return false

	_begin_ledge_grab(hang_position, climb_position, wall_normal)
	return true


func _begin_ledge_grab(hang_position: Vector3, climb_position: Vector3, wall_normal: Vector3) -> void:
	_movement_mode = MovementMode.LEDGE_HANG
	_ledge_hang_position = hang_position
	_ledge_climb_target_position = climb_position
	_ledge_wall_normal = wall_normal
	_ledge_climb_elapsed = 0.0
	velocity = Vector3.ZERO
	global_position = hang_position
	_set_dust_emitting(false)
	_skin.edge_grab()


func _release_ledge() -> void:
	_movement_mode = MovementMode.NORMAL
	_ledge_cooldown_remaining = ledge_regrab_cooldown
	velocity = Vector3.ZERO
	velocity.y = -1.5
	_skin.fall()


func _start_ledge_climb() -> void:
	_movement_mode = MovementMode.LEDGE_CLIMB
	_ledge_climb_elapsed = 0.0
	velocity = Vector3.ZERO
	_set_dust_emitting(false)
	_skin.jump()


func _get_move_direction(raw_input: Vector2) -> Vector3:
	var forward := _camera.global_basis.z
	var right := _camera.global_basis.x
	var move_direction := forward * raw_input.y + right * raw_input.x
	move_direction.y = 0.0
	return move_direction.normalized()


func _get_probe_forward() -> Vector3:
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	if horizontal_velocity.length() > 0.15:
		return horizontal_velocity.normalized()

	if _last_movement_direction.length() > 0.001:
		return _last_movement_direction.normalized()

	var camera_forward := _camera.global_basis.z
	camera_forward.y = 0.0
	return camera_forward.normalized()


func _find_wall_hit_from_direction(direction: Vector3) -> Dictionary:
	var normalized_direction := direction.normalized()
	if normalized_direction.length_squared() <= 0.0001:
		return {}

	var probe_from := global_position + Vector3.UP * wall_probe_height
	var probe_to := probe_from + normalized_direction * wall_probe_distance
	return _raycast(probe_from, probe_to)


func _find_wall_hit_from_normal(wall_normal: Vector3) -> Dictionary:
	if wall_normal.length_squared() <= 0.0001:
		return {}

	var probe_from := global_position + Vector3.UP * wall_probe_height
	var probe_to := probe_from - wall_normal.normalized() * wall_probe_distance
	return _raycast(probe_from, probe_to)


func _is_valid_wall_slide_hit(hit: Dictionary) -> bool:
	if hit.is_empty():
		return false

	var wall_collider := hit.get("collider") as CollisionObject3D
	if wall_collider == null or not wall_collider.is_in_group(WALL_SLIDE_GROUP):
		return false

	var wall_normal: Vector3 = hit.get("normal", Vector3.ZERO)
	return absf(wall_normal.y) <= 0.25


func _resolve_wall_slide_travel_direction(wall_collider: CollisionObject3D, wall_normal: Vector3, preferred_direction: Vector3 = Vector3.ZERO) -> Vector3:
	var direction := Vector3.ZERO
	if wall_collider != null and wall_collider.has_method("get_wall_slide_travel_direction"):
		direction = wall_collider.call("get_wall_slide_travel_direction")

	if direction.length_squared() <= 0.0001:
		direction = Vector3.UP.cross(wall_normal)

	direction.y = 0.0
	direction = (direction - wall_normal * direction.dot(wall_normal)).normalized()
	if direction.length_squared() <= 0.0001:
		direction = Vector3(wall_normal.z, 0.0, -wall_normal.x).normalized()

	var preferred := preferred_direction
	preferred.y = 0.0
	preferred = preferred - wall_normal * preferred.dot(wall_normal)

	if preferred.length_squared() <= 0.0001 and _last_movement_direction.length_squared() > 0.0001:
		preferred = _last_movement_direction
		preferred.y = 0.0
		preferred = preferred - wall_normal * preferred.dot(wall_normal)

	if preferred.length_squared() <= 0.0001:
		var camera_forward := -_camera.global_basis.z
		camera_forward.y = 0.0
		preferred = camera_forward - wall_normal * camera_forward.dot(wall_normal)

	if preferred.length_squared() > 0.0001 and direction.dot(preferred.normalized()) < 0.0:
		direction = -direction

	return direction


func _resolve_wall_slide_forward_speed(wall_collider: CollisionObject3D) -> float:
	if wall_collider != null and wall_collider.has_method("get_wall_slide_forward_speed"):
		return float(wall_collider.call("get_wall_slide_forward_speed"))
	return move_speed * 0.7


func _raycast(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)


func _has_ledge_clearance(target_position: Vector3) -> bool:
	_ledge_clearance_shape.radius = ledge_clearance_radius

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _ledge_clearance_shape
	query.transform = Transform3D(Basis.IDENTITY, target_position + Vector3.UP * ledge_clearance_height)
	query.exclude = [get_rid()]

	var hits := get_world_3d().direct_space_state.intersect_shape(query, 1)
	return hits.is_empty()


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
