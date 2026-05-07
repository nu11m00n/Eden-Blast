class_name SpawnZone
extends Marker3D

@export var team: StringName = &"attackers"


func _ready() -> void:
	add_to_group("spawn_zone")
