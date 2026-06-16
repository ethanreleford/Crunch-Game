class_name EnemySpawner
extends Node3D

signal enemy_spawned
signal enemy_died

var _mp_spawner: MultiplayerSpawner = null

func _ready() -> void:
	add_to_group("enemy_spawners")
	_mp_spawner = get_parent().get_node_or_null("EnemyMultiplayerSpawner") as MultiplayerSpawner

func spawn_count(count: int, elite_chance: float) -> void:
	if not multiplayer.is_server():
		return
	var points: Array[Node] = []
	for child in get_children():
		if child is SpawnPoint:
			points.append(child)
	if points.is_empty():
		return
	var remaining := count
	for i in range(points.size()):
		var n: int
		if i == points.size() - 1:
			n = maxi(0, remaining)
		else:
			n = mini(remaining, maxi(1, int(remaining * randf_range(0.2, 0.5))))
			remaining = maxi(0, remaining - n)
		for j in n:
			_spawn_at((points[i] as SpawnPoint).global_position, elite_chance)

func _spawn_at(pos: Vector3, elite_chance: float) -> void:
	if not _mp_spawner:
		return
	var actual_pos := pos + Vector3(randf_range(-2.0, 2.0), 0.0, randf_range(-2.0, 2.0))
	var enemy := _mp_spawner.spawn({
		"position": actual_pos,
		"elite_level": _roll_elite(elite_chance)
	}) as Enemy
	if enemy:
		enemy.health_component.died.connect(_on_enemy_died)
		enemy_spawned.emit()

func _roll_elite(chance: float) -> int:
	if randf() >= chance:
		return 0
	return 2 if randf() < 0.25 else 1

func _on_enemy_died() -> void:
	enemy_died.emit()
