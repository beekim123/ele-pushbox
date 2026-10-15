class_name Stat
extends RefCounted

const MODIFIER = preload("res://core/stats/modifier.gd")
var base_value: float
var minimum: float
var maximum: float
var _modifiers: Dictionary = {}

func _init(base: float = 0.0, lower: float = -INF, upper: float = INF) -> void:
	base_value = base
	minimum = lower
	maximum = upper

func add_modifier(source: String, additive: float = 0.0, multiplier: float = 0.0) -> void:
	_modifiers[source] = MODIFIER.new(source, additive, multiplier)

func remove_modifier(source: String) -> void:
	_modifiers.erase(source)

func value() -> float:
	var add: float = 0.0
	var multiply: float = 0.0
	for modifier in _modifiers.values():
		add += modifier.additive
		multiply += modifier.multiplier
	return clampf((base_value + add) * (1.0 + multiply), minimum, maximum)
