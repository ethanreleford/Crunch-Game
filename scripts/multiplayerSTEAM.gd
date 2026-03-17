extends Node

@export_enum("Steam", "ENet") var net_mode : String = "Steam"

var lobby_id : int = 0 
var peer 
@export var player_scene : PackedScene
var is_host : bool = false

var is_joining : bool = false
@onready var start_button: Button = $"../start_button"
@onready var join_button: Button = $"../join_button"
@onready var host_button: Button = $"../host_button"
@onready var id_prompt: LineEdit = $"../id_prompt"


func _ready():
	if net_mode == "ENet":
		peer = ENetMultiplayerPeer.new()
	elif net_mode == "Steam":
		peer = SteamMultiplayerPeer.new()
		print("Steam Initialized: ", Steam.steamInit(480, true))
		Steam.initRelayNetworkAccess()
		Steam.lobby_created.connect(_on_lobby_created)
		Steam.lobby_joined.connect(_on_lobby_joined)
	
	
func host_lobby():
	is_host = true
	if net_mode == "ENet":
		peer.create_server(1027)
		multiplayer.multiplayer_peer = peer
		multiplayer.peer_connected.connect(_add_player)
		multiplayer.peer_disconnected.connect(_remove_player)
		_add_player()
	elif net_mode == "Steam":
		Steam.createLobby(Steam.LobbyType.LOBBY_TYPE_PUBLIC, 16)
	
func _on_lobby_created(result : int, lobby_id : int):
	if result == Steam.Result.RESULT_OK:
		self.lobby_id = lobby_id
		
		peer = SteamMultiplayerPeer.new()
		peer.server_relay = true
		peer.create_host()
		
		multiplayer.multiplayer_peer = peer
		multiplayer.peer_connected.connect(_add_player)
		multiplayer.peer_disconnected.connect(_remove_player)
		_add_player()
		print("LOBBY CREATED, LOBBY ID: ", lobby_id)

func join_lobby(lobby_id : int = 0):
	is_joining = true
	
	if net_mode == "ENet":
		peer.create_client("127.0.0.1", 1027)
		multiplayer.multiplayer_peer = peer
	elif net_mode == "Steam":
		Steam.joinLobby(lobby_id)

func _on_lobby_joined(lobby_id : int, permissions : int, locked : bool, response : int):
	if !is_joining:
		return
	
	self.lobby_id = lobby_id
	peer = SteamMultiplayerPeer.new()
	peer.server_relay = true
	
	# Connect signals for the client so they can spawn other players
	multiplayer.peer_connected.connect(_add_player)
	multiplayer.peer_disconnected.connect(_remove_player)
	
	peer.create_client(Steam.getLobbyOwner(lobby_id))
	multiplayer.multiplayer_peer = peer
	is_joining = false
	print("JOINED LOBBY: ", lobby_id)

	
func _add_player(id : int = 1):
	var player = player_scene.instantiate()
	player.name = str(id)
	call_deferred("add_child", player)
	
func _remove_player(id : int):
	if !self.has_node(str(id)):
		return
		
	self.get_node(str(id)).queue_free()
	
	
func _on_start_button_pressed() -> void:
	pass # Replace with function body.

func _on_host_button_pressed() -> void:
	host_lobby()

func _on_join_button_pressed() -> void:
	join_lobby(id_prompt.text.to_int())


func _on_id_prompt_text_changed(new_text: String) -> void:
	join_button.disabled = (new_text.length() == 0)
