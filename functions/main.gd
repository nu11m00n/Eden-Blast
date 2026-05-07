extends Node

@onready var enemy_scene: PackedScene = preload("res://enemy.tscn")
@export var starting_weapon: Resource = preload("res://weapons/rifle.tres")
@export var available_weapons: Array[Resource] = [
	preload("res://weapons/pistol.tres"),
	preload("res://weapons/rifle.tres"),
]
var current_weapon: Resource = null

const DEFAULT_FIRE_ANIMATION := "attachment_vm_pi_papa320_mag_skeleton|fire1"
const DEFAULT_RELOAD_ANIMATION := "attachment_vm_pi_papa320_mag_skeleton|reload_empty"
const DEFAULT_DRAW_ANIMATION := "attachment_vm_pi_papa320_mag_skeleton|draw_first"
const DEFAULT_DRAW_EMPTY_ANIMATION := "attachment_vm_pi_papa320_mag_skeleton|draw_empty"
const DEFAULT_IDLE_ANIMATION := "attachment_vm_pi_papa320_mag_skeleton|idle"
const DEFAULT_ADS_ANIMATION := "ads"

var weapon_root: Node3D = null
var weapon_skeleton: Skeleton3D = null
var animplayer: AnimationPlayer = null
var firesound: AudioStreamPlayer = null
var dryFireSound: AudioStreamPlayer = null
var aimcast: RayCast3D = null
var muzzle_socket: Node3D = null
@onready var nuke_animplayer: AnimationPlayer = get_node_or_null("../AnimationPlayer") as AnimationPlayer
var missing_weapon_node_warning_shown := false
var weapon_camera: Camera3D = null
var weapon_mount: Node3D = null
var weapon_viewmodel: Node3D = null
var buy_menu_layer: CanvasLayer = null
var buy_menu_open := false

var player_velocity: Vector3 = Vector3.ZERO
var player_speed: float = 0.0
var player_ducked: bool = false
var player_grounded: bool = false
var previous_player_grounded: bool = false
var debug_menu_open: bool = false


var ammo: int = 0
var reserve_ammo: int = 0
var damage: int = 50
var shots: int = 0
var ads: bool = false
var reload_finished: bool = true
var inspecting: bool = false
var is_nuke: bool = false
var next_fire_time_msec: int = 0
var last_fire_time_msec: int = 0
var current_spread_penalty: float = 0.0
var landing_spread_penalty: float = 0.0
var fire_animation: String = DEFAULT_FIRE_ANIMATION
var reload_animation: String = DEFAULT_RELOAD_ANIMATION
var draw_animation: String = DEFAULT_DRAW_ANIMATION
var draw_empty_animation: String = DEFAULT_DRAW_EMPTY_ANIMATION
var idle_animation: String = DEFAULT_IDLE_ANIMATION
var ads_animation: String = DEFAULT_ADS_ANIMATION


func _ready() -> void:
	add_to_group("weapon_manager")
	_ensure_buy_menu()
	current_weapon = starting_weapon
	_equip_weapon(current_weapon)


func _process(delta: float) -> void:
	var recovery_speed := _weapon_float("spread_recovery_speed", 10.0)
	current_spread_penalty = move_toward(current_spread_penalty, 0.0, recovery_speed * delta)
	landing_spread_penalty = move_toward(landing_spread_penalty, 0.0, recovery_speed * 1.5 * delta)

func _input(event):
	if event.is_action_pressed("buy_menu"):
		if _can_open_buy_menu():
			_toggle_buy_menu()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel"):
		if buy_menu_open:
			_set_buy_menu_open(false)
		else:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not debug_menu_open and not buy_menu_open:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func set_player_movement_state(velocity: Vector3, ducked: bool, grounded: bool) -> void:
	player_velocity = velocity
	player_speed = Vector3(velocity.x, 0.0, velocity.z).length()
	player_ducked = ducked
	var was_grounded := player_grounded
	if grounded and not was_grounded:
		landing_spread_penalty = maxf(landing_spread_penalty, _weapon_float("jump_spread_deg", _weapon_float("air_spread_deg", 4.0)) * 0.45)
	previous_player_grounded = was_grounded
	player_grounded = grounded


func set_debug_menu_open(open: bool) -> void:
	debug_menu_open = open


