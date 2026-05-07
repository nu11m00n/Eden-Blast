extends GoldGdt_Body

@onready var main = $"../main"

@export var team: StringName = &"attackers"
@export var health := 100
@export var armor := 0
@export var has_helmet := false
@export var peer_id := 1


func _ready() -> void:
	add_to_group("player")
	add_to_group("damageable")
	add_to_group("round_reset")
	super._ready()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	main.set_player_movement_state(velocity, ducked, is_on_floor())

	if Input.is_action_pressed("fire") and main.is_current_weapon_automatic():
		main.shoot()
	elif Input.is_action_just_pressed("fire"):
		main.shoot()
	if Input.is_action_just_pressed("reload"):
		main.reload()
	if Input.is_action_just_pressed("ads"):
		main.ads_func()
	if Input.is_action_just_pressed("inspect"):
		main.draw()
	if Input.is_action_just_pressed("drop_weapon"):
		main.drop_current_weapon()
	if Input.is_action_just_pressed("use_objective"):
		_try_use_objective()

	main.idle()


func apply_damage(amount: int, _direction: Vector3 = Vector3.ZERO) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	health = maxi(0, health - amount)
	if health <= 0:
		set_physics_process(false)
		visible = false


func is_alive() -> bool:
	return health > 0


func get_team() -> StringName:
	return team


func reset_for_round() -> void:
	health = 100
	set_physics_process(true)
	visible = true


func _try_use_objective() -> void:
	for site in get_tree().get_nodes_in_group("bomb_site"):
		if site.has_method("try_begin_plant") and site.try_begin_plant(self):
			return
	var bomb := get_tree().get_first_node_in_group("bomb")
	if bomb != null and bomb.has_method("begin_defuse"):
		bomb.begin_defuse(self)
