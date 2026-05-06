extends Control

const SETTINGS_PATH := "user://debug_settings.cfg"
const CROSSHAIR_SECTION := "crosshair"
const MOUSE_SECTION := "mouse"

@onready var crosshair: CS2Crosshair = $"../Crosshair"
@onready var player_body: GoldGdt_Body = get_tree().get_first_node_in_group("player") as GoldGdt_Body
@onready var main = $"../../main"

var _panel: PanelContainer
var _spawn_count: SpinBox
var _cursor_overlay: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_load_settings()
	_build_ui()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if main != null:
		main.set_debug_menu_open(false)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		_set_visible_state(not visible)
		accept_event()


func _process(_delta: float) -> void:
	if visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if _cursor_overlay != null:
			var mouse_position: Vector2 = get_viewport().get_mouse_position()
			_cursor_overlay.position = mouse_position - (_cursor_overlay.custom_minimum_size * 0.5)
			_cursor_overlay.visible = true
	else:
		if _cursor_overlay != null:
			_cursor_overlay.visible = false


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(24.0, 24.0)
	_panel.custom_minimum_size = Vector2(360.0, 0.0)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var title := Label.new()
	title.text = "Debug Menu  F3"
	title.add_theme_font_size_override("font_size", 20)
	root.add_child(title)

	root.add_child(_make_separator())
	root.add_child(_make_label("Bots"))
	_spawn_count = _make_spinbox(1.0, 1.0, 16.0, 1.0)
	root.add_child(_make_labeled_row("Count", _spawn_count))
	root.add_child(_make_button("Spawn Bot(s)", _on_spawn_pressed))

	root.add_child(_make_separator())
	root.add_child(_make_label("Crosshair"))
	root.add_child(_make_color_row("Line Color", "line_color"))
	root.add_child(_make_color_row("Outline Color", "outline_color"))
	root.add_child(_make_bool_row("Use Outline", "use_outline"))
	root.add_child(_make_bool_row("Center Dot", "show_center_dot"))
	root.add_child(_make_float_row("Base Gap", "base_gap", 0.0, 30.0, 0.5))
	root.add_child(_make_float_row("Line Length", "line_length", 0.0, 30.0, 0.5))
	root.add_child(_make_float_row("Thickness", "line_thickness", 1.0, 10.0, 0.25))
	root.add_child(_make_float_row("Outline Size", "outline_size", 0.0, 5.0, 0.25))
	root.add_child(_make_float_row("Dot Size", "dot_size", 0.0, 8.0, 0.25))
	root.add_child(_make_float_row("Move Gap", "movement_gap", 0.0, 20.0, 0.25))
	root.add_child(_make_float_row("Air Gap", "airborne_gap", 0.0, 20.0, 0.25))
	root.add_child(_make_float_row("ADS Mult", "ads_gap_multiplier", 0.1, 1.0, 0.01))
	root.add_child(_make_float_row("Recoil Bump", "fire_recoil_bump", 0.0, 10.0, 0.1))
	root.add_child(_make_float_row("Recoil Decay", "fire_recoil_decay", 0.0, 30.0, 0.25))
	root.add_child(_make_separator())
	root.add_child(_make_label("Mouse"))
	root.add_child(_make_player_float_row("Sensitivity", "MOUSE_SENSITIVITY", 0.05, 10.0, 0.01))

	_cursor_overlay = ColorRect.new()
	_cursor_overlay.visible = false
	_cursor_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor_overlay.color = Color(1.0, 1.0, 1.0, 0.9)
	_cursor_overlay.custom_minimum_size = Vector2(10.0, 16.0)
	_cursor_overlay.z_index = 1000
	add_child(_cursor_overlay)

	_sync_from_crosshair()


func _sync_from_crosshair() -> void:
	_spawn_count.value = 1.0


func _make_separator() -> HSeparator:
	return HSeparator.new()


func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _make_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	return button


