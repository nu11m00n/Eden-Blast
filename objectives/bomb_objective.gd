class_name BombObjective
extends Node3D

signal state_changed(state: StringName)

enum State { CARRIED, DROPPED, PLANTED, DEFUSING, DEFUSED, EXPLODED }

@export var plant_time := 3.0
@export var defuse_time := 5.0
@export var planted_site := ""

var state: State = State.CARRIED
var carrier: Node = null
var _interactor: Node = null
var _interaction_time := 0.0
var _interaction_target := 0.0


func _ready() -> void:
	add_to_group("bomb")
	add_to_group("round_reset")


func _process(delta: float) -> void:
	if _interactor == null:
		return
	_interaction_time += delta
	if _interaction_time < _interaction_target:
		return
	if state == State.CARRIED:
		plant(_interactor)
	elif state == State.DEFUSING:
		defuse(_interactor)


func begin_plant(player: Node, site_name: String) -> void:
	if state != State.CARRIED or carrier != player:
		return
	planted_site = site_name
	_interactor = player
	_interaction_time = 0.0
	_interaction_target = plant_time


func begin_defuse(player: Node) -> void:
	if state != State.PLANTED:
		return
	state = State.DEFUSING
	_interactor = player
	_interaction_time = 0.0
	_interaction_target = defuse_time
	state_changed.emit(&"defusing")


func cancel_interaction(player: Node) -> void:
	if _interactor != player:
		return
	if state == State.DEFUSING:
		state = State.PLANTED
		state_changed.emit(&"planted")
	_interactor = null
	_interaction_time = 0.0


func plant(player: Node) -> void:
	state = State.PLANTED
	carrier = null
	_interactor = null
	state_changed.emit(&"planted")
	var round_manager := get_tree().get_first_node_in_group("round_manager")
	if round_manager != null and round_manager.has_method("notify_bomb_planted"):
		round_manager.notify_bomb_planted(player)


func defuse(player: Node) -> void:
	state = State.DEFUSED
	_interactor = null
	state_changed.emit(&"defused")
	var round_manager := get_tree().get_first_node_in_group("round_manager")
	if round_manager != null and round_manager.has_method("notify_bomb_defused"):
		round_manager.notify_bomb_defused(player)


func drop_at(world_position: Vector3) -> void:
	state = State.DROPPED
	carrier = null
	global_position = world_position
	visible = true
	state_changed.emit(&"dropped")


func pick_up(player: Node) -> void:
	if state != State.DROPPED and state != State.CARRIED:
		return
	state = State.CARRIED
	carrier = player
	visible = false
	state_changed.emit(&"carried")


func reset_for_round() -> void:
	state = State.CARRIED
	_interactor = null
	_interaction_time = 0.0
	planted_site = ""
	visible = false
	var players := get_tree().get_nodes_in_group("player")
	carrier = players[0] if not players.is_empty() else null
	state_changed.emit(&"carried")
