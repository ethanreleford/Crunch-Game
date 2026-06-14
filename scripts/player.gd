extends Entity

const JUMP_VELOCITY = 4.5

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var health_bar: ProgressBar = $HUD/Control/HealthBar
@onready var _camera_pivot: Node3D = $CameraPivot
@onready var _mesh: MeshInstance3D = $MeshInstance3D

func _enter_tree() -> void:
	var id := name.to_int()
	set_multiplayer_authority(id if id > 0 else 1)

func _ready() -> void:
	if is_multiplayer_authority():
		var class_data := ClassRegistry.get_class_data(GameState.selected_class_id)
		if class_data:
			speed = class_data.speed
			max_health = class_data.max_health
		else:
			speed = 5.0
			max_health = 100.0
	else:
		var peer_id := name.to_int()
		var class_id: String = GameState.player_class_ids.get(peer_id, "")
		var class_data := ClassRegistry.get_class_data(class_id)
		if class_data:
			speed = class_data.speed
			max_health = class_data.max_health
		else:
			speed = 5.0
			max_health = 100.0
	super._ready()
	if is_multiplayer_authority():
		health_bar.max_value = health_component.max_health
		health_bar.value = health_component.health
		health_component.health_changed.connect(_on_health_changed)
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
	var dir_3d := _camera_pivot.global_transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)
	var direction := Vector3(dir_3d.x, 0.0, dir_3d.z).normalized()

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	_mesh.rotation.y = _camera_pivot.rotation.y
	move_and_slide()
