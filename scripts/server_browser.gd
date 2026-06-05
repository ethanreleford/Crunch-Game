extends Control

@onready var server_list: VBoxContainer = $ScrollContainer/VBoxContainer

var discover_peer: PacketPeerUDP
var ping_timer: Timer
var known_server_ids: PackedStringArray = []

func _ready():
	_start_discovery()

func _start_discovery():
	discover_peer = PacketPeerUDP.new()
	discover_peer.bind(0)
	discover_peer.set_broadcast_enabled(true)
	ping_timer = Timer.new()
	ping_timer.wait_time = 1.0
	ping_timer.timeout.connect(_send_ping)
	add_child(ping_timer)
	ping_timer.start()
	_send_ping()

func _send_ping():
	var ping = "discover".to_utf8_buffer()
	for port in range(4567, 4578):
		discover_peer.set_dest_address("127.0.0.1", port)
		discover_peer.put_packet(ping)
		discover_peer.set_dest_address("255.255.255.255", port)
		discover_peer.put_packet(ping)

func _process(_delta: float):
	if not discover_peer or discover_peer.get_available_packet_count() == 0:
		return
	while discover_peer.get_available_packet_count() > 0:
		var packet = discover_peer.get_packet()
		var ip = discover_peer.get_packet_ip()
		var data = JSON.parse_string(packet.get_string_from_utf8())
		if not data or not data.has("id"):
			continue
		if data["id"] in known_server_ids:
			continue
		known_server_ids.append(data["id"])
		_add_server_row(ip, data)

func _add_server_row(ip: String, data: Dictionary):
	var hbox = HBoxContainer.new()
	var label = Label.new()
	label.text = "%s — %s" % [data.get("name", "Server"), ip]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var join_btn = Button.new()
	join_btn.text = "Join"
	join_btn.pressed.connect(_join_server.bind(ip, data.get("port", 1027)))
	hbox.add_child(label)
	hbox.add_child(join_btn)
	server_list.add_child(hbox)

func _join_server(ip: String, port: int):
	_cleanup()
	var peer = ENetMultiplayerPeer.new()
	peer.create_client(ip, port)
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected, CONNECT_ONE_SHOT)
	multiplayer.connection_failed.connect(_on_connection_failed, CONNECT_ONE_SHOT)

func _on_connected():
	get_tree().change_scene_to_file("res://Scenes/HostLobby.tscn")

func _on_connection_failed():
	multiplayer.multiplayer_peer = null
	_start_discovery()

func _on_refresh_pressed():
	known_server_ids.clear()
	for child in server_list.get_children():
		child.queue_free()
	_send_ping()

func _on_back_pressed():
	_cleanup()
	get_tree().change_scene_to_file("res://Scenes/main.tscn")

func _cleanup():
	if is_instance_valid(ping_timer):
		ping_timer.stop()
		ping_timer.queue_free()
		ping_timer = null
	if discover_peer:
		discover_peer.close()
		discover_peer = null
