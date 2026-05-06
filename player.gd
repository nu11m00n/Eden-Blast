extends GoldGdt_Body

@onready var main = $"../main"


func _ready() -> void:
	add_to_group("player")
	super._ready()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	main.set_player_movement_state(velocity, ducked, is_on_floor())

	if Input.is_action_just_pressed("fire"):
		main.shoot()
	if Input.is_action_just_pressed("reload"):
		main.reload()
	if Input.is_action_just_pressed("ads"):
		main.ads_func()
	if Input.is_action_just_pressed("inspect"):
		main.draw()

	main.idle()
