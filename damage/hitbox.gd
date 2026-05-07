class_name Hitbox
extends Area3D

@export var hitgroup: StringName = &"body"
@export var victim_path: NodePath


func _ready() -> void:
	add_to_group("hitbox")


func get_victim() -> Node:
	if not victim_path.is_empty():
		var explicit := get_node_or_null(victim_path)
		if explicit != null:
			return explicit
	var node := get_parent()
	while node != null:
		if node.is_in_group("damageable") or node.is_in_group("player") or node.is_in_group("enemy"):
			return node
		node = node.get_parent()
	return null
