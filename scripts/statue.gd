class_name Statue
extends StaticBody3D

@export var max_health: float = 500.0
@export var upgrade_level: int = 0

@onready var health_component: HealthComponent = $HealthComponent

func _ready() -> void:
	health_component.max_health = max_health
	health_component.health = max_health

func take_damage(amount: float) -> void:
	health_component.take_damage(amount)
