extends Entity

const JUMP_VELOCITY = 4.5

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var health_bar: ProgressBar = $HUD/Control/HealthBar

func _enter_tree() -> void:
	var id := name.to_int()
	set_multiplayer_authority(id if id > 0 else 1)

func _ready() -> void:
	super._ready()
	if is_multiplayer_authority():
		health_bar.max_value = max_health
		health_bar.value = health
		health_changed.connect(_on_health_changed)
	else:
		$HUD.visible = false

func _on_health_changed(new_health: float) -> void:
	health_bar.value = new_health

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector("left", "right", "up", "down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()
