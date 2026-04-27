@tool
extends Area3D

signal tutorial_requested(trigger: Node3D, body: Node3D)

const TUTORIAL_TRIGGER_GROUP := "level_2_tutorial_trigger"

@export var hint_id := ""
@export var tutorial_title := ""
@export_multiline var tutorial_body := ""
@export_range(1.0, 12.0, 0.1) var tutorial_duration := 10.0
@export var show_once := true
@export var trigger_if_player_starts_inside := true

var _active_body_ids: Dictionary = {}


func _ready() -> void:
	add_to_group(TUTORIAL_TRIGGER_GROUP)

	if Engine.is_editor_hint():
		return

	monitoring = true
	monitorable = true

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

	if trigger_if_player_starts_inside:
		_check_initial_overlap.call_deferred()


func get_tutorial_hint_data() -> Dictionary:
	return {
		"hint_id": hint_id,
		"title": tutorial_title,
		"body": tutorial_body,
		"duration": tutorial_duration,
		"show_once": show_once,
	}


func _on_body_entered(body: Node3D) -> void:
	_try_emit_for_body(body)


func _on_body_exited(body: Node3D) -> void:
	if body == null:
		return

	_active_body_ids.erase(body.get_instance_id())


func _try_emit_for_body(body: Node3D) -> void:
	if not (body is CharacterBody3D):
		return

	var body_id := body.get_instance_id()
	if _active_body_ids.has(body_id):
		return

	_active_body_ids[body_id] = true
	tutorial_requested.emit(self, body)


func _check_initial_overlap() -> void:
	if Engine.is_editor_hint():
		return

	await get_tree().physics_frame

	for body in get_overlapping_bodies():
		_try_emit_for_body(body as Node3D)
