class_name GameManager
extends Node

enum State { IDLE, SPAWNING, BETWEEN_ROUNDS }

@export var elite_chance_base: float = 0.15
@export var time_between_rounds: float = 5.0

signal round_started(round_num: int)
signal round_ended(round_num: int)
signal enemy_count_changed(count: int)

var current_round: int = 0
var state: State = State.IDLE
var total_living_enemies: int = 0

var _spawners: Array[EnemySpawner] = []
var _spawners_done: int = 0
var _round_timer: Timer

func _ready() -> void:
	add_to_group("game_manager")
	_round_timer = Timer.new()
	_round_timer.one_shot = true
	_round_timer.timeout.connect(_start_next_round)
	add_child(_round_timer)
	_round_timer.start(3.0)

func _start_next_round() -> void:
	_spawners.clear()
	for node in get_tree().get_nodes_in_group("enemy_spawners"):
		if node is EnemySpawner:
			_spawners.append(node)
	if _spawners.is_empty():
		return

	current_round += 1
	_spawners_done = 0
	total_living_enemies = 0
	state = State.SPAWNING
	round_started.emit(current_round)

	for spawner in _spawners:
		if not spawner.wave_completed.is_connected(_on_spawner_wave_completed):
			spawner.wave_completed.connect(_on_spawner_wave_completed)
		if not spawner.enemy_spawned.is_connected(_on_enemy_spawned):
			spawner.enemy_spawned.connect(_on_enemy_spawned)
		if not spawner.enemy_died.is_connected(_on_enemy_died):
			spawner.enemy_died.connect(_on_enemy_died)
		spawner.begin_wave(current_round, elite_chance_base)

func _on_enemy_spawned() -> void:
	total_living_enemies += 1
	enemy_count_changed.emit(total_living_enemies)

func _on_enemy_died() -> void:
	total_living_enemies -= 1
	enemy_count_changed.emit(total_living_enemies)

func _on_spawner_wave_completed() -> void:
	_spawners_done += 1
	if _spawners_done >= _spawners.size():
		state = State.BETWEEN_ROUNDS
		round_ended.emit(current_round)
		_round_timer.start(time_between_rounds)