func spawn_enemy_bot(count: int = 1) -> void:
	var scene_root: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	var player: Node = get_tree().get_first_node_in_group("player")
	var forward: Vector3 = Vector3.FORWARD
	var spawn_origin: Vector3 = Vector3.ZERO

	if player is Node3D and player.is_inside_tree():
		forward = -player.global_transform.basis.z
		spawn_origin = player.global_position

	for i in range(count):
		var enemy: Node = enemy_scene.instantiate()
		if enemy is Node3D:
			var offset: Vector3 = forward * 6.0
			offset += Vector3(randf_range(-2.0, 2.0), 0.0, randf_range(-2.0, 2.0))
			enemy.global_position = spawn_origin + offset
		scene_root.add_child(enemy)


func spawn_enemy_bot_at_crosshair(count: int = 1, distance: float = 40.0) -> void:
	var scene_root: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	var spawn_origin: Vector3 = _get_crosshair_spawn_point(distance)
	var right: Vector3 = Vector3.RIGHT
	var up: Vector3 = Vector3.UP

	if aimcast != null and aimcast.is_inside_tree():
		right = aimcast.global_transform.basis.x
		up = aimcast.global_transform.basis.y

	for i in range(count):
		var enemy: Node = enemy_scene.instantiate()
		var offset: Vector3 = Vector3.ZERO
		if enemy is Node3D:
			var ring: float = 1.5 + (i * 0.5)
			offset = right * randf_range(-ring, ring)
			offset += up * randf_range(-0.5, 0.5)
		scene_root.add_child(enemy)
		if enemy is Node3D:
			enemy.global_position = spawn_origin + offset


func _get_crosshair_spawn_point(distance: float) -> Vector3:
	if aimcast != null and aimcast.is_inside_tree():
		aimcast.force_raycast_update()
		if aimcast.is_colliding():
			return aimcast.get_collision_point()
		return aimcast.global_position + (-aimcast.global_transform.basis.z * distance)

	var player: Node = get_tree().get_first_node_in_group("player")
	if player is Node3D and player.is_inside_tree():
		return player.global_position + (-player.global_transform.basis.z * distance)

	return Vector3.ZERO


func get_weapon_display_name() -> String:
	return _weapon_string("weapon_name", "Weapon")


func get_weapon_magazine_ammo() -> int:
	return ammo


func get_weapon_reserve_ammo() -> int:
	return reserve_ammo


func get_current_spread_degrees() -> float:
	return _get_weapon_spread_degrees()


func get_recoil_index() -> int:
	return shots


func _equip_weapon(weapon: Resource) -> void:
	if weapon == null:
		return

	_unmount_weapon_viewmodel()
	current_weapon = weapon
	_sync_weapon_strings()
	_mount_weapon_viewmodel()
	_cache_weapon_nodes()
	ammo = _weapon_int("starting_magazine_ammo", 0)
	reserve_ammo = _weapon_int("starting_reserve_ammo", 0)
	damage = _weapon_int("damage", 50)
	shots = 0
	next_fire_time_msec = 0
	last_fire_time_msec = 0
	reload_finished = true
	inspecting = false
	ads = false


func _can_fire_weapon() -> bool:
	return Time.get_ticks_msec() >= next_fire_time_msec


func is_current_weapon_automatic() -> bool:
	if current_weapon == null:
		return false
	return bool(current_weapon.get("automatic"))


func _get_weapon_spread_degrees() -> float:
	if current_weapon == null:
		return 0.0

	if player_grounded and (player_ducked or player_speed <= _weapon_float("stop_speed_threshold", 0.0)):
		return maxf(0.0, _weapon_float("crouch_spread_deg", 0.0) if player_ducked else _weapon_float("standing_spread_deg", 0.0)) + current_spread_penalty + landing_spread_penalty

	var spread: float = _weapon_float("base_spread_deg", 0.0)
	if player_grounded:
		spread += _weapon_float("standing_spread_deg", 0.0)
	var move_ratio: float = clampf(player_speed / _weapon_float("movement_speed_reference", 1.0), 0.0, 1.0)
	var counter_strafe_threshold := _weapon_float("counter_strafe_speed_threshold", _weapon_float("stop_speed_threshold", 0.0))
	if player_grounded and player_speed <= counter_strafe_threshold:
		move_ratio *= 0.25
	spread += _weapon_float("move_spread_deg", 0.0) * move_ratio

	if not player_grounded:
		spread += _weapon_float("jump_spread_deg", _weapon_float("air_spread_deg", 0.0))

	if player_ducked:
		spread += _weapon_float("crouch_spread_deg", 0.0)
		spread *= _weapon_float("crouch_spread_multiplier", 1.0)

	if ads:
		spread *= _weapon_float("ads_spread_multiplier", 1.0)

	if player_grounded and player_speed <= _weapon_float("stop_speed_threshold", 0.0):
		spread *= _weapon_float("still_spread_multiplier", 1.0)

	return spread + current_spread_penalty + landing_spread_penalty


