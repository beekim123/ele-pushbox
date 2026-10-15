class_name StatModifier
extends RefCounted

var source: String
var additive: float
var multiplier: float

func _init(owner_source: String = "", add: float = 0.0, multiply: float = 0.0) -> void:
	source = owner_source
	additive = add
	multiplier = multiply
