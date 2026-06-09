class_name Entity
extends CharacterBody3D

@export var speed: float = 5.0
@export var max_health: float = 100.0

@onready var health_component: HealthComponent = $HealthComponent
@onready var _debug_label: Label3D = $DebugLabel

func _ready() -> void:
	health_component.max_health = max_health
	health_component.health = max_health
	health_component.health_changed.connect(_update_debug_label)
	_update_debug_label(health_component.health)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_stats") and not event.is_echo():
		_debug_label.visible = not _debug_label.visible

func take_damage(amount: float) -> void:
	health_component.take_damage(amount)

func _update_debug_label(current_health: float) -> void:
	_debug_label.text = "HP: %d / %d\nSpd: %.1f" % [current_health, health_component.max_health, speed]
