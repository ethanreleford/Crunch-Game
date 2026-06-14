extends SpringArm3D

@export var zoom_speed: float = 1.0
@export var zoom_min: float = 1.5
@export var zoom_max: float = 8.0
@export var pitch_min: float = -75.0
@export var pitch_max: float = 75.0
@export var camera_radius: float = 0.2

@onready var _pivot: Node3D = get_parent()
@onready var _player: CharacterBody3D = _pivot.get_parent()
@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	var sphere := SphereShape3D.new()
	sphere.radius = camera_radius
	shape = sphere
	margin = camera_radius
	add_excluded_object(_player.get_rid())
	if not _player.is_multiplayer_authority():
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	rotation.x = deg_to_rad(-20.0)
	camera.make_current()

func _input(event: InputEvent) -> void:
	if not _player.is_multiplayer_authority():
		return

	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return

	if event is InputEventMouseMotion:
		_pivot.rotate_y(-event.relative.x * SettingsManager.mouse_sensitivity)
		rotate_x(-event.relative.y * SettingsManager.mouse_sensitivity)
		rotation.x = clamp(rotation.x, deg_to_rad(pitch_min), deg_to_rad(pitch_max))
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			spring_length = clamp(spring_length - zoom_speed, zoom_min, zoom_max)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			spring_length = clamp(spring_length + zoom_speed, zoom_min, zoom_max)
