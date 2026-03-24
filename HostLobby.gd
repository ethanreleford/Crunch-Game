extends Control

@onready var player_list_container = $ScrollContainer/VBoxContainer
var player_row_scene = preload("res://Scenes/playerRow.tscn")

func _ready():
	multiplayer.peer_connected.connect(_onplayer)
