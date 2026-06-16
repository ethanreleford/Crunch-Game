class_name Enemy
extends Entity

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@export var elite_level: int = 0

var _target: Node3D = null

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
	var objectives := get_tree().get_nodes_in_group("objective")
	if objectives.size() > 0:
		_target = objectives[0]

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	if not is_on_floor():
		velocity.y -= gravity * delta
	if _target:
		var to_target := _target.global_position - global_position
		to_target.y = 0.0
		if to_target.length() < 5.0:
			take_damage(max_health)
			return
		var dir := to_target.normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
	move_and_slide()
