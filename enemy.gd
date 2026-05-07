extends RigidBody3D

@export var health: int = 200
@export var max_speed: float = 5.5
@export var acceleration: float = 18.0
@export var turn_speed: float = 8.0
@export var preferred_distance: float = 7.5
@export var close_distance: float = 4.0
@export var strafe_speed: float = 4.0
@export var chase_speed: float = 2.75
@export var retreat_speed: float = 2.0
@export var strafe_interval_min: float = 0.75
@export var strafe_interval_max: float = 1.4
@export var target_group: StringName = &"player"

var _target: Node3D
var _strafe_sign: float = 1.0
var _strafe_timer: float = 0.0


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("damageable")
	randomize()
	can_sleep = false
	axis_lock_angular_x = true
	axis_lock_angular_z = true
	_pick_new_strafe_direction()


func apply_damage(amount: int, _direction: Vector3 = Vector3.ZERO) -> void:
	health -= amount


func _physics_process(delta: float) -> void:
	if health <= 0:
		queue_free()
		return

	_acquire_target()
	if _target == null:
		_apply_brake(delta)
		return

	_update_strafe_timer(delta)

	var to_target := _target.global_position - global_position
	var flat_to_target := Vector3(to_target.x, 0.0, to_target.z)
	var distance := flat_to_target.length()

	if distance < 0.001:
		_apply_brake(delta)
		return

	var direction := flat_to_target / distance
	var desired_yaw := atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, desired_yaw, turn_speed * delta)

	var view_basis := Basis(Vector3.UP, rotation.y)
	var right := view_basis.x
	var forward := -view_basis.z
	var desired := Vector3.ZERO

	if distance > preferred_distance * 1.15:
		desired += forward * chase_speed
	elif distance < close_distance:
		desired -= forward * retreat_speed

	desired += right * _strafe_sign * strafe_speed

	if desired.length() > max_speed:
		desired = desired.normalized() * max_speed

	var current_horizontal := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	var blended_horizontal := current_horizontal.move_toward(desired, acceleration * delta)
	linear_velocity.x = blended_horizontal.x
	linear_velocity.z = blended_horizontal.z


func _acquire_target() -> void:
	if is_instance_valid(_target):
		return

	var candidate := get_tree().get_first_node_in_group(target_group)
	if candidate is Node3D:
		_target = candidate
	else:
		_target = null


func _update_strafe_timer(delta: float) -> void:
	_strafe_timer -= delta
	if _strafe_timer <= 0.0:
		_pick_new_strafe_direction()


func _pick_new_strafe_direction() -> void:
	_strafe_sign = -1.0 if _strafe_sign > 0.0 else 1.0
	_strafe_timer = randf_range(strafe_interval_min, strafe_interval_max)


func _apply_brake(delta: float) -> void:
	var current_horizontal := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	var stopped := current_horizontal.move_toward(Vector3.ZERO, acceleration * delta)
	linear_velocity.x = stopped.x
	linear_velocity.z = stopped.z
