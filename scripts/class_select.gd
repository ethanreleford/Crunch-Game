class_name ClassSelectScreen
extends Control

@export var destination: String = "res://Scenes/map.tscn"

@onready var _base_list: VBoxContainer = $VBox/Content/BaseColumn/BaseList
@onready var _sub_list: VBoxContainer = $VBox/Content/SubColumn/SubList
@onready var _name_label: Label = $VBox/Content/Stats/NameLabel
@onready var _desc_label: Label = $VBox/Content/Stats/DescLabel
@onready var _stats_label: Label = $VBox/Content/Stats/StatsLabel
@onready var _confirm_btn: Button = $VBox/Bottom/ConfirmButton

var _selected_class: PlayerClassData = null

func _ready() -> void:
	_confirm_btn.disabled = true
	for base_class in ClassRegistry.get_all_base_classes():
		var btn := Button.new()
		btn.text = base_class.display_name
		btn.pressed.connect(_on_base_selected.bind(base_class))
		_base_list.add_child(btn)

func _on_base_selected(base_class: PlayerClassData) -> void:
	for child in _sub_list.get_children():
		child.queue_free()
	for sub in ClassRegistry.get_subclasses(base_class.class_id):
		var btn := Button.new()
		btn.text = sub.display_name
		btn.pressed.connect(_show_stats.bind(sub))
		_sub_list.add_child(btn)
	_show_stats(base_class)

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
