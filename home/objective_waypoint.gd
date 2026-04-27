extends Node3D


@export_group("Motion")
@export_range(0.0, 1.0, 0.01) var bob_height := 0.14
@export_range(0.1, 6.0, 0.05) var bob_speed := 2.4
@export_range(0.0, 360.0, 1.0) var rotation_speed_degrees := 92.0
@export_range(0.1, 20.0, 0.1) var follow_speed := 8.0

var _time := 0.0
var _target_position := Vector3.ZERO
var _has_target := false


func _ready() -> void:
	visible = false


func _process(delta: float) -> void:
	if not visible or not _has_target:
		return

	_time += delta
	var bob_offset := Vector3.UP * sin(_time * bob_speed) * bob_height
	global_position = global_position.lerp(_target_position + bob_offset, minf(1.0, delta * follow_speed))
	rotate_y(deg_to_rad(rotation_speed_degrees) * delta)


func set_world_target(world_target: Vector3) -> void:
	_target_position = world_target
	if not _has_target:
		global_position = world_target
		_has_target = true


func clear_target() -> void:
	_has_target = false
	visible = false
