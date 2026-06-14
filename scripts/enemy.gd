class_name Enemy
extends Entity

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@export var elite_level: int = 0

static var _elite_colors: Array[Color] = [
	Color.WHITE,
	Color(1.0, 0.5, 0.0),  # elite: orange
	Color(0.7, 0.0, 1.0),  # champion: purple
]

func _ready() -> void:
	speed = 4.0 * (1.0 + 0.3 * elite_level)
	max_health = 60.0 * pow(2.5, elite_level)
	super._ready()
	if elite_level > 0:
		var mesh := $MeshInstance3D as MeshInstance3D
		var mat := StandardMaterial3D.new()
		mat.albedo_color = _elite_colors[mini(elite_level, _elite_colors.size() - 1)]
		mesh.material_override = mat

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	move_and_slide()
