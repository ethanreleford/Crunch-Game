extends Control

@onready var player_list: VBoxContainer = $ScrollContainer/VBoxContainer
@onready var start_button: Button = $StartButton
@onready var lobby_code_label: Label = $LobbyCodeLabel
@export var player_row_scene: PackedScene

var players: Dictionary = {}
var discovery_peer: PacketPeerUDP
var server_id: String = ""

func _ready():
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	start_button.visible = multiplayer.is_server()

	players[multiplayer.get_unique_id()] = _get_my_name()
	_refresh_list()

	if multiplayer.is_server():
		if multiplayer.multiplayer_peer is SteamMultiplayerPeer:
			lobby_code_label.text = "Lobby ID: %d" % GameState.steam_lobby_id
		else:
			server_id = str(randi())
			discovery_peer = PacketPeerUDP.new()
			for port in range(4567, 4578):
				if discovery_peer.bind(port) == OK:
					break
			lobby_code_label.text = "%s  —  %s : %d" % [GameState.server_name, _get_local_ip(), GameState.server_port]
	else:
		_submit_name.rpc_id(1, _get_my_name())

func _process(_delta: float):
	if not discovery_peer:
		return
	while discovery_peer.get_available_packet_count() > 0:
		var _ping = discovery_peer.get_packet()
		var requester_ip = discovery_peer.get_packet_ip()
		var requester_port = discovery_peer.get_packet_port()
		var response = JSON.stringify({"name": GameState.server_name, "port": GameState.server_port, "id": server_id}).to_utf8_buffer()
		discovery_peer.set_dest_address(requester_ip, requester_port)
		discovery_peer.put_packet(response)

func _get_local_ip() -> String:
	for addr in IP.get_local_addresses():
		if addr.begins_with("192.") or addr.begins_with("10.") or addr.begins_with("172."):
			return addr
	return "127.0.0.1"

func _get_my_name() -> String:
	if multiplayer.multiplayer_peer is SteamMultiplayerPeer:
		return Steam.getPersonaName()
	return "Player %d" % multiplayer.get_unique_id()

func _stop_discovery():
	if discovery_peer:
		discovery_peer.close()
		discovery_peer = null

func _on_peer_connected(_id: int):
	pass

func _on_peer_disconnected(id: int):
	if multiplayer.is_server():
		players.erase(id)
		_sync_players.rpc(players)

func _on_server_disconnected():
	multiplayer.multiplayer_peer = null
	get_tree().change_scene_to_file("res://Scenes/main.tscn")

@rpc("any_peer", "reliable")
func _submit_name(player_name: String):
	if not multiplayer.is_server():
		return
	var id = multiplayer.get_remote_sender_id()
	players[id] = player_name
	_sync_players.rpc(players)

@rpc("authority", "call_local", "reliable")
func _sync_players(player_dict: Dictionary):
	players = player_dict
	_refresh_list()

func _refresh_list():
	for child in player_list.get_children():
		child.queue_free()
	for id in players:
		var row = player_row_scene.instantiate()
		row.get_node("Label").text = players[id]
		player_list.add_child(row)

func _on_start_button_pressed():
	if multiplayer.is_server():
		_start_game.rpc()

@rpc("authority", "call_local", "reliable")
func _start_game():
	_stop_discovery()
	get_tree().change_scene_to_file("res://Scenes/main_3D_Map.tscn")

func _on_leave_button_pressed():
	_stop_discovery()
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	get_tree().change_scene_to_file("res://Scenes/main.tscn")
