extends CanvasLayer

@onready var round_label: Label = $VBoxContainer/RoundLabel
@onready var enemy_label: Label = $VBoxContainer/EnemyLabel
@onready var status_label: Label = $VBoxContainer/StatusLabel

func _ready() -> void:
	var gm := get_tree().get_first_node_in_group("game_manager") as GameManager
	if not gm:
		return
	gm.round_started.connect(_on_round_started)
	gm.round_ended.connect(_on_round_ended)
	gm.enemy_count_changed.connect(_on_enemy_count_changed)
	status_label.text = "Get Ready..."

func _on_round_started(round_num: int) -> void:
	round_label.text = "Round %d" % round_num
	status_label.text = ""

func _on_round_ended(_round_num: int) -> void:
	status_label.text = "Wave Clear!"

func _on_enemy_count_changed(count: int) -> void:
	enemy_label.text = "Enemies: %d" % count
