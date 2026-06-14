extends CanvasLayer

@onready var _volume_slider: HSlider = $Panel/Margin/VBox/VolumeRow/VolumeSlider
@onready var _fullscreen_check: CheckButton = $Panel/Margin/VBox/FullscreenRow/FullscreenCheck
@onready var _vsync_check: CheckButton = $Panel/Margin/VBox/VSyncRow/VSyncCheck
@onready var _sens_slider: HSlider = $Panel/Margin/VBox/SensRow/SensSlider

var _syncing := false

func _ready() -> void:
	SettingsManager.load_and_apply()
	_sync_ui()
	hide()

func _sync_ui() -> void:
	_syncing = true
	_volume_slider.value = SettingsManager.master_volume
	_fullscreen_check.button_pressed = SettingsManager.fullscreen
	_vsync_check.button_pressed = SettingsManager.vsync
	_sens_slider.value = SettingsManager.mouse_sensitivity
	_syncing = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		if visible:
			_close()
		else:
			_open()
		get_viewport().set_input_as_handled()

func _open() -> void:
	_sync_ui()
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _close() -> void:
	hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_volume_changed(value: float) -> void:
	if _syncing:
		return
	SettingsManager.master_volume = value
	SettingsManager.apply_all()
	SettingsManager.save()

func _on_fullscreen_toggled(toggled_on: bool) -> void:
	if _syncing:
		return
	SettingsManager.fullscreen = toggled_on
	SettingsManager.apply_all()
	SettingsManager.save()

func _on_vsync_toggled(toggled_on: bool) -> void:
	if _syncing:
		return
	SettingsManager.vsync = toggled_on
	SettingsManager.apply_all()
	SettingsManager.save()

func _on_sensitivity_changed(value: float) -> void:
	if _syncing:
		return
	SettingsManager.mouse_sensitivity = value
	SettingsManager.save()

func _on_resume_pressed() -> void:
	_close()

func _on_quit_to_menu_pressed() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://Scenes/main.tscn")
