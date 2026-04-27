extends Node3D

const INTRO_TEXT := "I need to get ready for university.\nFirst things first: take a shower, make the bed, get dressed, grab breakfast from the fridge, drink coffee, and take my laptop.\nThen I can leave the house."
const LEVEL_COMPLETE_TEXT := "Level Complete"
const NEXT_LEVEL_PATH := "res://level_2.tscn"
const LEVEL_TRANSITION_DELAY := 2.0

const QUESTS := [
	{
		"title": "Morning Routine",
		"objectives": [
			{
				"id": "take_shower",
				"label": "Take a shower",
				"prompt": "Press E to take a shower",
				"node_path": "furniture/shower",
				"radius": 1.5,
			},
			{
				"id": "make_bed",
				"label": "Make the bed",
				"prompt": "Press E to make the bed",
				"node_path": "furniture/bed",
				"radius": 2.0,
			},
			{
				"id": "get_dressed",
				"label": "Get dressed",
				"prompt": "Press E to get dressed",
				"node_path": "furniture/bookcase",
				"radius": 2.0,
			},
			{
				"id": "eat_breakfast",
				"label": "Eat breakfast",
				"prompt": "Press E to eat breakfast",
				"node_path": "furniture/fridge",
				"radius": 2.0,
			},
			{
				"id": "drink_coffee",
				"label": "Drink coffee",
				"prompt": "Press E to drink coffee",
				"node_path": "furniture/CoffeeMachine",
				"radius": 2.0,
			},
			{
				"id": "take_laptop",
				"label": "Take the laptop",
				"prompt": "Press E to take the laptop",
				"node_path": "furniture/laptop",
				"radius": 2.0,
			},
		],
	},
	{
		"title": "Leave the House",
		"objectives": [
			{
				"id": "leave_house",
				"label": "Leave the house",
				"prompt": "Press E to leave the house",
				"node_path": "walls/doorway_wood",
				"radius": 2.0,
			},
		],
	},
]

var _objective_nodes: Dictionary = {}
var _completed_objectives: Dictionary = {}
var _current_quest_index := 0
var _current_interactable_id := ""
var _dialogue_active := false
var _is_transitioning := false

var _player: CharacterBody3D
var _quest_panel: PanelContainer
var _quest_title_label: Label
var _quest_objectives_label: Label
var _prompt_panel: PanelContainer
var _prompt_label: Label
var _dialogue_overlay: ColorRect
var _status_panel: PanelContainer
var _status_label: Label
var _status_timer: Timer
var _level_transition_timer: Timer


func _ready():
	_player = get_node_or_null("Player3D")
	_ensure_input_action("interact", KEY_E)
	_ensure_input_action("dialog_skip", KEY_Q)
	_cache_objective_nodes()
	_build_ui()
	_update_quest_ui()
	_show_intro_dialogue()


func _process(_delta: float):
	if _dialogue_active or _is_transitioning or _current_quest_index >= QUESTS.size():
		_prompt_panel.visible = false
		return

	var objective := _find_nearest_objective()
	if objective.is_empty():
		_current_interactable_id = ""
		_prompt_panel.visible = false
		return

	_current_interactable_id = String(objective["id"])
	_prompt_label.text = String(objective["prompt"])
	_prompt_panel.visible = true


func _unhandled_input(event: InputEvent):
	if _dialogue_active and event.is_action_pressed("dialog_skip"):
		_hide_intro_dialogue()
		get_viewport().set_input_as_handled()
		return

	if _dialogue_active or _is_transitioning:
		return

	if event.is_action_pressed("interact") and _current_interactable_id != "":
		_complete_objective(_current_interactable_id)
		get_viewport().set_input_as_handled()


func _complete_objective(objective_id: String):
	if _completed_objectives.has(objective_id):
		return

	_completed_objectives[objective_id] = true
	_current_interactable_id = ""
	var status_text := "Objective complete: %s" % _objective_label(objective_id)
	var should_transition := false

	if _is_current_quest_complete():
		should_transition = _current_quest_index == QUESTS.size() - 1
		status_text = _advance_quest()

	_update_quest_ui()
	_show_status(status_text)

	if should_transition:
		_begin_level_transition()


func _advance_quest() -> String:
	_current_quest_index += 1
	if _current_quest_index >= QUESTS.size():
		return LEVEL_COMPLETE_TEXT

	return "New quest: %s" % String(QUESTS[_current_quest_index]["title"])


func _is_current_quest_complete() -> bool:
	for objective in _current_objectives():
		if not _completed_objectives.has(String(objective["id"])):
			return false
	return true


func _current_objectives() -> Array:
	if _current_quest_index >= QUESTS.size():
		return []
	return QUESTS[_current_quest_index]["objectives"]


