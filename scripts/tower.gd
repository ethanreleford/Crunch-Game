class_name Tower
extends StaticBody3D

@export var cost: int = 100
@export var damage: float = 10.0
@export var range: float = 5.0
@export var attack_speed: float = 1.0

@onready var health_component: HealthComponent = $HealthComponent

func take_damage(amount: float) -> void:
	health_component.take_damage(amount)
