@tool
extends Node3D


signal player_entered(finish: Node3D, body: Node3D)


func _ready() -> void:
	add_to_group("level_2_finish")

	if Engine.is_editor_hint():
		return

	var trigger := get_node_or_null("TriggerArea") as Area3D
	if trigger != null:
		if not trigger.body_entered.is_connected(_on_trigger_body_entered):
			trigger.body_entered.connect(_on_trigger_body_entered)


func _on_trigger_body_entered(body: Node3D) -> void:
	player_entered.emit(self, body)


func play_finish_vfx() -> void:
	if Engine.is_editor_hint():
		return

	for node_name in ["ConfettiLeft", "ConfettiRight"]:
		var particles := get_node_or_null(node_name) as GPUParticles3D
		if particles == null:
			continue
		particles.emitting = false
		particles.restart()
		particles.emitting = true