func _objective_label(objective_id: String) -> String:
	for quest in QUESTS:
		for objective in quest["objectives"]:
			if String(objective["id"]) == objective_id:
				return String(objective["label"])
	return objective_id


func _find_nearest_objective() -> Dictionary:
	var closest_objective := {}
	var closest_distance := INF
	var player_position := _player.global_position

	for objective in _current_objectives():
		var objective_id := String(objective["id"])
		if _completed_objectives.has(objective_id):
			continue

		var target_node: Node3D = _objective_nodes.get(objective_id)
		if target_node == null:
			continue

		var offset := target_node.global_position - player_position
		offset.y = 0.0
		var distance := offset.length()
		if distance > float(objective["radius"]):
			continue

		if distance < closest_distance:
			closest_distance = distance
			closest_objective = objective

	return closest_objective


func _cache_objective_nodes():
	for quest in QUESTS:
		for objective in quest["objectives"]:
			var objective_id := String(objective["id"])
			var node_path := NodePath(String(objective["node_path"]))
			var node := get_node_or_null(node_path)
			if node is Node3D:
				_objective_nodes[objective_id] = node
			else:
				push_warning("Quest target is missing or not Node3D: %s" % objective_id)


func _show_intro_dialogue():
	_dialogue_active = true
	_dialogue_overlay.visible = true
	_quest_panel.visible = false
	_prompt_panel.visible = false
	_set_player_controls_locked(true)


func _hide_intro_dialogue():
	_dialogue_active = false
	_dialogue_overlay.visible = false
	_quest_panel.visible = true
	_set_player_controls_locked(false)
	_update_quest_ui()


func _set_player_controls_locked(is_locked: bool):
	if _player.has_method("set_controls_locked"):
		_player.call("set_controls_locked", is_locked)


func _update_quest_ui():
	if _current_quest_index >= QUESTS.size():
		_quest_title_label.text = "Home Level Complete"
		_quest_objectives_label.text = "[x] Leave the house\nLoading Level 2..."
		return

	var current_quest: Dictionary = QUESTS[_current_quest_index]
	_quest_title_label.text = String(current_quest["title"])

	var lines: PackedStringArray = []
	for objective in current_quest["objectives"]:
		var objective_id := String(objective["id"])
		var prefix := "[x]" if _completed_objectives.has(objective_id) else "[ ]"
		lines.append("%s %s" % [prefix, String(objective["label"])])

	_quest_objectives_label.text = "\n".join(lines)


func _show_status(text: String):
	_status_label.text = text
	_status_panel.visible = true
	_status_timer.start()


func _on_status_timer_timeout():
	_status_panel.visible = false


func _begin_level_transition():
	if _is_transitioning:
		return

	_is_transitioning = true
	_prompt_panel.visible = false
	_quest_panel.visible = false
	_set_player_controls_locked(true)
	_status_timer.stop()
	_status_label.text = LEVEL_COMPLETE_TEXT
	_status_panel.visible = true
	_level_transition_timer.start(LEVEL_TRANSITION_DELAY)


func _on_level_transition_timeout():
	var change_error := get_tree().change_scene_to_file(NEXT_LEVEL_PATH)
	if change_error != OK:
		_is_transitioning = false
		_quest_panel.visible = true
		_set_player_controls_locked(false)
		push_error("Failed to load next level: %s" % NEXT_LEVEL_PATH)


func _ensure_input_action(action_name: StringName, keycode: Key):
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	for existing_event in InputMap.action_get_events(action_name):
		InputMap.action_erase_event(action_name, existing_event)

	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action_name, event)


