extends CanvasLayer

@onready var _volume_slider: HSlider = $Panel/Margin/VBox/VolumeRow/VolumeSlider
@onready var _fullscreen_check: CheckButton = $Panel/Margin/VBox/FullscreenRow/FullscreenCheck
@onready var _vsync_check: CheckButton = $Panel/Margin/VBox/VSyncRow/VSyncCheck
@onready var _sens_slider: HSlider = $Panel/Margin/VBox/SensRow/SensSlider

var _syncing := false

func _ready() -> void:
	_sync_ui()

func open() -> void:
	_sync_ui()
	show()

func _sync_ui() -> void:
	_syncing = true
	_volume_slider.value = SettingsManager.master_volume
	_fullscreen_check.button_pressed = SettingsManager.fullscreen
	_vsync_check.button_pressed = SettingsManager.vsync
	_sens_slider.value = SettingsManager.mouse_sensitivity
	_syncing = false

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

func _on_close_pressed() -> void:
	hide()
