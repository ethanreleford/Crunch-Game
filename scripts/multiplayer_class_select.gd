extends Control

@onready var _class_list: VBoxContainer = $HBox/LeftPanel/ClassList
@onready var _name_label: Label = $HBox/LeftPanel/Stats/NameLabel
@onready var _desc_label: Label = $HBox/LeftPanel/Stats/DescLabel
@onready var _stats_label: Label = $HBox/LeftPanel/Stats/StatsLabel
@onready var _confirm_btn: Button = $HBox/LeftPanel/ConfirmButton
@onready var _checklist: VBoxContainer = $HBox/RightPanel/Checklist

var _selected_class: PlayerClassData = null
var _confirmed := false
var _ready_players: Dictionary = {}  # peer_id (int) -> class_id (String, "" = not yet locked)

func _ready() -> void:
	_confirm_btn.disabled = true

	for class_data in ClassRegistry.get_all_classes():
		var btn := Button.new()
		btn.text = class_data.display_name
		btn.pressed.connect(_on_class_selected.bind(class_data))
		_class_list.add_child(btn)

	if multiplayer.is_server():
		_ready_players[1] = ""
		for peer_id in multiplayer.get_peers():
			_ready_players[peer_id] = ""
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		_sync_ready_players.rpc(_ready_players)

func _on_class_selected(class_data: PlayerClassData) -> void:
	if _confirmed:
		return
	_selected_class = class_data
	_name_label.text = class_data.display_name
	_desc_label.text = class_data.description
	var effect_names := ["None", "Poison", "Fire", "Freeze"]
	var effect: String = effect_names[mini(class_data.on_hit_effect, effect_names.size() - 1)]
	_stats_label.text = "HP: %d   Speed: %.1f   Damage: %.1f\nOn-Hit: %s" % [
		class_data.max_health, class_data.speed, class_data.base_damage, effect
	]
	_confirm_btn.disabled = false

func _on_confirm_pressed() -> void:
	if _selected_class == null or _confirmed:
		return
	_confirmed = true
	_confirm_btn.disabled = true
	_confirm_btn.text = "Locked In!"
	GameState.selected_class_id = _selected_class.class_id
	if multiplayer.is_server():
		_record_class(1, _selected_class.class_id)
	else:
		_submit_class.rpc_id(1, _selected_class.class_id)

# Called on server only — from RPC or directly when server locks in
func _record_class(peer_id: int, class_id: String) -> void:
	_ready_players[peer_id] = class_id
	GameState.player_class_ids[peer_id] = class_id
	_sync_ready_players.rpc(_ready_players)
	_check_all_ready()

func _check_all_ready() -> void:
	for class_id in _ready_players.values():
		if class_id == "":
			return
	_begin_game.rpc()

func _on_peer_disconnected(peer_id: int) -> void:
	_ready_players.erase(peer_id)
	GameState.player_class_ids.erase(peer_id)
	_sync_ready_players.rpc(_ready_players)
	_check_all_ready()

@rpc("any_peer", "reliable")
func _submit_class(class_id: String) -> void:
	if not multiplayer.is_server():
		return
	_record_class(multiplayer.get_remote_sender_id(), class_id)

@rpc("authority", "call_local", "reliable")
func _sync_ready_players(ready_dict: Dictionary) -> void:
	_ready_players = ready_dict
	for peer_id in ready_dict:
		if ready_dict[peer_id] != "":
			GameState.player_class_ids[peer_id] = ready_dict[peer_id]
	_refresh_checklist()

@rpc("authority", "call_local", "reliable")
func _begin_game() -> void:
	get_tree().change_scene_to_file("res://Scenes/map.tscn")

func _refresh_checklist() -> void:
	for child in _checklist.get_children():
		child.queue_free()
	for peer_id in _ready_players:
		var label := Label.new()
		var player_name: String = GameState.player_names.get(peer_id, "Player %d" % peer_id)
		var class_id: String = _ready_players[peer_id]
		if class_id == "":
			label.text = "%s  —  choosing..." % player_name
		else:
			var data := ClassRegistry.get_class_data(class_id)
			label.text = "%s  —  %s  ✓" % [player_name, data.display_name if data else class_id]
		_checklist.add_child(label)
