extends Node3D


const CHECKPOINT_GROUP := "level_2_checkpoint"
const FINISH_GROUP := "level_2_finish"
const TUTORIAL_TRIGGER_GROUP := "level_2_tutorial_trigger"


@export_node_path("CharacterBody3D") var player_path: NodePath = ^"Player3D"
@export_file("*.tscn") var next_scene_path := ""
@export var require_interact_for_finish := true
@export var finish_delay := 1.75
@export var checkpoint_message_duration := 1.35
@export var finish_prompt_text := "Press E to finish the level"
@export var finish_message_text := "Level Complete"
@export var checkpoint_message_text := "Checkpoint reached"

var _player: CharacterBody3D
var _spawn_position := Vector3.ZERO
var _spawn_rotation := Vector3.ZERO
var _current_respawn_position := Vector3.ZERO
var _current_respawn_rotation := Vector3.ZERO
var _active_checkpoint: Node
var _finish_target: Node
var _is_player_near_finish := false
var _is_finishing := false

var _finish_timer: Timer
var _message_timer: Timer
var _tutorial_timer: Timer
var _prompt_panel: PanelContainer
var _prompt_label: Label
var _message_panel: PanelContainer
var _message_label: Label
var _tutorial_panel: PanelContainer
var _tutorial_title_label: Label
var _tutorial_body_label: Label
var _shown_tutorial_hints: Dictionary = {}


func _ready() -> void:
	_player = get_node_or_null(player_path) as CharacterBody3D
	

	_spawn_position = _player.global_position
	_spawn_rotation = _player.global_rotation
	_current_respawn_position = _spawn_position
	_current_respawn_rotation = _spawn_rotation

	_build_ui()
	_connect_level_nodes()
	_reset_checkpoint_progress()


func _unhandled_input(event: InputEvent) -> void:
	if _is_finishing or not require_interact_for_finish:
		return

	if _is_player_near_finish and event.is_action_pressed("interact"):
		_complete_level()
		get_viewport().set_input_as_handled()


func respawn_body_from_kill_plane(body: Node3D) -> void:
	if body != _player or _is_finishing:
		return

	_respawn_player(_current_respawn_position, _current_respawn_rotation)


func _connect_level_nodes() -> void:
	var checkpoint_callback := Callable(self, "_on_checkpoint_reached")
	for node in get_tree().get_nodes_in_group(CHECKPOINT_GROUP):
		if not is_ancestor_of(node):
			continue
		if not node.is_connected("checkpoint_reached", checkpoint_callback):
			node.connect("checkpoint_reached", checkpoint_callback)

	var finish_enter_callback := Callable(self, "_on_finish_player_entered")
	var finish_exit_callback := Callable(self, "_on_finish_player_exited")
	for node in get_tree().get_nodes_in_group(FINISH_GROUP):
		if not is_ancestor_of(node):
			continue
		if not node.is_connected("player_entered", finish_enter_callback):
			node.connect("player_entered", finish_enter_callback)
		if not node.is_connected("player_exited", finish_exit_callback):
			node.connect("player_exited", finish_exit_callback)

	var tutorial_callback := Callable(self, "_on_tutorial_requested")
	for node in get_tree().get_nodes_in_group(TUTORIAL_TRIGGER_GROUP):
		if not is_ancestor_of(node):
			continue
		if not node.is_connected("tutorial_requested", tutorial_callback):
			node.connect("tutorial_requested", tutorial_callback)


func _reset_checkpoint_progress() -> void:
	_active_checkpoint = null
	_current_respawn_position = _spawn_position
	_current_respawn_rotation = _spawn_rotation

	for node in get_tree().get_nodes_in_group(CHECKPOINT_GROUP):
		if is_ancestor_of(node) and node.has_method("set_active"):
			node.call("set_active", false)


func _activate_checkpoint(checkpoint: Node) -> void:
	if checkpoint == null:
		return

	if _active_checkpoint != null and _active_checkpoint != checkpoint and _active_checkpoint.has_method("set_active"):
		_active_checkpoint.call("set_active", false)

	_active_checkpoint = checkpoint

	if checkpoint.has_method("set_active"):
		checkpoint.call("set_active", true)
	if checkpoint.has_method("get_respawn_position"):
		_current_respawn_position = checkpoint.call("get_respawn_position")
	if checkpoint.has_method("get_respawn_rotation"):
		_current_respawn_rotation = checkpoint.call("get_respawn_rotation")

	_show_message(checkpoint_message_text, checkpoint_message_duration)
	if checkpoint.has_method("get_tutorial_hint_data"):
		_show_tutorial_hint_data(checkpoint.call("get_tutorial_hint_data"))


