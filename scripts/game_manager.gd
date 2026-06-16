class_name GameManager
extends Node

@export var base_enemies: int = 40
@export var enemies_per_round: int = 15
@export var num_mini_waves: int = 3
@export var next_wave_threshold: int = 5
@export var time_between_rounds: float = 5.0
@export var elite_chance_base: float = 0.15

signal round_started(round_num: int)
signal round_ended(round_num: int)
signal enemy_count_changed(count: int)

var current_round: int = 0
var total_living_enemies: int = 0

var _spawners: Array[EnemySpawner] = []
var _mini_wave_counts: Array[int] = []
var _mini_wave_index: int = 0
var _round_timer: Timer

func _ready() -> void:
	add_to_group("game_manager")
	_round_timer = Timer.new()
	_round_timer.one_shot = true
	_round_timer.timeout.connect(_start_next_round)
	add_child(_round_timer)
	if multiplayer.is_server():
		_round_timer.start(time_between_rounds)

func _start_next_round() -> void:
	if not multiplayer.is_server():
		return
	_spawners.clear()
	for node in get_tree().get_nodes_in_group("enemy_spawners"):
		if node is EnemySpawner:
			_spawners.append(node)
	if _spawners.is_empty():
		return

	current_round += 1
	total_living_enemies = 0

	for spawner in _spawners:
		if not spawner.enemy_spawned.is_connected(_on_enemy_spawned):
			spawner.enemy_spawned.connect(_on_enemy_spawned)
		if not spawner.enemy_died.is_connected(_on_enemy_died):
			spawner.enemy_died.connect(_on_enemy_died)

	var budget := base_enemies + (current_round - 1) * enemies_per_round
	_mini_wave_counts = _split_budget(budget, num_mini_waves)
	_mini_wave_index = 0

	_rpc_round_started.rpc(current_round)
	_fire_next_mini_wave()

func _split_budget(total: int, waves: int) -> Array[int]:
	var result: Array[int] = []
	var remaining := total
	for i in range(waves):
		if i == waves - 1:
			result.append(maxi(1, remaining))
		else:
			var portion := maxi(1, int(remaining * randf_range(0.25, 0.45)))
			result.append(portion)
			remaining -= portion
	return result

func _fire_next_mini_wave() -> void:
	if _mini_wave_index >= _mini_wave_counts.size():
		return
	var count := _mini_wave_counts[_mini_wave_index]
	_mini_wave_index += 1
	var elite_chance := minf(elite_chance_base * current_round, 0.75)
	_distribute(count, elite_chance)

func _distribute(count: int, elite_chance: float) -> void:
	if _spawners.is_empty():
		return
	var remaining := count
	for i in range(_spawners.size()):
		var n: int
		if i == _spawners.size() - 1:
			n = maxi(0, remaining)
		else:
			n = mini(remaining, maxi(1, int(remaining * randf_range(0.15, 0.45))))
			remaining = maxi(0, remaining - n)
		if n > 0:
			_spawners[i].spawn_count(n, elite_chance)

func _on_enemy_spawned() -> void:
	total_living_enemies += 1
	_rpc_enemy_count_changed.rpc(total_living_enemies)

func _on_enemy_died() -> void:
	total_living_enemies -= 1
	_rpc_enemy_count_changed.rpc(total_living_enemies)
	if _mini_wave_index < _mini_wave_counts.size() and total_living_enemies <= next_wave_threshold:
		_fire_next_mini_wave()
	elif _mini_wave_index >= _mini_wave_counts.size() and total_living_enemies <= 0:
		_rpc_round_ended.rpc(current_round)
		_round_timer.start(time_between_rounds)

@rpc("authority", "call_local", "reliable")
func _rpc_round_started(round_num: int) -> void:
	round_started.emit(round_num)

@rpc("authority", "call_local", "reliable")
func _rpc_round_ended(round_num: int) -> void:
	round_ended.emit(round_num)

@rpc("authority", "call_local", "reliable")
func _rpc_enemy_count_changed(count: int) -> void:
	enemy_count_changed.emit(count)
