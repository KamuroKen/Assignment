extends Area3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	var level_root: Node = get_parent()
	if level_root == null:
		return

	if level_root.has_method("respawn_body_from_kill_plane"):
		level_root.call("respawn_body_from_kill_plane", body)