func _complete_level() -> void:
	if _is_finishing:
		return

	_is_finishing = true
	_is_player_near_finish = false
	_finish_target = null
	_prompt_panel.visible = false
	_tutorial_panel.visible = false
	_tutorial_timer.stop()
	_message_timer.stop()
	_message_label.text = finish_message_text
	_message_panel.visible = true

	if _player.has_method("set_controls_locked"):
		_player.call("set_controls_locked", true)

	_finish_timer.start(finish_delay)


func _respawn_player(position: Vector3, rotation_value: Vector3) -> void:
	_is_player_near_finish = false
	_finish_target = null
	_prompt_panel.visible = false
	_tutorial_panel.visible = false

	if _player.has_method("set_controls_locked"):
		_player.call("set_controls_locked", false)

	_player.velocity = Vector3.ZERO
	_player.global_position = position
	_player.global_rotation = rotation_value


func _show_message(text: String, duration: float) -> void:
	if _is_finishing:
		return

	_message_label.text = text
	_message_panel.visible = true
	_message_timer.start(duration)


func _on_checkpoint_reached(checkpoint: Node3D, body: Node3D) -> void:
	if body != _player:
		return

	if checkpoint == _active_checkpoint:
		return

	_activate_checkpoint(checkpoint)


func _on_finish_player_entered(finish: Node3D, body: Node3D) -> void:
	if body != _player or _is_finishing:
		return

	_finish_target = finish
	_is_player_near_finish = true

	if require_interact_for_finish:
		_prompt_label.text = finish_prompt_text
		_prompt_panel.visible = true
	else:
		_complete_level()


func _on_finish_player_exited(finish: Node3D, body: Node3D) -> void:
	if body != _player:
		return

	if finish == _finish_target:
		_finish_target = null
	_is_player_near_finish = false
	_prompt_panel.visible = false


func _on_finish_timer_timeout() -> void:
	_message_panel.visible = false
	_is_finishing = false

	if next_scene_path != "":
		get_tree().change_scene_to_file(next_scene_path)
		return

	_reset_checkpoint_progress()
	_respawn_player(_spawn_position, _spawn_rotation)


func _on_message_timer_timeout() -> void:
	if _is_finishing:
		return

	_message_panel.visible = false


func _on_tutorial_requested(trigger: Node3D, body: Node3D) -> void:
	if body != _player or _is_finishing:
		return

	if trigger == null or not trigger.has_method("get_tutorial_hint_data"):
		return

	_show_tutorial_hint_data(trigger.call("get_tutorial_hint_data"))


func _show_tutorial_hint_data(hint_data: Dictionary) -> void:
	if hint_data.is_empty():
		return

	var title := String(hint_data.get("title", "")).strip_edges()
	var body := String(hint_data.get("body", "")).strip_edges()
	if title == "" and body == "":
		return

	var hint_id := _resolve_tutorial_hint_id(hint_data, title, body)
	var show_once := bool(hint_data.get("show_once", true))
	if show_once and _shown_tutorial_hints.has(hint_id):
		return

	if show_once:
		_shown_tutorial_hints[hint_id] = true

	var duration := maxf(float(hint_data.get("duration", 5.0)), 0.5)
	_tutorial_title_label.text = title
	_tutorial_title_label.visible = title != ""
	_tutorial_body_label.text = body
	_tutorial_panel.visible = true
	_tutorial_timer.start(duration)


func _resolve_tutorial_hint_id(hint_data: Dictionary, title: String, body: String) -> String:
	var explicit_id := String(hint_data.get("hint_id", "")).strip_edges()
	if explicit_id != "":
		return explicit_id

	return "%s|%s" % [title, body]


func _on_tutorial_timer_timeout() -> void:
	_tutorial_panel.visible = false


