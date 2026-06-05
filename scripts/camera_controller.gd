extends SpringArm3D

const MOUSE_SENSITIVITY = 0.003
const PITCH_MIN = -40.0
const PITCH_MAX = 60.0

@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	if not get_parent().is_multiplayer_authority():
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	rotation.x = deg_to_rad(-20.0)
	camera.make_current()

func _unhandled_input(event: InputEvent) -> void:
	if not get_parent().is_multiplayer_authority():
		return
	if event is InputEventMouseMotion:
		get_parent().rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		rotation.x = clamp(rotation.x, deg_to_rad(PITCH_MIN), deg_to_rad(PITCH_MAX))
