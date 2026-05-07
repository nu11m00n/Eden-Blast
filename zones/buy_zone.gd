class_name BuyZone
extends Area3D

@export var team: StringName = &"attackers"

var players_inside: Array[Node] = []


func _ready() -> void:
	add_to_group("buy_zone")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func can_player_buy(player: Node) -> bool:
	if player == null or not players_inside.has(player):
		return false
	if _get_team(player) != team:
		return false
	var round_manager := get_tree().get_first_node_in_group("round_manager")
	return round_manager == null or not round_manager.has_method("is_buy_time") or round_manager.is_buy_time()


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
