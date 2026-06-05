extends Control

@onready var lobby_input: LineEdit = $LobbyInput
@onready var join_button: Button = $JoinButton
@onready var status_label: Label = $StatusLabel

func _ready() -> void:
	join_button.disabled = true
	Steam.lobby_joined.connect(_on_lobby_joined)

func _on_lobby_input_text_changed(new_text: String) -> void:
	join_button.disabled = not new_text.strip_edges().is_valid_int()

func _on_join_pressed() -> void:
	var lobby_id = int(lobby_input.text.strip_edges())
	status_label.text = "Joining lobby..."
	join_button.disabled = true
	Steam.joinLobby(lobby_id)

func _on_lobby_joined(lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response != 1:
		status_label.text = "Failed to join lobby (code %d)." % response
		join_button.disabled = false
		return
	var peer = SteamMultiplayerPeer.new()
	peer.server_relay = true
	peer.create_client(Steam.getLobbyOwner(lobby_id))
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected, CONNECT_ONE_SHOT)
	multiplayer.connection_failed.connect(_on_connection_failed, CONNECT_ONE_SHOT)

func _on_connected() -> void:
	get_tree().change_scene_to_file("res://Scenes/HostLobby.tscn")

func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = null
	status_label.text = "Connection failed."
	join_button.disabled = false

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/main.tscn")
