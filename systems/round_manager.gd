class_name RoundManager
extends Node

signal phase_changed(phase: StringName)
signal round_ended(winner_team: StringName, reason: String)

enum Phase { WARMUP, FREEZE, LIVE, BOMB_PLANTED, ROUND_END }

@export var freeze_time := 12.0
@export var round_time := 115.0
@export var bomb_time := 45.0
@export var post_round_time := 6.0
@export var auto_start := true

var phase: Phase = Phase.WARMUP
var time_left := 0.0
var round_number := 0
var attackers_alive := 0
var defenders_alive := 0
var bomb_planted := false

@onready var economy: EconomyManager = get_node_or_null("../EconomyManager") as EconomyManager


func _ready() -> void:
	add_to_group("round_manager")
	if auto_start and _is_authority():
		start_match()


func _process(delta: float) -> void:
	if not _is_authority():
		return
	if phase == Phase.WARMUP:
		return

	time_left = maxf(time_left - delta, 0.0)
	if time_left > 0.0:
		return

	match phase:
		Phase.FREEZE:
			_set_phase(Phase.LIVE, round_time)
		Phase.LIVE:
			end_round(&"defenders", "time")
		Phase.BOMB_PLANTED:
			end_round(&"attackers", "bomb_exploded")
		Phase.ROUND_END:
			start_round()


func start_match() -> void:
	round_number = 0
	if economy != null:
		economy.reset_match()
	start_round()


func start_round() -> void:
	round_number += 1
	bomb_planted = false
	_refresh_alive_counts()
	get_tree().call_group("round_reset", "reset_for_round")
	if economy != null:
		economy.on_freeze_started()
	_set_phase(Phase.FREEZE, freeze_time)


func notify_player_killed(victim: Node, attacker: Node, weapon_data: Resource) -> void:
	if not _is_authority() or phase == Phase.ROUND_END:
		return
	if economy != null:
		economy.on_player_killed(attacker, victim, weapon_data)
	_refresh_alive_counts()
	if attackers_alive <= 0:
		end_round(&"defenders", "elimination")
	elif defenders_alive <= 0:
		end_round(&"attackers", "elimination")


func notify_bomb_planted(planter: Node) -> void:
	if not _is_authority() or phase != Phase.LIVE:
		return
	bomb_planted = true
	if economy != null:
		economy.on_bomb_planted(planter)
	_set_phase(Phase.BOMB_PLANTED, bomb_time)


func notify_bomb_defused(defuser: Node) -> void:
	if not _is_authority() or phase != Phase.BOMB_PLANTED:
		return
	if economy != null:
		economy.on_bomb_defused(defuser)
	end_round(&"defenders", "bomb_defused")


func end_round(winner_team: StringName, reason: String) -> void:
	if phase == Phase.ROUND_END:
		return
	if economy != null:
		economy.on_round_ended(winner_team, reason)
	round_ended.emit(winner_team, reason)
	_set_phase(Phase.ROUND_END, post_round_time)


func is_buy_time() -> bool:
	return phase == Phase.FREEZE


func is_live() -> bool:
	return phase == Phase.LIVE or phase == Phase.BOMB_PLANTED


func get_phase_name() -> StringName:
	match phase:
		Phase.WARMUP:
			return &"warmup"
		Phase.FREEZE:
			return &"freeze"
		Phase.LIVE:
			return &"live"
		Phase.BOMB_PLANTED:
			return &"bomb_planted"
		Phase.ROUND_END:
			return &"round_end"
	return &"unknown"


func _set_phase(next_phase: Phase, duration: float) -> void:
	phase = next_phase
	time_left = duration
	phase_changed.emit(get_phase_name())


func _refresh_alive_counts() -> void:
	attackers_alive = 0
	defenders_alive = 0
	for player in get_tree().get_nodes_in_group("player"):
		if player.has_method("is_alive") and not player.is_alive():
			continue
		var team := _get_team(player)
		if team == &"attackers":
			attackers_alive += 1
		elif team == &"defenders":
			defenders_alive += 1

	# The current sandbox only has one player. Default it into attackers so timers still work.
	if attackers_alive == 0 and defenders_alive == 0:
		attackers_alive = 1


func _get_team(player: Node) -> StringName:
	if player.has_method("get_team"):
		return player.get_team()
	var value: Variant = player.get("team")
	return value if value is StringName else &"attackers"


func _is_authority() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