func _get_weapon_shot_origin() -> Vector3:
	if aimcast != null and aimcast.is_inside_tree():
		return aimcast.global_position
	if weapon_camera != null and weapon_camera.is_inside_tree():
		return weapon_camera.global_position
	if muzzle_socket != null and muzzle_socket.is_inside_tree():
		return muzzle_socket.global_position
	return Vector3.ZERO


func _get_weapon_shot_direction() -> Vector3:
	if aimcast == null or not aimcast.is_inside_tree():
		if weapon_camera != null and weapon_camera.is_inside_tree():
			return -weapon_camera.global_transform.basis.z
		return -Vector3.FORWARD

	var shot_transform: Transform3D = aimcast.global_transform
	var shot_basis: Basis = shot_transform.basis
	var recoil_offset: Vector2 = _get_weapon_recoil_offset(maxi(shots - 1, 0))
	var spread: float = _get_weapon_spread_degrees()
	var random_yaw: float = randf_range(-spread, spread)
	var random_pitch: float = randf_range(-spread, spread)

	shot_basis = shot_basis.rotated(shot_basis.y, deg_to_rad(recoil_offset.x + random_yaw))
	shot_basis = shot_basis.rotated(shot_basis.x, deg_to_rad(recoil_offset.y + random_pitch))
	return -shot_basis.z


func _get_weapon_muzzle_origin() -> Vector3:
	if muzzle_socket != null and muzzle_socket.is_inside_tree():
		return muzzle_socket.global_position
	if weapon_skeleton != null and weapon_skeleton.is_inside_tree():
		var muzzle_bone_name: StringName = StringName(_weapon_string("muzzle_bone_name", "tag_flash_end_099"))
		var bone_index: int = weapon_skeleton.find_bone(muzzle_bone_name)
		if bone_index != -1:
			weapon_skeleton.force_update_all_bone_transforms()
			var muzzle_transform: Transform3D = weapon_skeleton.global_transform * weapon_skeleton.get_bone_global_pose(bone_index)
			return muzzle_transform.origin
	if aimcast != null and aimcast.is_inside_tree():
		return aimcast.global_position
	return Vector3.ZERO


func _get_weapon_recoil_offset(shot_index: int) -> Vector2:
	var recoil_pattern: Array = _weapon_recoil_pattern()
	if recoil_pattern.is_empty():
		return Vector2.ZERO

	var sustained_random_after := _weapon_int("sustained_random_recoil_after", recoil_pattern.size())
	if shot_index < recoil_pattern.size() and shot_index < sustained_random_after:
		return recoil_pattern[shot_index] as Vector2

	var last_offset: Vector2 = recoil_pattern[recoil_pattern.size() - 1] as Vector2
	var random_side := -1.0 if randf() < 0.5 else 1.0
	var random_yaw := random_side * randf_range(0.45, 1.05) * _weapon_float("horizontal_recoil_variance", 0.2)
	var random_pitch := last_offset.y - randf_range(0.08, 0.22) * _weapon_float("recoil_climb", 0.1)
	return Vector2(random_yaw, random_pitch)


