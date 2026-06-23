class_name ClassSelectScreen
extends Control

@export var destination: String = "res://Scenes/map.tscn"

@onready var _class_list: VBoxContainer = $VBox/Content/ClassColumn/ClassList
@onready var _name_label: Label = $VBox/Content/Stats/NameLabel
@onready var _desc_label: Label = $VBox/Content/Stats/DescLabel
@onready var _stats_label: Label = $VBox/Content/Stats/StatsLabel
@onready var _confirm_btn: Button = $VBox/Bottom/ConfirmButton

var _selected_class: PlayerClassData = null

func _ready() -> void:
	_confirm_btn.disabled = true
	for class_data in ClassRegistry.get_all_classes():
		var btn := Button.new()
		btn.text = class_data.display_name
		btn.pressed.connect(_show_stats.bind(class_data))
		_class_list.add_child(btn)

func _show_stats(class_data: PlayerClassData) -> void:
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
	if _selected_class == null:
		return
	GameState.selected_class_id = _selected_class.class_id
	get_tree().change_scene_to_file(destination)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/main.tscn")