func _make_labeled_row(label_text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(140.0, 0.0)
	row.add_child(label)
	row.add_child(control)
	return row


func _make_spinbox(initial: float, minimum: float, maximum: float, step: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.value = initial
	spin.custom_minimum_size = Vector2(120.0, 0.0)
	return spin


func _make_float_row(label_text: String, property_name: StringName, minimum: float, maximum: float, step: float) -> HBoxContainer:
	var current_value: Variant = crosshair.get(property_name)
	var spin: SpinBox = _make_spinbox(float(current_value), minimum, maximum, step)
	spin.value_changed.connect(_on_float_changed.bind(property_name))
	return _make_labeled_row(label_text, spin)


func _make_bool_row(label_text: String, property_name: StringName) -> HBoxContainer:
	var check: CheckButton = CheckButton.new()
	check.button_pressed = bool(crosshair.get(property_name))
	check.toggled.connect(_on_bool_toggled.bind(property_name))
	return _make_labeled_row(label_text, check)


func _make_color_row(label_text: String, property_name: StringName) -> HBoxContainer:
	var picker: ColorPickerButton = ColorPickerButton.new()
	picker.color = crosshair.get(property_name)
	picker.color_changed.connect(_on_color_changed.bind(property_name))
	return _make_labeled_row(label_text, picker)


func _make_player_float_row(label_text: String, property_name: StringName, minimum: float, maximum: float, step: float) -> HBoxContainer:
	var parameters: PlayerParameters = _get_player_parameters()
	var initial: float = 1.0
	if parameters != null:
		var parameter_value: Variant = parameters.get(property_name)
		initial = float(parameter_value)
	var spin: SpinBox = _make_spinbox(initial, minimum, maximum, step)
	spin.value_changed.connect(_on_player_float_changed.bind(property_name))
	return _make_labeled_row(label_text, spin)


func _on_float_changed(value: float, property_name: StringName) -> void:
	crosshair.set(property_name, value)
	_save_settings()


func _on_bool_toggled(pressed: bool, property_name: StringName) -> void:
	crosshair.set(property_name, pressed)
	_save_settings()


func _on_color_changed(color: Color, property_name: StringName) -> void:
	crosshair.set(property_name, color)
	_save_settings()


func _on_player_float_changed(value: float, property_name: StringName) -> void:
	var parameters: PlayerParameters = _get_player_parameters()
	if parameters != null:
		parameters.set(property_name, value)
		_save_settings()


func _on_spawn_pressed() -> void:
	if main != null:
		main.spawn_enemy_bot_at_crosshair(int(_spawn_count.value))


func _get_player_parameters() -> PlayerParameters:
	if player_body == null:
		player_body = get_tree().get_first_node_in_group("player") as GoldGdt_Body
	return player_body.Parameters if player_body != null else null


func _set_visible_state(open: bool) -> void:
	visible = open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED
	if main != null:
		main.set_debug_menu_open(open)


func _load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return

	crosshair.line_color = config.get_value(CROSSHAIR_SECTION, "line_color", crosshair.line_color)
	crosshair.outline_color = config.get_value(CROSSHAIR_SECTION, "outline_color", crosshair.outline_color)
	crosshair.use_outline = config.get_value(CROSSHAIR_SECTION, "use_outline", crosshair.use_outline)
	crosshair.base_gap = config.get_value(CROSSHAIR_SECTION, "base_gap", crosshair.base_gap)
	crosshair.line_length = config.get_value(CROSSHAIR_SECTION, "line_length", crosshair.line_length)
	crosshair.line_thickness = config.get_value(CROSSHAIR_SECTION, "line_thickness", crosshair.line_thickness)
	crosshair.outline_size = config.get_value(CROSSHAIR_SECTION, "outline_size", crosshair.outline_size)
	crosshair.show_center_dot = config.get_value(CROSSHAIR_SECTION, "show_center_dot", crosshair.show_center_dot)
	crosshair.dot_size = config.get_value(CROSSHAIR_SECTION, "dot_size", crosshair.dot_size)
	crosshair.movement_gap = config.get_value(CROSSHAIR_SECTION, "movement_gap", crosshair.movement_gap)
	crosshair.airborne_gap = config.get_value(CROSSHAIR_SECTION, "airborne_gap", crosshair.airborne_gap)
	crosshair.crouch_gap_multiplier = config.get_value(CROSSHAIR_SECTION, "crouch_gap_multiplier", crosshair.crouch_gap_multiplier)
	crosshair.ads_gap_multiplier = config.get_value(CROSSHAIR_SECTION, "ads_gap_multiplier", crosshair.ads_gap_multiplier)
	crosshair.movement_speed_divisor = config.get_value(CROSSHAIR_SECTION, "movement_speed_divisor", crosshair.movement_speed_divisor)
	crosshair.fire_recoil_bump = config.get_value(CROSSHAIR_SECTION, "fire_recoil_bump", crosshair.fire_recoil_bump)
	crosshair.fire_recoil_decay = config.get_value(CROSSHAIR_SECTION, "fire_recoil_decay", crosshair.fire_recoil_decay)
	crosshair.spread_smoothing = config.get_value(CROSSHAIR_SECTION, "spread_smoothing", crosshair.spread_smoothing)

	var parameters: PlayerParameters = _get_player_parameters()
	if parameters != null:
		parameters.MOUSE_SENSITIVITY = config.get_value(MOUSE_SECTION, "sensitivity", parameters.MOUSE_SENSITIVITY)


func _save_settings() -> void:
	var config: ConfigFile = ConfigFile.new()

	config.set_value(CROSSHAIR_SECTION, "line_color", crosshair.line_color)
	config.set_value(CROSSHAIR_SECTION, "outline_color", crosshair.outline_color)
	config.set_value(CROSSHAIR_SECTION, "use_outline", crosshair.use_outline)
	config.set_value(CROSSHAIR_SECTION, "base_gap", crosshair.base_gap)
	config.set_value(CROSSHAIR_SECTION, "line_length", crosshair.line_length)
	config.set_value(CROSSHAIR_SECTION, "line_thickness", crosshair.line_thickness)
	config.set_value(CROSSHAIR_SECTION, "outline_size", crosshair.outline_size)
	config.set_value(CROSSHAIR_SECTION, "show_center_dot", crosshair.show_center_dot)
	config.set_value(CROSSHAIR_SECTION, "dot_size", crosshair.dot_size)
	config.set_value(CROSSHAIR_SECTION, "movement_gap", crosshair.movement_gap)
	config.set_value(CROSSHAIR_SECTION, "airborne_gap", crosshair.airborne_gap)
	config.set_value(CROSSHAIR_SECTION, "crouch_gap_multiplier", crosshair.crouch_gap_multiplier)
	config.set_value(CROSSHAIR_SECTION, "ads_gap_multiplier", crosshair.ads_gap_multiplier)
	config.set_value(CROSSHAIR_SECTION, "movement_speed_divisor", crosshair.movement_speed_divisor)
	config.set_value(CROSSHAIR_SECTION, "fire_recoil_bump", crosshair.fire_recoil_bump)
	config.set_value(CROSSHAIR_SECTION, "fire_recoil_decay", crosshair.fire_recoil_decay)
	config.set_value(CROSSHAIR_SECTION, "spread_smoothing", crosshair.spread_smoothing)

	var parameters: PlayerParameters = _get_player_parameters()
	if parameters != null:
		config.set_value(MOUSE_SECTION, "sensitivity", parameters.MOUSE_SENSITIVITY)

	var err: int = config.save(SETTINGS_PATH)
	if err != OK:
		push_warning("Failed to save debug settings to %s (error %d)." % [SETTINGS_PATH, err])