func _spawn_tracer(origin: Vector3, hit_point: Vector3) -> void:
	if current_weapon == null:
		return

	var scene_root: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	if scene_root == null:
		return

	var tracer_root: Node3D = Node3D.new()
	scene_root.add_child(tracer_root)
	tracer_root.global_position = origin
	tracer_root.look_at(hit_point, Vector3.UP)

	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var immediate: ImmediateMesh = ImmediateMesh.new()
	var length: float = maxf(origin.distance_to(hit_point), 0.01)
	immediate.surface_begin(Mesh.PRIMITIVE_LINES)
	immediate.surface_add_vertex(Vector3.ZERO)
	immediate.surface_add_vertex(Vector3(0.0, 0.0, -length))
	immediate.surface_end()
	mesh_instance.mesh = immediate

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = _weapon_color("tracer_color", Color(1.0, 0.9, 0.5, 1.0))
	mesh_instance.material_override = material
	tracer_root.add_child(mesh_instance)
	get_tree().create_timer(_weapon_float("tracer_lifetime", 0.05)).timeout.connect(func() -> void:
		if is_instance_valid(tracer_root):
			tracer_root.queue_free()
	)


func _spawn_impact_decal(hit_point: Vector3, hit_normal: Vector3) -> void:
	if current_weapon == null:
		return

	var decal_texture: Texture2D = _weapon_texture("impact_decal_texture", null)
	if decal_texture == null:
		return

	var scene_root: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	if scene_root == null:
		return

	var decal_root: Node3D = Node3D.new()
	scene_root.add_child(decal_root)
	decal_root.global_position = hit_point + (hit_normal * 0.01)

	var up: Vector3 = Vector3.UP
	if absf(hit_normal.dot(up)) > 0.98:
		up = Vector3.FORWARD
	decal_root.look_at(hit_point + hit_normal, up)
	decal_root.rotate_object_local(Vector3.FORWARD, randf_range(0.0, TAU))

	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var plane_mesh: QuadMesh = QuadMesh.new()
	var decal_size: Vector3 = _weapon_vector3("impact_decal_size", Vector3(0.18, 0.18, 0.18))
	plane_mesh.size = Vector2(decal_size.x, decal_size.y)
	mesh_instance.mesh = plane_mesh
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = decal_texture
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	mesh_instance.material_override = material
	decal_root.add_child(mesh_instance)

	get_tree().create_timer(20.0).timeout.connect(func() -> void:
		if is_instance_valid(decal_root):
			decal_root.queue_free()
	)


func _apply_weapon_hit(origin: Vector3, direction: Vector3) -> Dictionary:
	if current_weapon == null:
		return {}

	var viewport_world: World3D = get_viewport().get_world_3d()
	if viewport_world == null:
		return {}

	var space_state: PhysicsDirectSpaceState3D = viewport_world.direct_space_state
	var weapon_range: float = _weapon_float("weapon_range", 1000.0)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + (direction * weapon_range))
	var player: Node = get_tree().get_first_node_in_group("player")
	if player != null:
		query.exclude = [player]

	var hit: Dictionary = space_state.intersect_ray(query)
	var hit_point: Vector3 = origin + (direction * weapon_range)
	var hit_normal: Vector3 = -direction
	if not hit.is_empty():
		hit_point = hit.get("position", hit_point)
		hit_normal = hit.get("normal", hit_normal)
		var damage_system := get_tree().get_first_node_in_group("damage_system")
		if damage_system != null and damage_system.has_method("apply_hitscan_hit"):
			damage_system.apply_hitscan_hit(hit, get_tree().get_first_node_in_group("player"), current_weapon, direction)
		else:
			var collider: Object = hit.get("collider")
			if collider != null and collider.is_in_group("enemy"):
				collider.health -= _weapon_int("damage", 50)
		var collider_for_decal: Object = hit.get("collider")
		if collider_for_decal == null or not (collider_for_decal is Node and ((collider_for_decal as Node).is_in_group("player") or (collider_for_decal as Node).is_in_group("enemy") or (collider_for_decal as Node).is_in_group("hitbox"))):
			_spawn_impact_decal(hit_point, hit_normal)

	_spawn_tracer(origin, hit_point)
	return {
		"origin": origin,
		"direction": direction,
		"hit_point": hit_point,
		"hit_normal": hit_normal,
		"hit": hit,
	}

func nuke():
	if ads:
		_play_weapon_animation_backwards(ads_animation)
		if nuke_animplayer != null:
			nuke_animplayer.play("tablet")
		is_nuke = true
	else:
		if nuke_animplayer != null:
			nuke_animplayer.play("tablet")
		is_nuke = true

