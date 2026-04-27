@tool
extends AnimatableBody3D

@export var rotation_axis := Vector3.UP
@export var speed_degrees := 24.0

var _base_rotation := Vector3.ZERO
var _elapsed := 0.0


func _ready() -> void:
	sync_to_physics = true
	_base_rotation = rotation
	set_physics_process(not Engine.is_editor_hint())


func _physics_process(delta: float) -> void:
	_elapsed += delta
	var axis := rotation_axis.normalized()
	if axis.length_squared() <= 0.0001:
		axis = Vector3.UP

	var angle := deg_to_rad(speed_degrees) * _elapsed
	rotation = _base_rotation + axis * angle
