extends Control

@onready var frame0 = $Hud
@onready var button = $Label
@onready var frame1 = $Hud2
@onready var crosshair: CS2Crosshair = $Crosshair
@onready var main = $"../main"
@onready var animplayer = $"../AnimationPlayer"
@onready var ui_animplayer = $"../nuke/AnimationPlayer"
@onready var audio = $"../nuke/AudioStreamPlayer"
@onready var vid = $"../CharacterBody3D/Horizontal View/Vertical View/Camera Mount/Camera3D/tablet/Sketchfab_model/root/GLTF_SceneRootNode/ekran_3/Object_10/SubViewport/VideoStreamPlayer"

var _last_shots := 0
var _ammo_label: Label

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	frame0.visible = false
	button.visible = false
	frame1.visible = false
	_last_shots = main.shots
	crosshair.set_tactical_state(main.player_speed, main.player_grounded, main.player_ducked, main.ads)

	_ammo_label = Label.new()
	_ammo_label.position = Vector2(24.0, 24.0)
	_ammo_label.add_theme_font_size_override("font_size", 22)
	_ammo_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))
	_ammo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ammo_label)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if Input.is_action_just_pressed("HUD"):
		frame0.visible = true
		button.visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if Input.is_action_just_released("HUD"):
		frame0.visible = false
		button.visible = false
		frame1.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	crosshair.set_tactical_state(main.player_speed, main.player_grounded, main.player_ducked, main.ads)
	if main.shots > _last_shots:
		crosshair.add_fire_recoil(main.shots - _last_shots)
	_last_shots = main.shots
	if _ammo_label != null:
		_ammo_label.text = "%s  %d / %d" % [main.get_weapon_display_name(), main.get_weapon_magazine_ammo(), main.get_weapon_reserve_ammo()]



func _on_label_mouse_entered() -> void:
	if button.visible == true:
		frame1.visible = true
		frame0.visible = false


func _on_label_mouse_exited() -> void:
	if button.visible == true:
		frame1.visible = false
		frame0.visible = true
		main.nuke()


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "tablet":
		animplayer.play("plane")
		ui_animplayer.play("nuke")
		audio.play()
	if anim_name == "plane":
		animplayer.play("nuke")


func _on_animation_player_animation_started(anim_name: StringName) -> void:
	if anim_name == "tablet":
		vid.play()
