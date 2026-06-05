class_name Entity
extends CharacterBody3D

@export var speed: float = 5.0

@onready var health_component: HealthComponent = $HealthComponent

func take_damage(amount: float) -> void:
	health_component.take_damage(amount)
