class_name DamageSystem
extends Node

signal damage_applied(victim: Node, attacker: Node, amount: int, hitgroup: StringName)
signal player_killed(victim: Node, attacker: Node, weapon_data: Resource, hitgroup: StringName)

@export var default_health := 100
@export var default_armor := 0
@export var default_has_helmet := false


func _ready() -> void:
	add_to_group("damage_system")


func apply_hitscan_hit(hit: Dictionary, attacker: Node, weapon_data: Resource, direction: Vector3) -> int:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return 0
	if hit.is_empty():
		return 0
	var collider: Object = hit.get("collider")
	var victim := _resolve_victim(collider)
	if victim == null:
		return 0

	var hitgroup := _resolve_hitgroup(collider)
	var raw_damage := _calculate_damage(weapon_data, hitgroup)
	var final_damage := _apply_armor(victim, raw_damage, weapon_data, hitgroup)
	_apply_damage(victim, final_damage, direction)
	damage_applied.emit(victim, attacker, final_damage, hitgroup)

	if _get_health(victim) <= 0:
		player_killed.emit(victim, attacker, weapon_data, hitgroup)
		var round_manager := get_tree().get_first_node_in_group("round_manager")
		if round_manager != null and round_manager.has_method("notify_player_killed"):
			round_manager.notify_player_killed(victim, attacker, weapon_data)
	return final_damage


func _calculate_damage(weapon_data: Resource, hitgroup: StringName) -> int:
	if weapon_data == null:
		return 1
	var base := float(weapon_data.get("damage"))
	var multiplier := 1.0
	match hitgroup:
		&"head":
			multiplier = float(weapon_data.get("head_multiplier"))
		&"limb":
			multiplier = float(weapon_data.get("limb_multiplier"))
		_:
			multiplier = float(weapon_data.get("body_multiplier"))
	return maxi(1, int(round(base * multiplier)))


func _apply_armor(victim: Node, damage: int, weapon_data: Resource, hitgroup: StringName) -> int:
	var armor := _get_armor(victim)
	if armor <= 0:
		return damage
	if hitgroup == &"head" and not _has_helmet(victim):
		return damage

	var penetration := 0.5
	if weapon_data != null and weapon_data.get("armor_penetration") != null:
		penetration = clampf(float(weapon_data.get("armor_penetration")), 0.0, 1.0)
	var armor_absorb := int(round(float(damage) * (1.0 - penetration) * 0.5))
	_set_armor(victim, maxi(0, armor - armor_absorb))
	return maxi(1, damage - armor_absorb)


func _apply_damage(victim: Node, damage: int, direction: Vector3) -> void:
	if victim.has_method("apply_damage"):
		victim.apply_damage(damage, direction)
		return
	if victim.get("health") != null:
		victim.set("health", int(victim.get("health")) - damage)


func _resolve_victim(collider: Object) -> Node:
	if collider is Hitbox:
		return (collider as Hitbox).get_victim()
	if collider is Node:
		var node := collider as Node
		if node.is_in_group("damageable") or node.is_in_group("player") or node.is_in_group("enemy"):
			return node
		var parent := node.get_parent()
		while parent != null:
			if parent.is_in_group("damageable") or parent.is_in_group("player") or parent.is_in_group("enemy"):
				return parent
			parent = parent.get_parent()
	return null


func _resolve_hitgroup(collider: Object) -> StringName:
	if collider is Hitbox:
		return (collider as Hitbox).hitgroup
	return &"body"


func _get_health(victim: Node) -> int:
	return int(victim.get("health")) if victim.get("health") != null else default_health


func _get_armor(victim: Node) -> int:
	return int(victim.get("armor")) if victim.get("armor") != null else default_armor


func _set_armor(victim: Node, armor: int) -> void:
	if victim.get("armor") != null:
		victim.set("armor", armor)


func _has_helmet(victim: Node) -> bool:
	return bool(victim.get("has_helmet")) if victim.get("has_helmet") != null else default_has_helmet