func _build_ui():
	var canvas_layer := CanvasLayer.new()
	canvas_layer.layer = 10
	add_child(canvas_layer)

	_quest_panel = PanelContainer.new()
	_quest_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_quest_panel.position = Vector2(24.0, 24.0)
	_quest_panel.custom_minimum_size = Vector2(320.0, 0.0)
	_quest_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.1, 0.13, 0.88)))
	canvas_layer.add_child(_quest_panel)

	var quest_margin := MarginContainer.new()
	quest_margin.add_theme_constant_override("margin_left", 16)
	quest_margin.add_theme_constant_override("margin_top", 14)
	quest_margin.add_theme_constant_override("margin_right", 16)
	quest_margin.add_theme_constant_override("margin_bottom", 14)
	_quest_panel.add_child(quest_margin)

	var quest_vbox := VBoxContainer.new()
	quest_vbox.add_theme_constant_override("separation", 8)
	quest_margin.add_child(quest_vbox)

	_quest_title_label = Label.new()
	_quest_title_label.add_theme_color_override("font_color", Color(0.98, 0.98, 0.98))
	_quest_title_label.add_theme_font_size_override("font_size", 22)
	quest_vbox.add_child(_quest_title_label)

	_quest_objectives_label = Label.new()
	_quest_objectives_label.add_theme_color_override("font_color", Color(0.88, 0.92, 0.96))
	_quest_objectives_label.add_theme_font_size_override("font_size", 18)
	_quest_objectives_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quest_vbox.add_child(_quest_objectives_label)

	_prompt_panel = PanelContainer.new()
	_prompt_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_prompt_panel.offset_left = 260.0
	_prompt_panel.offset_right = -260.0
	_prompt_panel.offset_bottom = -32.0
	_prompt_panel.offset_top = -88.0
	_prompt_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.07, 0.09, 0.11, 0.92)))
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
	_prompt_label.add_theme_color_override("font_color", Color(0.98, 0.98, 0.98))
	_prompt_label.add_theme_font_size_override("font_size", 20)
	prompt_margin.add_child(_prompt_label)

	_dialogue_overlay = ColorRect.new()
	_dialogue_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dialogue_overlay.color = Color(0.0, 0.0, 0.0, 0.55)
	canvas_layer.add_child(_dialogue_overlay)

	var dialogue_panel := PanelContainer.new()
	dialogue_panel.set_anchors_preset(Control.PRESET_CENTER)
	dialogue_panel.custom_minimum_size = Vector2(680.0, 0.0)
	dialogue_panel.position = Vector2(-340.0, -120.0)
	dialogue_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.09, 0.11, 0.14, 0.96)))
	_dialogue_overlay.add_child(dialogue_panel)

	var dialogue_margin := MarginContainer.new()
	dialogue_margin.add_theme_constant_override("margin_left", 22)
	dialogue_margin.add_theme_constant_override("margin_top", 20)
	dialogue_margin.add_theme_constant_override("margin_right", 22)
	dialogue_margin.add_theme_constant_override("margin_bottom", 18)
	dialogue_panel.add_child(dialogue_margin)

	var dialogue_vbox := VBoxContainer.new()
	dialogue_vbox.add_theme_constant_override("separation", 12)
	dialogue_margin.add_child(dialogue_vbox)

	var dialogue_title := Label.new()
	dialogue_title.text = "Inner Monologue"
	dialogue_title.add_theme_color_override("font_color", Color(0.99, 0.99, 0.99))
	dialogue_title.add_theme_font_size_override("font_size", 26)
	dialogue_vbox.add_child(dialogue_title)

	var dialogue_text := Label.new()
	dialogue_text.text = INTRO_TEXT
	dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_text.add_theme_color_override("font_color", Color(0.9, 0.93, 0.97))
	dialogue_text.add_theme_font_size_override("font_size", 22)
	dialogue_vbox.add_child(dialogue_text)

	var dialogue_hint := Label.new()
	dialogue_hint.text = "Press Q to skip"
	dialogue_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dialogue_hint.add_theme_color_override("font_color", Color(0.76, 0.83, 0.92))
	dialogue_hint.add_theme_font_size_override("font_size", 18)
	dialogue_vbox.add_child(dialogue_hint)

	_status_panel = PanelContainer.new()
	_status_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_status_panel.offset_left = 360.0
	_status_panel.offset_right = -360.0
	_status_panel.offset_top = 24.0
	_status_panel.offset_bottom = 82.0
	_status_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.12, 0.17, 0.22, 0.92)))
	_status_panel.visible = false
	canvas_layer.add_child(_status_panel)

	var status_margin := MarginContainer.new()
	status_margin.add_theme_constant_override("margin_left", 16)
	status_margin.add_theme_constant_override("margin_top", 10)
	status_margin.add_theme_constant_override("margin_right", 16)
	status_margin.add_theme_constant_override("margin_bottom", 10)
	_status_panel.add_child(status_margin)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.add_theme_color_override("font_color", Color(0.99, 0.99, 0.99))
	_status_label.add_theme_font_size_override("font_size", 20)
	status_margin.add_child(_status_label)

	_status_timer = Timer.new()
	_status_timer.one_shot = true
	_status_timer.wait_time = 2.0
	_status_timer.timeout.connect(_on_status_timer_timeout)
	add_child(_status_timer)

	_level_transition_timer = Timer.new()
	_level_transition_timer.one_shot = true
	_level_transition_timer.timeout.connect(_on_level_transition_timeout)
	add_child(_level_transition_timer)


func _panel_style(background: Color) -> StyleBoxFlat:
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
	style.border_color = Color(0.33, 0.43, 0.54, 0.8)
	return style
