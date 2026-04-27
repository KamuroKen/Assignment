@tool
extends Area3D

signal tutorial_requested(trigger: Node3D, body: Node3D)

const TUTORIAL_TRIGGER_GROUP := "level_2_tutorial_trigger"

@export var hint_id := ""
@export var tutorial_title := "Tutorial"
@export_multiline var tutorial_body := "Explain the mechanic here."
@export_range(1.0, 12.0, 0.1) var tutorial_duration := 5.0
@export var show_once := true


func _ready() -> void:
	add_to_group(TUTORIAL_TRIGGER_GROUP)

	if Engine.is_editor_hint():
		return

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func get_tutorial_hint_data() -> Dictionary:
	return {
		"hint_id": hint_id,
		"title": tutorial_title,
		"body": tutorial_body,
		"duration": tutorial_duration,
		"show_once": show_once,
	}


func _on_body_entered(body: Node3D) -> void:
	if not (body is CharacterBody3D):
		return

	tutorial_requested.emit(self, body)
