class_name HealthComponent
extends Node

@export var max_health: float = 100.0
var health: float
var _dead: bool = false

signal died
signal health_changed(new_health: float)

func _ready() -> void:
	health = max_health

func take_damage(amount: float) -> void:
	if _dead:
		return
	health = max(health - amount, 0.0)
	health_changed.emit(health)
	if health == 0.0:
		_dead = true
		die()

func die() -> void:
	died.emit()
	get_parent().queue_free()