func _build_ui() -> void:
	var canvas_layer := CanvasLayer.new()
	canvas_layer.layer = 15
	add_child(canvas_layer)

	_prompt_panel = PanelContainer.new()
	_prompt_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_prompt_panel.offset_left = 300.0
	_prompt_panel.offset_right = -300.0
	_prompt_panel.offset_top = -90.0
	_prompt_panel.offset_bottom = -28.0
	_prompt_panel.add_theme_stylebox_override("panel", _create_panel_style(Color(0.08, 0.1, 0.13, 0.9)))
	_prompt_panel.visible = false
	canvas_layer.add_child(_prompt_panel)

	var prompt_margin := MarginContainer.new()
	prompt_margin.add_theme_constant_override("margin_left", 16)
	prompt_margin.add_theme_constant_override("margin_top", 12)
	prompt_margin.add_theme_constant_override("margin_right", 16)
	prompt_margin.add_theme_constant_override("margin_bottom", 12)
	_prompt_panel.add_child(prompt_margin)

	_prompt_label = Label.new()
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 20)
	_prompt_label.add_theme_color_override("font_color", Color(0.97, 0.97, 0.97))
	prompt_margin.add_child(_prompt_label)

	_message_panel = PanelContainer.new()
	_message_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_message_panel.offset_left = 360.0
	_message_panel.offset_right = -360.0
	_message_panel.offset_top = 28.0
	_message_panel.offset_bottom = 90.0
	_message_panel.add_theme_stylebox_override("panel", _create_panel_style(Color(0.11, 0.16, 0.2, 0.94)))
	_message_panel.visible = false
	canvas_layer.add_child(_message_panel)

	var message_margin := MarginContainer.new()
	message_margin.add_theme_constant_override("margin_left", 18)
	message_margin.add_theme_constant_override("margin_top", 12)
	message_margin.add_theme_constant_override("margin_right", 18)
	message_margin.add_theme_constant_override("margin_bottom", 12)
	_message_panel.add_child(message_margin)

	_message_label = Label.new()
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message_label.add_theme_font_size_override("font_size", 24)
	_message_label.add_theme_color_override("font_color", Color(0.99, 0.99, 0.99))
	message_margin.add_child(_message_label)

	_tutorial_panel = PanelContainer.new()
	_tutorial_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_tutorial_panel.offset_left = -392.0
	_tutorial_panel.offset_right = -24.0
	_tutorial_panel.offset_top = 128.0
	_tutorial_panel.offset_bottom = 286.0
	_tutorial_panel.add_theme_stylebox_override("panel", _create_panel_style(Color(0.1, 0.13, 0.17, 0.94)))
	_tutorial_panel.visible = false
	canvas_layer.add_child(_tutorial_panel)

	var tutorial_margin := MarginContainer.new()
	tutorial_margin.add_theme_constant_override("margin_left", 18)
	tutorial_margin.add_theme_constant_override("margin_top", 16)
	tutorial_margin.add_theme_constant_override("margin_right", 18)
	tutorial_margin.add_theme_constant_override("margin_bottom", 16)
	_tutorial_panel.add_child(tutorial_margin)

	var tutorial_vbox := VBoxContainer.new()
	tutorial_vbox.add_theme_constant_override("separation", 8)
	tutorial_margin.add_child(tutorial_vbox)

	_tutorial_title_label = Label.new()
	_tutorial_title_label.add_theme_font_size_override("font_size", 22)
	_tutorial_title_label.add_theme_color_override("font_color", Color(0.99, 0.99, 0.99))
	tutorial_vbox.add_child(_tutorial_title_label)

	_tutorial_body_label = Label.new()
	_tutorial_body_label.add_theme_font_size_override("font_size", 18)
	_tutorial_body_label.add_theme_color_override("font_color", Color(0.87, 0.92, 0.97))
	_tutorial_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial_vbox.add_child(_tutorial_body_label)

	_finish_timer = Timer.new()
	_finish_timer.one_shot = true
	_finish_timer.timeout.connect(_on_finish_timer_timeout)
	add_child(_finish_timer)

	_message_timer = Timer.new()
	_message_timer.one_shot = true
	_message_timer.timeout.connect(_on_message_timer_timeout)
	add_child(_message_timer)

	_tutorial_timer = Timer.new()
	_tutorial_timer.one_shot = true
	_tutorial_timer.timeout.connect(_on_tutorial_timer_timeout)
	add_child(_tutorial_timer)


func _create_panel_style(background: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.31, 0.39, 0.48, 0.8)
	return style
