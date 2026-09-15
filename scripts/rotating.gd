@tool
extends Node3D

var timer := 0.0

func _process(delta: float) -> void:
	timer += delta
	position.y = sin(timer * 1.5) * 0.25
	rotation.y += delta * 0.5
	rotation.x = sin(timer * 1.5 + 1.5) * 0.1
	rotation.z = cos(timer * 1.5 + 1.5) * 0.1
