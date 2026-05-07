class_name WeaponPickup
extends Area3D

@export var weapon_data: Resource
@export var magazine_ammo := 0
@export var reserve_ammo := 0


func _ready() -> void:
	add_to_group("weapon_pickup")
	add_to_group("round_reset")
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if weapon_data == null or not body.is_in_group("player"):
		return
	var manager := get_tree().get_first_node_in_group("weapon_manager")
	if manager != null and manager.has_method("try_pickup_weapon"):
		if manager.try_pickup_weapon(body, self):
			queue_free()


func reset_for_round() -> void:
	queue_free()
