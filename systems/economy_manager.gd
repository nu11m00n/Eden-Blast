class_name EconomyManager
extends Node

@export var starting_money := 800
@export var max_money := 16000
@export var round_win_reward := 3250
@export var round_loss_reward := 1400
@export var loss_bonus_step := 500
@export var max_loss_bonus := 3400
@export var bomb_plant_reward := 800
@export var bomb_defuse_reward := 300

var _money_by_peer: Dictionary = {}
var _loss_streak: Dictionary = {
	&"attackers": 0,
	&"defenders": 0,
}


func _ready() -> void:
	add_to_group("economy_manager")


func reset_match() -> void:
	_money_by_peer.clear()
	_loss_streak[&"attackers"] = 0
	_loss_streak[&"defenders"] = 0
	for player in get_tree().get_nodes_in_group("player"):
		register_player(player)


func on_freeze_started() -> void:
	for player in get_tree().get_nodes_in_group("player"):
		register_player(player)


func register_player(player: Node) -> void:
	var id := _player_id(player)
	if not _money_by_peer.has(id):
		_money_by_peer[id] = starting_money


func can_afford(player: Node, cost: int) -> bool:
	register_player(player)
	return int(_money_by_peer[_player_id(player)]) >= cost


func spend(player: Node, cost: int) -> bool:
	if cost <= 0:
		return true
	if not can_afford(player, cost):
		return false
	var id := _player_id(player)
	_money_by_peer[id] = maxi(0, int(_money_by_peer[id]) - cost)
	return true


func award(player: Node, amount: int) -> void:
	if player == null or amount <= 0:
		return
	register_player(player)
	var id := _player_id(player)
	_money_by_peer[id] = mini(max_money, int(_money_by_peer[id]) + amount)


func get_money(player: Node) -> int:
	register_player(player)
	return int(_money_by_peer[_player_id(player)])


func on_player_killed(attacker: Node, victim: Node, weapon_data: Resource) -> void:
	if attacker == null or attacker == victim:
		return
	var reward := 300
	if weapon_data != null:
		var value: Variant = weapon_data.get("kill_reward")
		if value != null:
			reward = int(value)
	award(attacker, reward)


func on_bomb_planted(planter: Node) -> void:
	award(planter, bomb_plant_reward)


func on_bomb_defused(defuser: Node) -> void:
	award(defuser, bomb_defuse_reward)


func on_round_ended(winner_team: StringName, _reason: String) -> void:
	var loser_team := &"defenders" if winner_team == &"attackers" else &"attackers"
	_loss_streak[winner_team] = 0
	_loss_streak[loser_team] = int(_loss_streak.get(loser_team, 0)) + 1

	for player in get_tree().get_nodes_in_group("player"):
		var team := _get_team(player)
		if team == winner_team:
			award(player, round_win_reward)
		else:
			var loss_reward: int = mini(round_loss_reward + (int(_loss_streak[loser_team]) - 1) * loss_bonus_step, max_loss_bonus)
			award(player, loss_reward)


func _player_id(player: Node) -> int:
	var peer_id: Variant = player.get("peer_id")
	if peer_id != null:
		return int(peer_id)
	return player.get_instance_id()


func _get_team(player: Node) -> StringName:
	if player.has_method("get_team"):
		return player.get_team()
	var value: Variant = player.get("team")
	return value if value is StringName else &"attackers"
