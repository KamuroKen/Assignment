@tool
extends Node3D


signal checkpoint_reached(checkpoint: Node3D, body: Node3D)

const PLATFORM_IDLE_EMISSION := 0.0
const PLATFORM_ACTIVE_EMISSION := 0.18
const BEACON_IDLE_EMISSION := 0.12
const BEACON_ACTIVE_EMISSION := 1.35

@export var shows_tutorial_hint := false
@export var tutorial_hint_id := "checkpoint_intro"
@export var tutorial_title := "Checkpoint"
@export_multiline var tutorial_body := "If you fall, you will restart from here."
@export_range(1.0, 12.0, 0.1) var tutorial_duration := 4.5
@export var tutorial_show_once := true

var _is_active := false


func _ready() -> void:
	add_to_group("level_2_checkpoint")

	if Engine.is_editor_hint():
		return

	_apply_state_visuals()
	var trigger := get_node_or_null("TriggerArea") as Area3D
	if trigger != null and not trigger.body_entered.is_connected(_on_trigger_body_entered):
		trigger.body_entered.connect(_on_trigger_body_entered)


func set_active(is_active: bool) -> void:
	_is_active = is_active
	_apply_state_visuals()


func get_respawn_position() -> Vector3:
	var marker := get_node_or_null("RespawnMarker") as Node3D
	if marker != null:
		return marker.global_position
	return global_position + Vector3(0.0, 0.61, -2.2)


func get_respawn_rotation() -> Vector3:
	var marker := get_node_or_null("RespawnMarker") as Node3D
	if marker != null:
		return marker.global_rotation
	return global_rotation


func get_tutorial_hint_data() -> Dictionary:
	if not shows_tutorial_hint:
		return {}

	return {
		"hint_id": tutorial_hint_id,
		"title": tutorial_title,
		"body": tutorial_body,
		"duration": tutorial_duration,
		"show_once": tutorial_show_once,
	}


func _on_trigger_body_entered(body: Node3D) -> void:
	checkpoint_reached.emit(self, body)


func _apply_state_visuals() -> void:
	var platform_mesh := get_node_or_null("PlatformBody/MeshInstance3D") as MeshInstance3D
	var platform_material := _ensure_local_material(platform_mesh)
	if platform_material != null:
		platform_material.emission_enabled = true
		platform_material.emission = platform_material.albedo_color
		platform_material.emission_energy_multiplier = PLATFORM_ACTIVE_EMISSION if _is_active else PLATFORM_IDLE_EMISSION

	var beacon_mesh := get_node_or_null("CheckpointMarker/BeaconMesh") as MeshInstance3D
	var beacon_material := _ensure_local_material(beacon_mesh)
	if beacon_material != null:
		beacon_material.emission_enabled = true
		beacon_material.emission = beacon_material.albedo_color
		beacon_material.emission_energy_multiplier = BEACON_ACTIVE_EMISSION if _is_active else BEACON_IDLE_EMISSION


func _ensure_local_material(mesh_instance: MeshInstance3D) -> StandardMaterial3D:
	if mesh_instance == null:
		return null

	var material := mesh_instance.material_override as StandardMaterial3D
	if material == null and mesh_instance.mesh != null:
		material = mesh_instance.mesh.surface_get_material(0) as StandardMaterial3D
	if material == null:
		return null

	if not material.resource_local_to_scene:
		material = material.duplicate()
		material.resource_local_to_scene = true
		mesh_instance.material_override = material
	elif mesh_instance.material_override == null:
		mesh_instance.material_override = material

	return material
