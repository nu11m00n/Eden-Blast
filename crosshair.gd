extends Control
class_name CS2Crosshair

@export var line_color := Color(0.22, 1.0, 0.45, 1.0)
@export var outline_color := Color(0.0, 0.0, 0.0, 0.85)
@export var use_outline := true

@export var base_gap := 6.0
@export var line_length := 8.0
@export var line_thickness := 2.0
@export var outline_size := 1.0

@export var show_center_dot := false
@export var dot_size := 1.0

@export var movement_gap := 5.0
@export var airborne_gap := 3.0
@export var crouch_gap_multiplier := 0.8
@export var ads_gap_multiplier := 0.55
@export var movement_speed_divisor := 10.0

@export var fire_recoil_bump := 2.0
@export var fire_recoil_decay := 10.0
@export var spread_smoothing := 18.0

var _target_spread_gap := 0.0
var _current_spread_gap := 0.0
var _fire_spread := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _process(delta: float) -> void:
	_current_spread_gap = move_toward(_current_spread_gap, _target_spread_gap, spread_smoothing * delta)
	_fire_spread = move_toward(_fire_spread, 0.0, fire_recoil_decay * delta)
	queue_redraw()


func set_tactical_state(speed: float, grounded: bool, ducked: bool, ads: bool) -> void:
	var normalized_speed: float = clamp(speed / movement_speed_divisor, 0.0, 1.0)
	var target: float = movement_gap * normalized_speed

	if not grounded:
		target += airborne_gap

	if ducked:
		target *= crouch_gap_multiplier

	if ads:
		target *= ads_gap_multiplier

	_target_spread_gap = target


func add_fire_recoil(amount: float = 1.0) -> void:
	_fire_spread = min(_fire_spread + fire_recoil_bump * amount, fire_recoil_bump * 4.0)


func _draw() -> void:
	var center := size * 0.5
	var gap := base_gap + _current_spread_gap + _fire_spread
	var thickness := maxf(line_thickness, 1.0)
	var outline := maxf(outline_size, 0.0)
	var half_thickness := thickness * 0.5

	_draw_bar(Vector2(center.x - gap - line_length, center.y - half_thickness), Vector2(line_length, thickness), outline)
	_draw_bar(Vector2(center.x + gap, center.y - half_thickness), Vector2(line_length, thickness), outline)
	_draw_bar(Vector2(center.x - half_thickness, center.y - gap - line_length), Vector2(thickness, line_length), outline)
	_draw_bar(Vector2(center.x - half_thickness, center.y + gap), Vector2(thickness, line_length), outline)

	if show_center_dot:
		var dot_extent := maxf(dot_size, 1.0)
		_draw_bar(Vector2(center.x - dot_extent * 0.5, center.y - dot_extent * 0.5), Vector2(dot_extent, dot_extent), outline)


func _draw_bar(rect_position: Vector2, extent: Vector2, outline: float) -> void:
	var rect := Rect2(rect_position, extent)
	if use_outline and outline > 0.0:
		draw_rect(rect.grow(outline), outline_color)
	draw_rect(rect, line_color)
