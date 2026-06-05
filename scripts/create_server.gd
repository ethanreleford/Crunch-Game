extends Control

@onready var name_input: LineEdit = $NameInput
@onready var status_label: Label = $StatusLabel

func _on_create_pressed():
	var raw := name_input.text.strip_edges()
	GameState.server_name = raw if raw != "" else "My Server"

	var peer: ENetMultiplayerPeer
	var hosted := false
	for port in range(1027, 1038):
		peer = ENetMultiplayerPeer.new()
		if peer.create_server(port) == OK:
			GameState.server_port = port
			hosted = true
			break
	if not hosted:
		status_label.text = "Error: No available port in range 1027-1037."
		return
	multiplayer.multiplayer_peer = peer
	get_tree().change_scene_to_file("res://Scenes/HostLobby.tscn")

func _on_back_pressed():
	get_tree().change_scene_to_file("res://Scenes/main.tscn")
