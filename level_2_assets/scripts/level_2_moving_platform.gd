@tool
extends AnimatableBody3D

@export var move_axis := Vector3.RIGHT
@export var move_distance := 2.5
@export var move_speed := 1.2
@export var move_phase := 0.0

var _origin := Vector3.ZERO
var _elapsed := 0.0


func _ready() -> void:
	sync_to_physics = true
	_origin = position
	set_physics_process(not Engine.is_editor_hint())


func _physics_process(delta: float) -> void:
	_elapsed += delta
	var axis := move_axis.normalized()
	if axis.length_squared() <= 0.0001:
		axis = Vector3.RIGHT

	position = _origin + axis * sin(_elapsed * move_speed + move_phase) * move_distance
