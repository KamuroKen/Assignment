@tool
extends StaticBody3D

const LEDGE_GRAB_GROUP := "ledge_grab_target"

@export var allows_ledge_grab := false:
	set(value):
		allows_ledge_grab = value
		_sync_ledge_grab_group()


func _ready() -> void:
	_sync_ledge_grab_group()


func _sync_ledge_grab_group() -> void:
	if allows_ledge_grab:
		if not is_in_group(LEDGE_GRAB_GROUP):
			add_to_group(LEDGE_GRAB_GROUP)
		return

	if is_in_group(LEDGE_GRAB_GROUP):
		remove_from_group(LEDGE_GRAB_GROUP)
