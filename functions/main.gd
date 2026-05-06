extends Node

@onready var enemy_scene: PackedScene = preload("res://enemy.tscn")
@export var starting_weapon: Resource = preload("res://weapons/pistol.tres")
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
@onready var nuke_animplayer = $"../AnimationPlayer"

var player_velocity: Vector3 = Vector3.ZERO
var player_speed: float = 0.0
var player_ducked: bool = false
var player_grounded: bool = false
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
var fire_animation: String = DEFAULT_FIRE_ANIMATION
var reload_animation: String = DEFAULT_RELOAD_ANIMATION
var draw_animation: String = DEFAULT_DRAW_ANIMATION
var draw_empty_animation: String = DEFAULT_DRAW_EMPTY_ANIMATION
var idle_animation: String = DEFAULT_IDLE_ANIMATION
var ads_animation: String = DEFAULT_ADS_ANIMATION


func _ready() -> void:
	current_weapon = starting_weapon
	_equip_weapon(current_weapon)

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not debug_menu_open:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func set_player_movement_state(velocity: Vector3, ducked: bool, grounded: bool) -> void:
	player_velocity = velocity
	player_speed = Vector3(velocity.x, 0.0, velocity.z).length()
	player_ducked = ducked
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


func _equip_weapon(weapon: Resource) -> void:
	if weapon == null:
		return

	current_weapon = weapon
	_sync_weapon_strings()
	_cache_weapon_nodes()
	ammo = _weapon_int("starting_magazine_ammo", 0)
	reserve_ammo = _weapon_int("starting_reserve_ammo", 0)
	damage = _weapon_int("damage", 50)
	shots = 0
	next_fire_time_msec = 0


func _can_fire_weapon() -> bool:
	return Time.get_ticks_msec() >= next_fire_time_msec


func _get_weapon_spread_degrees() -> float:
	if current_weapon == null:
		return 0.0

	var spread: float = _weapon_float("base_spread_deg", 0.0)
	var move_ratio: float = clampf(player_speed / _weapon_float("movement_speed_reference", 1.0), 0.0, 1.0)
	spread += _weapon_float("move_spread_deg", 0.0) * move_ratio

	if not player_grounded:
		spread += _weapon_float("air_spread_deg", 0.0)

	if player_ducked:
		spread *= _weapon_float("crouch_spread_multiplier", 1.0)

	if ads:
		spread *= _weapon_float("ads_spread_multiplier", 1.0)

	if player_grounded and player_speed <= _weapon_float("stop_speed_threshold", 0.0):
		spread *= _weapon_float("still_spread_multiplier", 1.0)

	return spread


func _get_weapon_shot_direction() -> Vector3:
	if aimcast == null or not aimcast.is_inside_tree():
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


func _get_weapon_shot_origin() -> Vector3:
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


func _apply_weapon_hit(origin: Vector3, direction: Vector3) -> void:
	if current_weapon == null:
		return

	var viewport_world: World3D = get_viewport().get_world_3d()
	if viewport_world == null:
		return

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
		var collider: Object = hit.get("collider")
		if collider != null and collider.is_in_group("enemy"):
			collider.health -= _weapon_int("damage", 50)
		else:
			_spawn_impact_decal(hit_point, hit_normal)

	_spawn_tracer(origin, hit_point)

func nuke():
	if ads:
		animplayer.play_backwards(ads_animation)
		nuke_animplayer.play("tablet")
		is_nuke = true
	else:
		nuke_animplayer.play("tablet")
		is_nuke = true

func shoot():
	if is_nuke:
		pass
	else:
		if not reload_finished or inspecting:
			return

		if not _can_fire_weapon():
			return

		if ammo <= 0:
			dryFireSound.playing = true
			next_fire_time_msec = Time.get_ticks_msec() + int(_weapon_float("fire_delay", 0.25) * 1000.0)
			return

		animplayer.stop()
		animplayer.play(fire_animation)
		firesound.playing = true
		shots += 1
		ammo -= 1
		next_fire_time_msec = Time.get_ticks_msec() + int(_weapon_float("fire_delay", 0.25) * 1000.0)

		var shot_origin: Vector3 = _get_weapon_shot_origin()
		var shot_direction: Vector3 = _get_weapon_shot_direction()
		_apply_weapon_hit(shot_origin, shot_direction)

func reload():
	if is_nuke:
		pass
	else:
		if inspecting:
			pass
		else:
			var needed: int = _weapon_int("magazine_size", 1) - ammo
			if needed <= 0 or reserve_ammo <= 0:
				return

			animplayer.play(reload_animation)
			var loaded: int = int(min(needed, reserve_ammo))
			ammo += loaded
			reserve_ammo -= loaded
			shots = 0

func idle():
	if is_nuke:
		pass
	else:
		if animplayer.is_playing() == false:
			animplayer.play(idle_animation)


func draw():
	if is_nuke:
		pass
	else:	
		if ads:
			pass
		elif !reload_finished:
			pass
		else:
			if ammo == 0:
				animplayer.stop()
				animplayer.play(draw_empty_animation)
			else:
				animplayer.stop()
				animplayer.play(draw_animation)

func ads_func():
	if is_nuke:
		pass
	else:
		if ads and reload_finished:
			ads = false
			animplayer.play_backwards(ads_animation)
		elif ads and not reload_finished or inspecting:
			pass
		elif not ads and not reload_finished or inspecting:
			pass
		else:
			ads = true
			animplayer.play(ads_animation)


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


func _get_weapon_recoil_offset(shot_index: int) -> Vector2:
	var recoil_pattern: Array = _weapon_recoil_pattern()
	if recoil_pattern.is_empty():
		return Vector2.ZERO

	var clamped_index: int = clampi(shot_index, 0, recoil_pattern.size() - 1)
	return recoil_pattern[clamped_index] as Vector2


func _sync_weapon_strings() -> void:
	fire_animation = _weapon_string("fire_animation_name", DEFAULT_FIRE_ANIMATION)
	reload_animation = _weapon_string("reload_animation_name", DEFAULT_RELOAD_ANIMATION)
	draw_animation = _weapon_string("draw_animation_name", DEFAULT_DRAW_ANIMATION)
	draw_empty_animation = _weapon_string("draw_empty_animation_name", DEFAULT_DRAW_EMPTY_ANIMATION)
	idle_animation = _weapon_string("idle_animation_name", DEFAULT_IDLE_ANIMATION)
	ads_animation = _weapon_string("ads_animation_name", DEFAULT_ADS_ANIMATION)


func _cache_weapon_nodes() -> void:
	weapon_root = _weapon_node("viewmodel_root_path") as Node3D
	weapon_skeleton = _find_weapon_skeleton(weapon_root)
	animplayer = _weapon_node("animation_player_path") as AnimationPlayer
	aimcast = _weapon_node("aimcast_path") as RayCast3D
	muzzle_socket = _weapon_node("muzzle_path") as Node3D
	firesound = _weapon_node("fire_sound_path") as AudioStreamPlayer
	dryFireSound = _weapon_node("dry_fire_sound_path") as AudioStreamPlayer


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
