extends Node3D

const HOME_SCENE_PATH := "res://home/home.tscn"


@export_group("Idle Camera")
@export var idle_camera_enabled := true
@export_range(0.0, 1.5, 0.01) var idle_camera_horizontal_amplitude := 0.55
@export_range(0.0, 10.0, 0.05) var idle_camera_yaw_degrees := 2.3
@export_range(0.05, 3.0, 0.01) var idle_camera_speed := 0.55

@export_group("Credits Scroll")
@export_range(20.0, 400.0, 5.0) var credits_scroll_step := 75.0
@export_range(1.0, 30.0, 0.5) var credits_scroll_smoothing := 7.5

@onready var _camera: Camera3D = $Camera3D
@onready var _play_button: Button = $CanvasLayer/Root/MenuPanel/MenuPadding/MenuVBox/PlayButton
@onready var _credits_button: Button = $CanvasLayer/Root/MenuPanel/MenuPadding/MenuVBox/CreditsButton
@onready var _credits_panel: PanelContainer = $CanvasLayer/Root/CreditsPanel
@onready var _close_credits_button: Button = $CanvasLayer/Root/CreditsPanel/CreditsPadding/CreditsVBox/CreditsHeader/CloseCreditsButton
@onready var _credits_body: RichTextLabel = $CanvasLayer/Root/CreditsPanel/CreditsPadding/CreditsVBox/CreditsBody

var _idle_camera_time := 0.0
var _camera_base_position := Vector3.ZERO
var _camera_base_rotation := Vector3.ZERO
var _credits_scroll_target := 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_camera_base_position = _camera.position
	_camera_base_rotation = _camera.rotation
	
	_play_button.pressed.connect(_on_play_pressed)
	_credits_button.pressed.connect(_on_credits_pressed)
	_close_credits_button.pressed.connect(_hide_credits)
	_set_credits_visible(false)
	_play_button.grab_focus()
	call_deferred("_sync_credits_scroll_target")


func _process(delta: float) -> void:
	if not idle_camera_enabled:
		_update_credits_scroll(delta)
		return

	_idle_camera_time += delta * idle_camera_speed

	var horizontal_offset := sin(_idle_camera_time) * idle_camera_horizontal_amplitude
	var yaw_offset := sin(_idle_camera_time * 0.9) * deg_to_rad(idle_camera_yaw_degrees)

	_camera.position = _camera_base_position + Vector3(horizontal_offset, 0.0, 0.0)
	_camera.rotation = _camera_base_rotation + Vector3(0.0, yaw_offset, 0.0)
	_update_credits_scroll(delta)


func _input(event: InputEvent) -> void:
	if not _credits_panel.visible:
		return

	if _handle_credits_scroll(event):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not _credits_panel.visible:
		return

	if event.is_action_pressed("ui_cancel"):
		_hide_credits()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_hide_credits()
		get_viewport().set_input_as_handled()


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(HOME_SCENE_PATH)


func _on_credits_pressed() -> void:
	_set_credits_visible(true)
	_sync_credits_scroll_target()
	_close_credits_button.grab_focus()


func _hide_credits() -> void:
	_set_credits_visible(false)
	_play_button.grab_focus()


func _set_credits_visible(visible_state: bool) -> void:
	_credits_panel.visible = visible_state


func _handle_credits_scroll(event: InputEvent) -> bool:
	if not _is_mouse_over_credits_panel():
		return false

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_adjust_credits_scroll(-credits_scroll_step)
			return true
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_adjust_credits_scroll(credits_scroll_step)
			return true

	return false


func _adjust_credits_scroll(amount: float) -> void:
	var scroll_bar := _credits_body.get_v_scroll_bar()
	if scroll_bar == null:
		return

	var effective_max := _get_credits_scroll_max(scroll_bar)
	_credits_scroll_target = clampf(
		scroll_bar.value + amount,
		scroll_bar.min_value,
		effective_max
	)


func _update_credits_scroll(delta: float) -> void:
	if not _credits_panel.visible:
		return

	var scroll_bar := _credits_body.get_v_scroll_bar()
	if scroll_bar == null:
		return

	var effective_max := _get_credits_scroll_max(scroll_bar)
	_credits_scroll_target = clampf(_credits_scroll_target, scroll_bar.min_value, effective_max)
	scroll_bar.value = lerpf(scroll_bar.value, _credits_scroll_target, minf(1.0, delta * credits_scroll_smoothing))

	if absf(scroll_bar.value - _credits_scroll_target) < 0.5:
		scroll_bar.value = _credits_scroll_target


func _sync_credits_scroll_target() -> void:
	var scroll_bar := _credits_body.get_v_scroll_bar()
	if scroll_bar == null:
		return

	_credits_scroll_target = clampf(scroll_bar.value, scroll_bar.min_value, _get_credits_scroll_max(scroll_bar))


func _is_mouse_over_credits_panel() -> bool:
	return _credits_panel.get_global_rect().has_point(_credits_panel.get_global_mouse_position())


func _get_credits_scroll_max(scroll_bar: VScrollBar) -> float:
	return maxf(scroll_bar.min_value, scroll_bar.max_value)
