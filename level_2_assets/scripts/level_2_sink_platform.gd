@tool
extends AnimatableBody3D

@export var active_offset := Vector3(0.0, -1.6, 0.0)
@export_range(0.5, 10.0, 0.1) var move_speed := 4.0
@export_range(0.5, 10.0, 0.1) var return_speed := 2.4

var _origin := Vector3.ZERO
var _occupant_count := 0


func _ready() -> void:
	sync_to_physics = true
	_origin = position

	if Engine.is_editor_hint():
		set_physics_process(false)
		return

	set_physics_process(true)
	var trigger_area := get_node_or_null("TriggerArea") as Area3D
	if trigger_area != null:
		if not trigger_area.body_entered.is_connected(_on_trigger_body_entered):
			trigger_area.body_entered.connect(_on_trigger_body_entered)
		if not trigger_area.body_exited.is_connected(_on_trigger_body_exited):
			trigger_area.body_exited.connect(_on_trigger_body_exited)


func _physics_process(delta: float) -> void:
	var target_position := _origin
	var speed := return_speed
	if _occupant_count > 0:
		target_position = _origin + active_offset
		speed = move_speed

	position = position.move_toward(target_position, speed * delta)


func _on_trigger_body_entered(body: Node3D) -> void:
	if not _is_player_body(body):
		return

	_occupant_count += 1


func _on_trigger_body_exited(body: Node3D) -> void:
	if not _is_player_body(body):
		return

	_occupant_count = maxi(0, _occupant_count - 1)


func _is_player_body(body: Node3D) -> bool:
	return body is CharacterBody3D
