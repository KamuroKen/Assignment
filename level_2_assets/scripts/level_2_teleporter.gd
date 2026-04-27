@tool
extends Area3D


@export_node_path("Node3D") var target_path: NodePath
@export var arrival_offset := Vector3(0.0, 0.6, 0.0)
@export var keep_target_rotation := true
@export var portal_color := Color(0.37, 0.88, 0.96, 1.0):
	set(value):
		portal_color = value
		_sync_visuals()


func _ready() -> void:
	_sync_visuals()

	if Engine.is_editor_hint():
		return

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	var target := get_node_or_null(target_path) as Node3D
	if target == null:
		return

	var character := body as CharacterBody3D
	if character != null:
		if character.has_method("reset_movement_state"):
			character.call("reset_movement_state")
		character.velocity = Vector3.ZERO

	body.global_position = target.global_position + arrival_offset
	if keep_target_rotation:
		body.global_rotation = target.global_rotation


func _sync_visuals() -> void:
	var portal_mesh := get_node_or_null("PortalMesh") as MeshInstance3D
	if portal_mesh == null:
		return

	var material := portal_mesh.material_override as StandardMaterial3D
	if material == null:
		material = StandardMaterial3D.new()
		material.emission_enabled = true
		material.emission_energy_multiplier = 1.4
		portal_mesh.material_override = material
	material.albedo_color = portal_color
	material.emission = portal_color
