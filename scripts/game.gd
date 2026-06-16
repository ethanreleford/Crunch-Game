extends Node3D

@export var player_scene: PackedScene

var _spawn_index: int = 0

func _ready():
	($EnemyMultiplayerSpawner as MultiplayerSpawner).spawn_function = _create_enemy
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	if not multiplayer.is_server():
		return
	_spawn_player(1)
	for id in multiplayer.get_peers():
		_spawn_player(id)
	multiplayer.peer_connected.connect(_spawn_player)
	multiplayer.peer_disconnected.connect(_remove_player)

func _create_enemy(data: Dictionary) -> Object:
	var enemy: Enemy = preload("res://Scenes/enemy.tscn").instantiate()
	enemy.elite_level = data.get("elite_level", 0)
	enemy.position = data.get("position", Vector3.ZERO)
	return enemy

func _spawn_player(id: int):
	var pos = Vector3(_spawn_index * 5.0, 2.0, 10.0)
	_spawn_index += 1
	var player = player_scene.instantiate()
	player.name = str(id)
	add_child(player)
	if id == multiplayer.get_unique_id():
		player.global_position = pos
	else:
		_set_spawn_position.rpc_id(id, pos)

@rpc("authority", "reliable")
func _set_spawn_position(pos: Vector3):
	var my_player = get_node_or_null(str(multiplayer.get_unique_id()))
	if my_player:
		my_player.global_position = pos

func _remove_player(id: int):
	var node = get_node_or_null(str(id))
	if node:
		node.queue_free()

func _on_server_disconnected():
	multiplayer.multiplayer_peer = null
	get_tree().change_scene_to_file("res://Scenes/main.tscn")
