class_name SettingsManager

const _SAVE_PATH := "user://settings.cfg"

static var master_volume: float = 1.0
static var fullscreen: bool = false
static var vsync: bool = true
static var mouse_sensitivity: float = 0.003

static func load_and_apply() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_SAVE_PATH) == OK:
		master_volume = cfg.get_value("audio", "master_volume", 1.0)
		fullscreen = cfg.get_value("video", "fullscreen", false)
		vsync = cfg.get_value("video", "vsync", true)
		mouse_sensitivity = cfg.get_value("controls", "mouse_sensitivity", 0.003)
	apply_all()

static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "vsync", vsync)
	cfg.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	cfg.save(_SAVE_PATH)

static func apply_all() -> void:
	var db := linear_to_db(master_volume) if master_volume > 0.0 else -80.0
	AudioServer.set_bus_volume_db(0, db)
	AudioServer.set_bus_mute(0, master_volume == 0.0)
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	)
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	)
