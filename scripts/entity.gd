class_name Entity
extends CharacterBody3D

@export var max_health: float = 100.0
@export var speed: float = 5.0

var health: float

signal died
signal health_changed(new_health: float)

func _ready() -> void:
	health = max_health

func take_damage(amount: float) -> void:
	health = max(health - amount, 0.0)
	health_changed.emit(health)
	if health == 0.0:
		die()

func die() -> void:
	died.emit()
	queue_free()
