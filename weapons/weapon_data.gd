class_name WeaponData

extends Resource

@export var weapon_name := "Weapon"
@export var viewmodel_root_path := NodePath()
@export var animation_player_path := NodePath()
@export var aimcast_path := NodePath()
@export var muzzle_path := NodePath()
@export var muzzle_bone_name := "tag_flash_end_099"
@export var fire_sound_path := NodePath()
@export var dry_fire_sound_path := NodePath()

@export var fire_animation_name := "attachment_vm_pi_papa320_mag_skeleton|fire1"
@export var reload_animation_name := "attachment_vm_pi_papa320_mag_skeleton|reload_empty"
@export var draw_animation_name := "attachment_vm_pi_papa320_mag_skeleton|draw_first"
@export var draw_empty_animation_name := "attachment_vm_pi_papa320_mag_skeleton|draw_empty"
@export var idle_animation_name := "attachment_vm_pi_papa320_mag_skeleton|idle"
@export var ads_animation_name := "ads"

@export var magazine_size := 1
@export var starting_magazine_ammo := 1
@export var starting_reserve_ammo := 0
@export var damage := 1
@export var weapon_range := 1000.0
@export var fire_delay := 0.25
@export var reload_time := 1.0

@export var base_spread_deg := 0.0
@export var move_spread_deg := 2.0
@export var air_spread_deg := 4.0
@export var crouch_spread_multiplier := 0.6
@export var ads_spread_multiplier := 0.4
@export var still_spread_multiplier := 0.2
@export var movement_speed_reference := 6.0
@export var stop_speed_threshold := 0.1

@export var recoil_pattern: Array[Vector2] = []

@export var impact_decal_texture: Texture2D
@export var impact_decal_size := Vector3(0.18, 0.18, 0.18)

@export var tracer_color := Color(1.0, 0.9, 0.5, 1.0)
@export var tracer_lifetime := 0.05