func shoot():
	if is_nuke:
		pass
	else:
		var now_msec := Time.get_ticks_msec()
		if buy_menu_open:
			return
		if not reload_finished or inspecting:
			return

		if not _can_fire_weapon():
			return

		if ammo <= 0:
			if dryFireSound != null:
				dryFireSound.playing = true
			next_fire_time_msec = Time.get_ticks_msec() + int(_weapon_float("fire_delay", 0.25) * 1000.0)
			return

		if last_fire_time_msec > 0 and now_msec - last_fire_time_msec > 350:
			shots = 0
		_stop_weapon_animation()
		_play_weapon_animation(fire_animation)
		if firesound != null:
			firesound.playing = true
		shots += 1
		last_fire_time_msec = now_msec
		ammo -= 1
		current_spread_penalty += _weapon_float("recoil_climb", 0.1) * 0.2
		next_fire_time_msec = now_msec + int(_weapon_float("fire_delay", 0.25) * 1000.0)

		var shot_origin: Vector3 = _get_weapon_shot_origin()
		var shot_direction: Vector3 = _get_weapon_shot_direction()
		_apply_weapon_hit(shot_origin, shot_direction)

func reload():
	if is_nuke:
		pass
	else:
		if buy_menu_open:
			return
		if inspecting:
			pass
		else:
			var needed: int = _weapon_int("magazine_size", 1) - ammo
			if needed <= 0 or reserve_ammo <= 0:
				return

			_play_weapon_animation(reload_animation)
			var loaded: int = int(min(needed, reserve_ammo))
			ammo += loaded
			reserve_ammo -= loaded
			shots = 0
			last_fire_time_msec = 0

func idle():
	if is_nuke:
		pass
	else:
		if animplayer != null and animplayer.is_playing() == false:
			_play_weapon_animation(idle_animation)


func draw():
	if is_nuke:
		pass
	else:	
		if buy_menu_open:
			return
		if ads:
			pass
		elif !reload_finished:
			pass
		else:
			if ammo == 0:
				_stop_weapon_animation()
				_play_weapon_animation(draw_empty_animation)
			else:
				_stop_weapon_animation()
				_play_weapon_animation(draw_animation)

func ads_func():
	if is_nuke:
		pass
	else:
		if buy_menu_open:
			return
		if ads and reload_finished:
			ads = false
			_play_weapon_animation_backwards(ads_animation)
		elif ads and not reload_finished or inspecting:
			pass
		elif not ads and not reload_finished or inspecting:
			pass
		else:
			ads = true
			_play_weapon_animation(ads_animation)


func _on_animplayer_animation_finished(anim_name):
	if anim_name == reload_animation:
		reload_finished = true
	elif anim_name == draw_animation or anim_name == draw_empty_animation:
		inspecting = false



func _on_animplayer_animation_started(anim_name):
	if anim_name == reload_animation:
		reload_finished = false
	elif anim_name == draw_animation or anim_name == draw_empty_animation:
		inspecting = true


func _weapon_int(property_name: StringName, default_value: int) -> int:
	if current_weapon == null:
		return default_value
	var value: Variant = current_weapon.get(property_name)
	if value == null:
		return default_value
	return int(value)


func _weapon_float(property_name: StringName, default_value: float) -> float:
	if current_weapon == null:
		return default_value
	var value: Variant = current_weapon.get(property_name)
	if value == null:
		return default_value
	return float(value)


func _weapon_string(property_name: StringName, default_value: String) -> String:
	if current_weapon == null:
		return default_value
	var value: Variant = current_weapon.get(property_name)
	if value == null:
		return default_value
	return str(value)


func _weapon_color(property_name: StringName, default_value: Color) -> Color:
	if current_weapon == null:
		return default_value
	var value: Variant = current_weapon.get(property_name)
	if value == null:
		return default_value
	return value as Color


func _weapon_texture(property_name: StringName, default_value: Texture2D) -> Texture2D:
	if current_weapon == null:
		return default_value
	var value: Variant = current_weapon.get(property_name)
	if value == null:
		return default_value
	return value as Texture2D


func _weapon_vector3(property_name: StringName, default_value: Vector3) -> Vector3:
	if current_weapon == null:
		return default_value
	var value: Variant = current_weapon.get(property_name)
	if value == null:
		return default_value
	return value as Vector3


func _weapon_recoil_pattern() -> Array:
	if current_weapon == null:
		return []
	var pattern: Array = current_weapon.get("recoil_pattern")
	if pattern == null:
		return []
	return pattern


