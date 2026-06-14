class_name EnemySpawner
extends Node3D

@export var enemy_scene: PackedScene
@export var burst_interval: float = 10.0
@export var base_spawn_limit: int = 10
@export var spawn_limit_increase: int = 3

signal wave_completed
signal enemy_spawned
signal enemy_died

var _living_enemies: int = 0
var _total_spawned: int = 0
var _round_limit: int = 0
var _current_round: int = 0
var _elite_chance_base: float = 0.0
var _burst_timer: Timer

func _ready() -> void:
	add_to_group("enemy_spawners")
	_burst_timer = Timer.new()
	_burst_timer.wait_time = burst_interval
	_burst_timer.timeout.connect(_fire_burst)
	add_child(_burst_timer)

func begin_wave(round_num: int, elite_chance_base: float) -> void:
	_current_round = round_num
	_elite_chance_base = elite_chance_base
	_round_limit = base_spawn_limit + (round_num - 1) * spawn_limit_increase
	_total_spawned = 0
	_living_enemies = 0
	_fire_burst()
	if _total_spawned < _round_limit:
		_burst_timer.start()

func _fire_burst() -> void:
	if _total_spawned >= _round_limit:
		_burst_timer.stop()
		return
	for child in get_children():
		if not child is SpawnPoint:
			continue
		var remaining := _round_limit - _total_spawned
		var to_spawn := mini(child.burst_size, remaining)
		for i in to_spawn:
			_spawn_at(child.global_position)
		if _total_spawned >= _round_limit:
			_burst_timer.stop()
			break

func _spawn_at(pos: Vector3) -> void:
	var enemy: Enemy = enemy_scene.instantiate()
	enemy.elite_level = _roll_elite_level()
	add_child(enemy)
	var offset := Vector3(randf_range(-1.5, 1.5), 0.0, randf_range(-1.5, 1.5))
	enemy.global_position = pos + offset
	enemy.health_component.died.connect(_on_enemy_died)
	_living_enemies += 1
	_total_spawned += 1
	enemy_spawned.emit()

func _roll_elite_level() -> int:
	var chance := minf(_elite_chance_base * _current_round, 0.75)
	if randf() >= chance:
		return 0
	return 2 if randf() < 0.25 else 1

func _on_enemy_died() -> void:
	_living_enemies -= 1
	enemy_died.emit()
	if _living_enemies <= 0 and _total_spawned >= _round_limit:
		wave_completed.emit()
