class_name PlayerClassData
extends Resource

enum OnHitEffect { NONE, POISON, FIRE, FREEZE }

@export var class_id: String = ""
@export var display_name: String = ""
@export var base_class_id: String = ""  # empty = this IS a base class
@export var description: String = ""

@export_group("Stats")
@export var max_health: float = 100.0
@export var speed: float = 5.0
@export var base_damage: float = 10.0

@export_group("On-Hit Effect")
@export var on_hit_effect: OnHitEffect = OnHitEffect.NONE
@export var on_hit_dot_dps: float = 0.0
@export var on_hit_dot_duration: float = 0.0

func is_base_class() -> bool:
	return base_class_id.is_empty()