func _sync_weapon_strings() -> void:
	fire_animation = _weapon_string("fire_animation_name", DEFAULT_FIRE_ANIMATION)
	reload_animation = _weapon_string("reload_animation_name", DEFAULT_RELOAD_ANIMATION)
	draw_animation = _weapon_string("draw_animation_name", DEFAULT_DRAW_ANIMATION)
	draw_empty_animation = _weapon_string("draw_empty_animation_name", DEFAULT_DRAW_EMPTY_ANIMATION)
	idle_animation = _weapon_string("idle_animation_name", DEFAULT_IDLE_ANIMATION)
	ads_animation = _weapon_string("ads_animation_name", DEFAULT_ADS_ANIMATION)


func _cache_weapon_nodes() -> void:
	missing_weapon_node_warning_shown = false
	weapon_root = weapon_viewmodel
	if weapon_root == null:
		weapon_root = _weapon_node("viewmodel_root_path") as Node3D
	if weapon_root == null:
		weapon_root = _find_scene_node(_weapon_string("weapon_name", "Weapon").to_lower()) as Node3D
	weapon_skeleton = _find_weapon_skeleton(weapon_root)
	animplayer = null
	if animplayer == null and weapon_root != null:
		animplayer = weapon_root.get_node_or_null("animplayer") as AnimationPlayer
	if animplayer == null and weapon_root != null:
		animplayer = weapon_root.find_child("animplayer", true, false) as AnimationPlayer
	if animplayer == null:
		animplayer = _weapon_node("animation_player_path") as AnimationPlayer
	_connect_weapon_animation_signals()
	aimcast = null
	if weapon_camera != null:
		aimcast = weapon_camera.get_node_or_null("WeaponRayCast") as RayCast3D
		if aimcast == null:
			aimcast = weapon_camera.get_node_or_null("RayCast3D") as RayCast3D
	if aimcast == null:
		aimcast = _find_scene_node("RayCast3D") as RayCast3D
	if aimcast == null:
		aimcast = _weapon_node("aimcast_path") as RayCast3D
	muzzle_socket = _weapon_node("muzzle_path") as Node3D
	if muzzle_socket == null and weapon_root != null:
		muzzle_socket = weapon_root.get_node_or_null("muzzle") as Node3D
	firesound = _weapon_node("fire_sound_path") as AudioStreamPlayer
	if firesound == null:
		firesound = _find_scene_node("firesound") as AudioStreamPlayer
	dryFireSound = _weapon_node("dry_fire_sound_path") as AudioStreamPlayer
	if dryFireSound == null:
		dryFireSound = _find_scene_node("dryFireSound") as AudioStreamPlayer
	_warn_missing_weapon_nodes()


func buy_weapon(index: int) -> void:
	if index < 0 or index >= available_weapons.size():
		return
	if not _can_open_buy_menu():
		_set_buy_menu_open(false)
		return
	var weapon := available_weapons[index]
	var player := get_tree().get_first_node_in_group("player")
	var economy := get_tree().get_first_node_in_group("economy_manager")
	var cost := int(weapon.get("buy_price"))
	if economy != null and economy.has_method("spend") and not economy.spend(player, cost):
		return
	_equip_weapon(weapon)
	_set_buy_menu_open(false)


func try_pickup_weapon(player: Node, pickup: WeaponPickup) -> bool:
	if player == null or pickup == null or pickup.weapon_data == null:
		return false
	_equip_weapon(pickup.weapon_data)
	if pickup.magazine_ammo > 0:
		ammo = pickup.magazine_ammo
	if pickup.reserve_ammo > 0:
		reserve_ammo = pickup.reserve_ammo
	return true


func drop_current_weapon() -> void:
	if current_weapon == null or weapon_camera == null:
		return
	var pickup := WeaponPickup.new()
	pickup.weapon_data = current_weapon
	pickup.magazine_ammo = ammo
	pickup.reserve_ammo = reserve_ammo
	get_tree().current_scene.add_child(pickup)
	pickup.global_position = weapon_camera.global_position + (-weapon_camera.global_transform.basis.z * 1.2)

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.55
	shape.shape = sphere
	pickup.add_child(shape)

	var marker := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.45, 0.12, 0.9)
	marker.mesh = mesh
	pickup.add_child(marker)


