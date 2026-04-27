@tool
extends StaticBody3D

const WALL_SLIDE_GROUP := "wall_slide_target"
const WALL_JUMP_GROUP := "wall_jump_target"

@export var slide_direction_local := Vector3.FORWARD
@export_range(0.0, 12.0, 0.1) var slide_forward_speed := 6

@export var allows_wall_slide := true:
	set(value):
		allows_wall_slide = value
		_sync_groups()

@export var allows_wall_jump := true:
	set(value):
		allows_wall_jump = value
		_sync_groups()


func _ready() -> void:
	_sync_groups()


func _sync_groups() -> void:
	_sync_group_state(WALL_SLIDE_GROUP, allows_wall_slide)
	_sync_group_state(WALL_JUMP_GROUP, allows_wall_jump)


func _sync_group_state(group_name: StringName, should_be_present: bool) -> void:
	if should_be_present:
		if not is_in_group(group_name):
			add_to_group(group_name)
		return

	if is_in_group(group_name):
		remove_from_group(group_name)


func get_wall_slide_travel_direction() -> Vector3:
	var direction := basis * slide_direction_local.normalized()
	direction.y = 0.0
	return direction.normalized()


func get_wall_slide_forward_speed() -> float:
	return slide_forward_speed
