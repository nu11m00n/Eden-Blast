class_name BombSite
extends Area3D

@export var site_name := "A"

var players_inside: Array[Node] = []


func _ready() -> void:
	add_to_group("bomb_site")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func can_plant(player: Node) -> bool:
	if player == null or not players_inside.has(player):
		return false
	return _get_team(player) == &"attackers"


func try_begin_plant(player: Node) -> bool:
	if not can_plant(player):
		return false
	var bomb := get_tree().get_first_node_in_group("bomb")
	if bomb != null and bomb.has_method("begin_plant"):
		bomb.begin_plant(player, site_name)
		return true
	return false


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and not players_inside.has(body):
		players_inside.append(body)


func _on_body_exited(body: Node3D) -> void:
	players_inside.erase(body)


func _get_team(player: Node) -> StringName:
	if player.has_method("get_team"):
		return player.get_team()
	var value: Variant = player.get("team")
	return value if value is StringName else &"attackers"
