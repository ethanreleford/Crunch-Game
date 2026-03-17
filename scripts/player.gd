extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _enter_tree():
	set_multiplayer_authority(name.to_int())

func _physics_process(delta: float) -> void:
	if !is_multiplayer_authority():
		print(is_multiplayer_authority())
		return
	print(is_multiplayer_authority())
	# 2. Handle Gravity
	#if not is_on_floor():
	#	velocity.y -= gravity * delta

	# 3. Handle Jump (Optional)
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# 4. Get Input and Calculate Direction
	# Note: get_vector returns a Vector2, which we map to X and Z in 3D space.
	var input_dir = Input.get_vector("left", "right", "up", "down")
	
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
		print(velocity)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	# 5. Apply Movement
	move_and_slide()
