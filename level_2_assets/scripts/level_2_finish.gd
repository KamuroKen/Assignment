@tool
extends Node3D


signal player_entered(finish: Node3D, body: Node3D)
signal player_exited(finish: Node3D, body: Node3D)


func _ready() -> void:
	add_to_group("level_2_finish")

	if Engine.is_editor_hint():
		return

	var trigger := get_node_or_null("TriggerArea") as Area3D
	if trigger != null:
		if not trigger.body_entered.is_connected(_on_trigger_body_entered):
			trigger.body_entered.connect(_on_trigger_body_entered)
		if not trigger.body_exited.is_connected(_on_trigger_body_exited):
			trigger.body_exited.connect(_on_trigger_body_exited)


func _on_trigger_body_entered(body: Node3D) -> void:
	player_entered.emit(self, body)


func _on_trigger_body_exited(body: Node3D) -> void:
	player_exited.emit(self, body)
