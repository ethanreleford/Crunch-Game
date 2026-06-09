class_name Enemy
extends Entity

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	speed = 4.0
	max_health = 60.0
	super._ready()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	move_and_slide()
