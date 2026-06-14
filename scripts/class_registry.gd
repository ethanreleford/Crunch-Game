class_name ClassRegistry

static var _classes: Dictionary = {}
static var _loaded: bool = false

static func get_class_data(class_id: String) -> PlayerClassData:
	_ensure_loaded()
	return _classes.get(class_id, null)

static func get_all_base_classes() -> Array[PlayerClassData]:
	_ensure_loaded()
	var result: Array[PlayerClassData] = []
	for c: PlayerClassData in _classes.values():
		if c.is_base_class():
			result.append(c)
	return result

static func get_subclasses(base_class_id: String) -> Array[PlayerClassData]:
	_ensure_loaded()
	var result: Array[PlayerClassData] = []
	for c: PlayerClassData in _classes.values():
		if c.base_class_id == base_class_id:
			result.append(c)
	return result

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_scan_directory("res://data/classes/")

static func _scan_directory(path: String) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full_path := path + entry
		if dir.current_is_dir():
			_scan_directory(full_path + "/")
		elif entry.ends_with(".tres") or entry.ends_with(".res"):
			var res := load(full_path)
			if res is PlayerClassData and res.class_id != "":
				_classes[res.class_id] = res
		entry = dir.get_next()
	dir.list_dir_end()
