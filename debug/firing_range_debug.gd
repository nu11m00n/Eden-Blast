class_name FiringRangeDebug
extends CanvasLayer

@export var enabled := true
@export var update_interval := 0.1

var _label: Label
var _timer := 0.0


func _ready() -> void:
	visible = enabled
	layer = 80
	_label = Label.new()
	_label.position = Vector2(18.0, 120.0)
	_label.add_theme_font_size_override("font_size", 14)
	add_child(_label)


func _process(delta: float) -> void:
	if not enabled:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = update_interval

	var main := get_tree().get_first_node_in_group("weapon_manager")
	var player := get_tree().get_first_node_in_group("player")
	if main == null:
		_label.text = "Weapon debug: no weapon manager"
		return

	var lines: Array[String] = []
	lines.append("Weapon: %s" % main.get_weapon_display_name())
	lines.append("Ammo: %d / %d" % [main.get_weapon_magazine_ammo(), main.get_weapon_reserve_ammo()])
	if main.has_method("get_current_spread_degrees"):
		lines.append("Spread: %.3f deg" % main.get_current_spread_degrees())
	if main.has_method("get_recoil_index"):
		lines.append("Recoil index: %d" % main.get_recoil_index())
	if player != null:
		var velocity: Variant = player.get("velocity")
		if velocity is Vector3:
			lines.append("Velocity: %.2f" % Vector3(velocity.x, 0.0, velocity.z).length())
		if player.has_method("is_on_floor"):
			lines.append("Grounded: %s" % str(player.is_on_floor()))
		var ducked: Variant = player.get("ducked")
		if ducked != null:
			lines.append("Crouched: %s" % str(ducked))
	_label.text = "\n".join(lines)
