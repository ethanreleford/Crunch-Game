extends Control

@export_enum("Steam", "ENet") var net_mode: String = "ENet"

var peer

func _ready():
	if net_mode == "Steam":
		peer = SteamMultiplayerPeer.new()
		print("Steam Initialized: ", Steam.steamInit(480, true))
		Steam.initRelayNetworkAccess()
		Steam.lobby_created.connect(_on_lobby_created)
		Steam.lobby_joined.connect(_on_lobby_joined)

func _on_lobby_created(result: int, lobby_id: int):
	if result == Steam.Result.RESULT_OK:
		peer = SteamMultiplayerPeer.new()
		peer.server_relay = true
		peer.create_host()
		multiplayer.multiplayer_peer = peer
		get_tree().change_scene_to_file("res://Scenes/HostLobby.tscn")

func _on_lobby_joined(lobby_id: int, _permissions: int, _locked: bool, _response: int):
	peer = SteamMultiplayerPeer.new()
	peer.server_relay = true
	peer.create_client(Steam.getLobbyOwner(lobby_id))
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected)

func _on_connected():
	get_tree().change_scene_to_file("res://Scenes/HostLobby.tscn")

func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/main_3D_Map.tscn")

func _on_host_button_pressed() -> void:
	if net_mode == "ENet":
		get_tree().change_scene_to_file("res://Scenes/CreateServer.tscn")
	elif net_mode == "Steam":
		Steam.createLobby(Steam.LobbyType.LOBBY_TYPE_PUBLIC, 16)

func _on_join_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/ServerBrowser.tscn")