func _can_open_buy_menu() -> bool:
	var round_manager := get_tree().get_first_node_in_group("round_manager")
	if round_manager != null and round_manager.has_method("is_buy_time") and not round_manager.is_buy_time():
		return false
	var player := get_tree().get_first_node_in_group("player")
	var buy_zones := get_tree().get_nodes_in_group("buy_zone")
	if buy_zones.is_empty():
		return true
	for zone in buy_zones:
		if zone.has_method("can_player_buy") and zone.can_player_buy(player):
			return true
	return false


func _mount_weapon_viewmodel() -> void:
	weapon_camera = _resolve_weapon_camera()
	if weapon_camera == null:
		push_warning("No active weapon camera found; cannot mount weapon viewmodel.")
		return

	_clear_legacy_viewmodels(weapon_camera)
	weapon_mount = _ensure_weapon_mount(weapon_camera)
	_clear_legacy_viewmodels(weapon_mount)

	var scene: PackedScene = current_weapon.get("viewmodel_scene") as PackedScene
	if scene == null:
		push_warning("Weapon '%s' has no viewmodel_scene." % _weapon_string("weapon_name", "Weapon"))
		return

	var instance: Node = scene.instantiate()
	if not instance is Node3D:
		instance.queue_free()
		push_warning("Weapon '%s' viewmodel_scene root is not Node3D." % _weapon_string("weapon_name", "Weapon"))
		return

	weapon_viewmodel = instance as Node3D
	weapon_viewmodel.name = _weapon_string("weapon_name", "weapon").to_lower()
	var viewmodel_transform: Variant = current_weapon.get("viewmodel_transform")
	if viewmodel_transform is Transform3D:
		weapon_viewmodel.transform = viewmodel_transform
	weapon_mount.add_child(weapon_viewmodel)
	_ensure_weapon_raycast(weapon_camera)


func _unmount_weapon_viewmodel() -> void:
	if weapon_viewmodel != null and is_instance_valid(weapon_viewmodel):
		if weapon_viewmodel.get_parent() != null:
			weapon_viewmodel.get_parent().remove_child(weapon_viewmodel)
		weapon_viewmodel.queue_free()
	weapon_viewmodel = null
	weapon_root = null
	weapon_skeleton = null
	animplayer = null
	muzzle_socket = null
	weapon_mount = null


func _ensure_weapon_mount(camera: Camera3D) -> Node3D:
	var mount := camera.get_node_or_null("WeaponMount") as Node3D
	if mount == null:
		mount = Node3D.new()
		mount.name = "WeaponMount"
		camera.add_child(mount)
	mount.transform = Transform3D.IDENTITY
	return mount


func _resolve_weapon_camera() -> Camera3D:
	var viewport_camera := get_viewport().get_camera_3d()
	if viewport_camera != null:
		return viewport_camera

	var search_root: Node = get_parent()
	if search_root == null:
		search_root = get_tree().current_scene
	if search_root == null:
		return null

	var current_camera := _find_current_camera(search_root)
	if current_camera != null:
		return current_camera
	return search_root.find_child("Camera3D", true, false) as Camera3D


func _find_current_camera(root: Node) -> Camera3D:
	if root is Camera3D:
		var camera := root as Camera3D
		if camera.current:
			return camera
	for child in root.get_children():
		var found := _find_current_camera(child)
		if found != null:
			return found
	return null


func _clear_legacy_viewmodels(camera: Node) -> void:
	for child in camera.get_children():
		var child_name := String(child.name).to_lower()
		if child_name == "pistol" or child_name == "rifle":
			camera.remove_child(child)
			child.queue_free()


func _ensure_weapon_raycast(camera: Camera3D) -> void:
	var raycast := camera.get_node_or_null("WeaponRayCast") as RayCast3D
	if raycast == null:
		raycast = RayCast3D.new()
		raycast.name = "WeaponRayCast"
		camera.add_child(raycast)
	raycast.target_position = Vector3(0.0, 0.0, -_weapon_float("weapon_range", 3500.0))


