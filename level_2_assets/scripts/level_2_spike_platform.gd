@tool
extends Node3D


@export_range(0.5, 2.5, 0.1) var spike_spacing := 1.2:
	set(value):
		spike_spacing = maxf(value, 0.5)
		if is_inside_tree():
			_layout_spikes()


func _ready() -> void:
	_layout_spikes()

	if Engine.is_editor_hint():
		return

	var hazard_area := get_node_or_null("HazardArea") as Area3D
	if hazard_area != null and not hazard_area.body_entered.is_connected(_on_hazard_body_entered):
		hazard_area.body_entered.connect(_on_hazard_body_entered)


func _on_hazard_body_entered(body: Node3D) -> void:
	var level_root := _find_level_root()
	if level_root != null:
		level_root.call("respawn_body_from_kill_plane", body)


func _find_level_root() -> Node:
	var current: Node = self
	while current != null:
		if current.has_method("respawn_body_from_kill_plane"):
			return current
		current = current.get_parent()
	return null


func _layout_spikes() -> void:
	var spike_root := get_node_or_null("SpikeRoot") as Node3D
	if spike_root == null:
		return

	var hazard_shape_node := get_node_or_null("HazardArea/CollisionShape3D") as CollisionShape3D
	var hazard_shape := hazard_shape_node.shape as BoxShape3D if hazard_shape_node != null else null
	if hazard_shape == null:
		return

	var platform_shape_node := get_node_or_null("PlatformBody/CollisionShape3D") as CollisionShape3D
	var platform_shape := platform_shape_node.shape as BoxShape3D if platform_shape_node != null else null
	var platform_top := 0.5
	if platform_shape != null:
		platform_top = platform_shape.size.y * 0.5
	spike_root.position = Vector3(0.0, platform_top, 0.0)

	var template := _ensure_template_spike(spike_root)
	if template == null:
		return

	var hazard_size := hazard_shape.size
	var columns := maxi(1, int(round(hazard_size.x / spike_spacing)))
	var rows := maxi(1, int(round(hazard_size.z / spike_spacing)))
	var desired_count := columns * rows

	while spike_root.get_child_count() < desired_count:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "Spike_%d" % spike_root.get_child_count()
		mesh_instance.mesh = template.mesh
		mesh_instance.material_override = template.material_override
		spike_root.add_child(mesh_instance)
		if Engine.is_editor_hint():
			mesh_instance.owner = get_tree().edited_scene_root

	while spike_root.get_child_count() > desired_count:
		var child := spike_root.get_child(spike_root.get_child_count() - 1)
		spike_root.remove_child(child)
		child.queue_free()

	var x_step := hazard_size.x / float(columns)
	var z_step := hazard_size.z / float(rows)
	var start_x := -hazard_size.x * 0.5 + x_step * 0.5
	var start_z := -hazard_size.z * 0.5 + z_step * 0.5
	var spike_index := 0
	for row in range(rows):
		for column in range(columns):
			var spike := spike_root.get_child(spike_index) as MeshInstance3D
			if spike == null:
				spike_index += 1
				continue
			spike.position = Vector3(start_x + x_step * column, template.position.y, start_z + z_step * row)
			spike_index += 1


func _ensure_template_spike(spike_root: Node3D) -> MeshInstance3D:
	for child in spike_root.get_children():
		var spike := child as MeshInstance3D
		if spike != null:
			return spike

	var fallback_spike := MeshInstance3D.new()
	fallback_spike.name = "Spike_0"
	var spike_mesh := CylinderMesh.new()
	spike_mesh.top_radius = 0.0
	spike_mesh.bottom_radius = 0.28
	spike_mesh.height = 0.8
	spike_mesh.radial_segments = 6
	fallback_spike.mesh = spike_mesh
	var spike_material := StandardMaterial3D.new()
	spike_material.albedo_color = Color(0.12, 0.12, 0.14, 1.0)
	spike_material.roughness = 0.92
	fallback_spike.material_override = spike_material
	fallback_spike.position = Vector3(0.0, 0.4, 0.0)
	spike_root.add_child(fallback_spike)
	if Engine.is_editor_hint():
		fallback_spike.owner = get_tree().edited_scene_root
	return fallback_spike
