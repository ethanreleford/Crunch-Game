class_name Entity
extends CharacterBody3D

static var _debug_visible: bool = false

@export var speed: float = 5.0
@export var max_health: float = 100.0

@onready var health_component: HealthComponent = $HealthComponent
@onready var _debug_label: Label3D = $DebugLabel

func _ready() -> void:
	add_to_group("entities")
	health_component.max_health = max_health
	health_component.health = max_health
	health_component.health_changed.connect(_update_debug_label)
	_update_debug_label(health_component.health)
	_debug_label.visible = _debug_visible

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_stats") and not event.is_echo():
		_debug_visible = not _debug_visible
		get_viewport().set_input_as_handled()
		for entity in get_tree().get_nodes_in_group("entities"):
			(entity as Entity)._debug_label.visible = _debug_visible

func take_damage(amount: float) -> void:
	health_component.take_damage(amount)

func _update_debug_label(current_health: float) -> void:
	_debug_label.text = "HP: %d / %d\nSpd: %.1f" % [current_health, health_component.max_health, speed]