func _ensure_buy_menu() -> void:
	if buy_menu_layer != null:
		return

	buy_menu_layer = CanvasLayer.new()
	buy_menu_layer.name = "BuyMenu"
	buy_menu_layer.layer = 50
	buy_menu_layer.visible = false
	add_child(buy_menu_layer)

	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(0.0, 0.0, 0.0, 0.45)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	buy_menu_layer.add_child(backdrop)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(360.0, 0.0)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -180.0
	panel.offset_top = -160.0
	panel.offset_right = 180.0
	panel.offset_bottom = 160.0
	buy_menu_layer.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var list := VBoxContainer.new()
	list.name = "WeaponList"
	list.add_theme_constant_override("separation", 10)
	margin.add_child(list)

	var title := Label.new()
	title.text = "Buy Menu"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	list.add_child(title)

	for index in range(available_weapons.size()):
		var weapon := available_weapons[index]
		if weapon == null:
			continue
		var button := Button.new()
		button.text = "%s  $%d" % [str(weapon.get("weapon_name")), int(weapon.get("buy_price"))]
		button.custom_minimum_size = Vector2(0.0, 44.0)
		button.pressed.connect(buy_weapon.bind(index))
		list.add_child(button)

	var hint := Label.new()
	hint.text = "Press B or Esc to close"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	list.add_child(hint)


func _toggle_buy_menu() -> void:
	_set_buy_menu_open(not buy_menu_open)


func _set_buy_menu_open(open: bool) -> void:
	buy_menu_open = open
	if buy_menu_layer != null:
		buy_menu_layer.visible = open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED


func _play_weapon_animation(animation_name: String) -> void:
	if animation_name.is_empty():
		return
	if animplayer == null:
		_warn_missing_weapon_nodes()
		return
	if not animplayer.has_animation(animation_name):
		push_warning("Weapon animation '%s' is missing on %s." % [animation_name, animplayer.get_path()])
		return
	animplayer.play(animation_name)


func _play_weapon_animation_backwards(animation_name: String) -> void:
	if animation_name.is_empty():
		return
	if animplayer == null:
		_warn_missing_weapon_nodes()
		return
	if not animplayer.has_animation(animation_name):
		push_warning("Weapon animation '%s' is missing on %s." % [animation_name, animplayer.get_path()])
		return
	animplayer.play_backwards(animation_name)


func _stop_weapon_animation() -> void:
	if animplayer != null:
		animplayer.stop()


func _warn_missing_weapon_nodes() -> void:
	if missing_weapon_node_warning_shown:
		return
	if weapon_root != null and animplayer != null and aimcast != null and firesound != null and dryFireSound != null:
		return

	missing_weapon_node_warning_shown = true
	push_warning("Weapon nodes not fully cached. root=%s animplayer=%s aimcast=%s firesound=%s dryFireSound=%s" % [
		_get_node_path_or_null(weapon_root),
		_get_node_path_or_null(animplayer),
		_get_node_path_or_null(aimcast),
		_get_node_path_or_null(firesound),
		_get_node_path_or_null(dryFireSound),
	])


func _get_node_path_or_null(node: Node) -> String:
	if node == null:
		return "<null>"
	return str(node.get_path())


func _find_scene_node(node_name: String) -> Node:
	var search_root: Node = get_parent()
	if search_root == null:
		search_root = get_tree().current_scene
	if search_root == null:
		return null
	return search_root.find_child(node_name, true, false)


func _connect_weapon_animation_signals() -> void:
	if animplayer == null:
		return

	var finished_callback := Callable(self, "_on_animplayer_animation_finished")
	if not animplayer.animation_finished.is_connected(finished_callback):
		animplayer.animation_finished.connect(finished_callback)

	var started_callback := Callable(self, "_on_animplayer_animation_started")
	if not animplayer.animation_started.is_connected(started_callback):
		animplayer.animation_started.connect(started_callback)


func _find_weapon_skeleton(root: Node) -> Skeleton3D:
	if root == null:
		return null

	if root is Skeleton3D:
		return root

	for child in root.get_children():
		var found: Skeleton3D = _find_weapon_skeleton(child)
		if found != null:
			return found

	return null


func _weapon_node(property_name: StringName) -> Node:
	if current_weapon == null:
		return null

	var value: Variant = current_weapon.get(property_name)
	if value == null:
		return null

	var path: NodePath = NodePath()
	if value is NodePath:
		path = value
	elif value is String:
		path = NodePath(value)
	elif value is StringName:
		path = NodePath(String(value))
	else:
		return null

	return get_node_or_null(path)
