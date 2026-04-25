extends Control

const CarCatalog = preload("res://scripts/data/car_catalog.gd")
const RaceDifficultyCatalog = preload("res://scripts/data/race_difficulty_catalog.gd")
const UIPalette = preload("res://scripts/ui/ui_palette.gd")
const RaceTrack = preload("res://scripts/race/race_track.gd")
const RaceCar = preload("res://scripts/race/race_car.gd")
const AIDriver = preload("res://scripts/race/ai_driver.gd")

signal screen_change_requested(screen_name: String, context: Dictionary)

const MODE_AI := "ai"
const MODE_LOCAL_COOP := "local_coop"
const TOTAL_LAPS := 3
const CHECKPOINT_TOTAL := 5

var _session_context: Dictionary = {}
var _race_mode := MODE_AI
var _difficulty: Dictionary = {}
var _player_car_data: Dictionary = {}
var _player_two_car_data: Dictionary = {}
var _ai_car_data: Dictionary = {}

var _track: RaceTrack
var _player_car: RaceCar
var _player_two_car: RaceCar
var _ai_car: RaceCar
var _player_driver: AIDriver
var _ai_driver: AIDriver
var _checkpoint_distances: Array[float] = []
var _coop_huds: Array[Dictionary] = []

var _countdown_remaining := 3.2
var _elapsed_time := 0.0
var _race_started := false
var _race_finished := false
var _race_paused := false
var _results_delay := -1.0
var _status_message := ""
var _status_timer := 0.0
var _player_two_status_message := ""
var _player_two_status_timer := 0.0

var _player_progress: Dictionary = {}
var _player_two_progress: Dictionary = {}
var _ai_progress: Dictionary = {}

@onready var _scene_world: Node3D = $SceneWorld
@onready var _viewport_host: SubViewportContainer = $RaceViewportHost
@onready var _race_viewport: SubViewport = $RaceViewportHost/RaceViewport
@onready var _single_camera: Camera3D = $RaceViewportHost/RaceViewport/SingleCameraRoot/SingleCamera
@onready var _hud_panel: PanelContainer = $HUDPanel
@onready var _speed_value: Label = $HUDPanel/HudPadding/HudColumn/TopRow/SpeedValue
@onready var _position_value: Label = $HUDPanel/HudPadding/HudColumn/TopRow/PositionValue
@onready var _difficulty_value: Label = $HUDPanel/HudPadding/HudColumn/DifficultyValue
@onready var _lap_value: Label = $HUDPanel/HudPadding/HudColumn/LapValue
@onready var _progress_value: Label = $HUDPanel/HudPadding/HudColumn/ProgressValue
@onready var _timer_value: Label = $HUDPanel/HudPadding/HudColumn/TimerValue
@onready var _nitro_bar: ProgressBar = $HUDPanel/HudPadding/HudColumn/NitroBar
@onready var _nitro_label: Label = $HUDPanel/HudPadding/HudColumn/NitroLabel
@onready var _status_value: Label = $HUDPanel/HudPadding/HudColumn/StatusValue
@onready var _coop_layer: Control = $CoopLayer
@onready var _player_one_viewport_host: SubViewportContainer = $CoopLayer/SplitMargin/SplitStack/PlayerOnePane/PlayerOneViewportHost
@onready var _player_one_viewport: SubViewport = $CoopLayer/SplitMargin/SplitStack/PlayerOnePane/PlayerOneViewportHost/PlayerOneViewport
@onready var _player_one_camera: Camera3D = $CoopLayer/SplitMargin/SplitStack/PlayerOnePane/PlayerOneViewportHost/PlayerOneViewport/PlayerOneCameraRoot/PlayerOneCamera
@onready var _player_one_hud_anchor: Control = $CoopLayer/SplitMargin/SplitStack/PlayerOnePane/PlayerOneHudAnchor
@onready var _player_two_viewport_host: SubViewportContainer = $CoopLayer/SplitMargin/SplitStack/PlayerTwoPane/PlayerTwoViewportHost
@onready var _player_two_viewport: SubViewport = $CoopLayer/SplitMargin/SplitStack/PlayerTwoPane/PlayerTwoViewportHost/PlayerTwoViewport
@onready var _player_two_camera: Camera3D = $CoopLayer/SplitMargin/SplitStack/PlayerTwoPane/PlayerTwoViewportHost/PlayerTwoViewport/PlayerTwoCameraRoot/PlayerTwoCamera
@onready var _player_two_hud_anchor: Control = $CoopLayer/SplitMargin/SplitStack/PlayerTwoPane/PlayerTwoHudAnchor
@onready var _countdown_label: Label = $CountdownLabel
@onready var _pause_overlay: ColorRect = $PauseOverlay
@onready var _pause_card: PanelContainer = $PauseOverlay/PauseCenter/PauseCard
@onready var _resume_button: Button = $PauseOverlay/PauseCenter/PauseCard/PausePadding/PauseColumn/ResumeButton
@onready var _restart_button: Button = $PauseOverlay/PauseCenter/PauseCard/PausePadding/PauseColumn/RestartButton
@onready var _settings_button: Button = $PauseOverlay/PauseCenter/PauseCard/PausePadding/PauseColumn/SettingsButton
@onready var _menu_button: Button = $PauseOverlay/PauseCenter/PauseCard/PausePadding/PauseColumn/MenuButton


func _ready() -> void:
	_apply_styles()
	_connect_actions()
	_bind_viewport_worlds()
	_ensure_coop_huds()
	resized.connect(_update_viewport_size)
	_update_viewport_size()

	if _session_context.is_empty():
		_session_context = {
			"mode": MODE_AI,
			"difficulty_id": "normal",
			"player_car_id": String(CarCatalog.get_default_player_car().get("id", "urban_racer")),
			"ai_car_id": "dodge_challenger_srt",
		}

	call_deferred("_setup_session")


func configure_screen(context: Dictionary) -> void:
	_session_context = context.duplicate(true)

	if is_node_ready():
		_setup_session()


func _apply_styles() -> void:
	UIPalette.apply_panel_style(
		_hud_panel,
		Color(0.0823529, 0.113725, 0.168627, 0.82),
		UIPalette.ACCENT_CYAN,
		24,
		2
	)
	UIPalette.apply_panel_style(_pause_card, UIPalette.SURFACE_PANEL, UIPalette.ACCENT_ORANGE, 30, 2)

	for label in [_speed_value, _position_value, _difficulty_value, _lap_value, _progress_value, _timer_value, _nitro_label]:
		label.add_theme_color_override("font_color", UIPalette.TEXT_PRIMARY)

	_status_value.add_theme_color_override("font_color", UIPalette.TEXT_MUTED)
	_countdown_label.add_theme_color_override("font_color", UIPalette.TEXT_PRIMARY)
	_countdown_label.add_theme_font_size_override("font_size", 92)
	UIPalette.apply_progress_bar_style(_nitro_bar, UIPalette.ACCENT_ORANGE)

	UIPalette.apply_button_style(
		_resume_button,
		Color(0.164706, 0.2, 0.270588, 0.95),
		UIPalette.ACCENT_CYAN,
		Color(0.133333, 0.160784, 0.219608, 1.0)
	)
	UIPalette.apply_button_style(
		_restart_button,
		Color(0.541176, 0.239216, 0.176471, 0.95),
		UIPalette.ACCENT_ORANGE,
		Color(0.639216, 0.254902, 0.180392, 1.0)
	)
	UIPalette.apply_button_style(
		_settings_button,
		Color(0.298039, 0.262745, 0.113725, 0.95),
		UIPalette.ACCENT_GOLD,
		Color(0.403922, 0.337255, 0.0784314, 1.0)
	)
	UIPalette.apply_button_style(
		_menu_button,
		Color(0.180392, 0.215686, 0.286275, 0.95),
		Color(0.27451, 0.313726, 0.403922, 1.0),
		Color(0.141176, 0.176471, 0.243137, 1.0)
	)


func _connect_actions() -> void:
	_resume_button.pressed.connect(_on_resume_pressed)
	_restart_button.pressed.connect(_on_restart_pressed)
	_menu_button.pressed.connect(_on_menu_pressed)


func _bind_viewport_worlds() -> void:
	var shared_world := get_viewport().world_3d
	_race_viewport.world_3d = shared_world
	_player_one_viewport.world_3d = shared_world
	_player_two_viewport.world_3d = shared_world


func _ensure_coop_huds() -> void:
	if not _coop_huds.is_empty():
		return

	_coop_huds = [
		_create_coop_hud(_player_one_hud_anchor, "P1", UIPalette.ACCENT_ORANGE, "R"),
		_create_coop_hud(_player_two_hud_anchor, "P2", UIPalette.ACCENT_CYAN, "M"),
	]


func _create_coop_hud(anchor: Control, player_label: String, accent_color: Color, nitro_hint: String) -> Dictionary:
	var panel := PanelContainer.new()
	panel.offset_left = 16.0
	panel.offset_top = 16.0
	panel.offset_right = 332.0
	panel.offset_bottom = 232.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.add_child(panel)

	var padding := MarginContainer.new()
	padding.add_theme_constant_override("margin_left", 16)
	padding.add_theme_constant_override("margin_top", 16)
	padding.add_theme_constant_override("margin_right", 16)
	padding.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(padding)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	padding.add_child(column)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	column.add_child(top_row)

	var badge := PanelContainer.new()
	top_row.add_child(badge)
	UIPalette.apply_panel_style(badge, accent_color, accent_color.lightened(0.08), 16, 2)

	var badge_padding := MarginContainer.new()
	badge_padding.add_theme_constant_override("margin_left", 12)
	badge_padding.add_theme_constant_override("margin_top", 6)
	badge_padding.add_theme_constant_override("margin_right", 12)
	badge_padding.add_theme_constant_override("margin_bottom", 6)
	badge.add_child(badge_padding)

	var badge_value := Label.new()
	badge_value.text = player_label
	badge_value.add_theme_font_size_override("font_size", 16)
	badge_value.add_theme_color_override("font_color", UIPalette.TEXT_PRIMARY)
	badge_padding.add_child(badge_value)

	var position_value := Label.new()
	position_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	position_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	position_value.add_theme_font_size_override("font_size", 16)
	position_value.add_theme_color_override("font_color", UIPalette.TEXT_PRIMARY)
	top_row.add_child(position_value)

	var speed_value := Label.new()
	speed_value.add_theme_font_size_override("font_size", 28)
	speed_value.add_theme_color_override("font_color", UIPalette.TEXT_PRIMARY)
	column.add_child(speed_value)

	var lap_value := Label.new()
	lap_value.add_theme_font_size_override("font_size", 16)
	lap_value.add_theme_color_override("font_color", UIPalette.TEXT_PRIMARY)
	column.add_child(lap_value)

	var progress_value := Label.new()
	progress_value.add_theme_font_size_override("font_size", 16)
	progress_value.add_theme_color_override("font_color", UIPalette.TEXT_PRIMARY)
	column.add_child(progress_value)

	var timer_value := Label.new()
	timer_value.add_theme_font_size_override("font_size", 16)
	timer_value.add_theme_color_override("font_color", UIPalette.TEXT_PRIMARY)
	column.add_child(timer_value)

	var nitro_label := Label.new()
	nitro_label.add_theme_font_size_override("font_size", 16)
	nitro_label.add_theme_color_override("font_color", UIPalette.TEXT_PRIMARY)
	column.add_child(nitro_label)

	var nitro_bar := ProgressBar.new()
	nitro_bar.custom_minimum_size = Vector2(0, 16)
	nitro_bar.max_value = 100.0
	nitro_bar.show_percentage = false
	UIPalette.apply_progress_bar_style(nitro_bar, accent_color)
	column.add_child(nitro_bar)

	var status_value := Label.new()
	status_value.add_theme_font_size_override("font_size", 14)
	status_value.add_theme_color_override("font_color", UIPalette.TEXT_MUTED)
	status_value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status_value)

	UIPalette.apply_panel_style(panel, Color(0.0666667, 0.0941176, 0.14902, 0.84), accent_color, 22, 2)

	return {
		"position_value": position_value,
		"speed_value": speed_value,
		"lap_value": lap_value,
		"progress_value": progress_value,
		"timer_value": timer_value,
		"nitro_label": nitro_label,
		"nitro_bar": nitro_bar,
		"status_value": status_value,
		"nitro_hint": nitro_hint,
	}


func _setup_session() -> void:
	_bind_viewport_worlds()
	_clear_runtime_state()

	_race_mode = String(_session_context.get("mode", MODE_AI))
	_difficulty = RaceDifficultyCatalog.get_by_id(String(_session_context.get("difficulty_id", "normal")))
	_player_car_data = CarCatalog.get_car_by_id(String(_session_context.get("player_car_id", "urban_racer")))
	_player_two_car_data = CarCatalog.get_car_by_id(String(_session_context.get("player_two_car_id", "dodge_challenger_srt")))
	_ai_car_data = CarCatalog.get_car_by_id(String(_session_context.get("ai_car_id", _difficulty.get("ai_car_id", "dodge_challenger_srt"))))

	_scene_world.add_child(_create_environment())
	_scene_world.add_child(_create_lighting())

	_track = RaceTrack.new()
	_scene_world.add_child(_track)
	_checkpoint_distances = _track.get_checkpoint_distances()

	_player_car = _spawn_car(_player_car_data, true, false, 0)
	_player_car.nitro_state_changed.connect(_on_player_nitro_state_changed)

	if _race_mode == MODE_LOCAL_COOP:
		_player_two_car = _spawn_car(_player_two_car_data, true, false, 1)
		_player_two_car.nitro_state_changed.connect(_on_player_two_nitro_state_changed)
		_ai_car = null
		_setup_coop_runtime()
	else:
		_ai_car = _spawn_car(_ai_car_data, false, true, 1)
		_player_two_car = null
		_setup_ai_runtime()

	_player_progress = _make_progress_state()
	_player_two_progress = _make_progress_state()
	_ai_progress = _make_progress_state()
	_countdown_remaining = 3.2
	_elapsed_time = 0.0
	_race_started = false
	_race_finished = false
	_race_paused = false
	_results_delay = -1.0
	_status_message = ""
	_status_timer = 0.0
	_player_two_status_message = ""
	_player_two_status_timer = 0.0
	_pause_overlay.visible = false
	_countdown_label.text = "3"

	if _race_mode == MODE_LOCAL_COOP:
		_show_status("Приготовьтесь к старту")
		_show_player_two_status("Приготовьтесь к старту")
	else:
		_show_status("Приготовьтесь к старту")

	_configure_mode_layers()
	_update_active_cameras(0.0)
	_refresh_visible_hud()


func _clear_runtime_state() -> void:
	for child in _scene_world.get_children():
		_scene_world.remove_child(child)
		child.queue_free()

	for driver in [_player_driver, _ai_driver]:
		if is_instance_valid(driver):
			remove_child(driver)
			driver.queue_free()

	_track = null
	_player_car = null
	_player_two_car = null
	_ai_car = null
	_player_driver = null
	_ai_driver = null


func _spawn_car(car_data: Dictionary, player_controlled: bool, ghost_mode: bool, spawn_index: int) -> RaceCar:
	var car := RaceCar.new()
	car.configure(car_data, player_controlled, ghost_mode)
	_track.add_child(car)
	car.reset_to_transform(_track.get_spawn_transform(spawn_index))
	return car


func _setup_ai_runtime() -> void:
	_ai_car.set_physics_process(false)

	_player_driver = null
	if bool(_session_context.get("autoplay_player", false)):
		_player_driver = AIDriver.new()
		add_child(_player_driver)
		_player_driver.configure(_player_car, _track, RaceDifficultyCatalog.get_by_id("normal"))
		_player_car.set_physics_process(false)

	_ai_driver = AIDriver.new()
	add_child(_ai_driver)
	_ai_driver.configure(_ai_car, _track, _difficulty)

	_single_camera.current = true
	_player_one_camera.current = false
	_player_two_camera.current = false


func _setup_coop_runtime() -> void:
	_player_driver = null
	_ai_driver = null
	_single_camera.current = false
	_player_one_camera.current = true
	_player_two_camera.current = true


func _configure_mode_layers() -> void:
	var coop_enabled := _race_mode == MODE_LOCAL_COOP
	_viewport_host.visible = not coop_enabled
	_hud_panel.visible = not coop_enabled
	_coop_layer.visible = coop_enabled
	_race_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if not coop_enabled else SubViewport.UPDATE_DISABLED
	_player_one_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if coop_enabled else SubViewport.UPDATE_DISABLED
	_player_two_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if coop_enabled else SubViewport.UPDATE_DISABLED


func _physics_process(delta: float) -> void:
	if _track == null or _player_car == null:
		return

	if _race_mode == MODE_AI and _ai_car == null:
		return

	if _race_mode == MODE_LOCAL_COOP and _player_two_car == null:
		return

	if _race_paused:
		_refresh_visible_hud()
		return

	if _race_finished:
		_results_delay -= delta
		if _results_delay <= 0.0:
			_open_results_screen()
			return
		_update_active_cameras(delta)
		_refresh_visible_hud()
		return

	if _countdown_remaining > 0.0:
		_countdown_remaining -= delta
		_countdown_label.text = "GO!" if _countdown_remaining < 0.5 else str(int(ceil(_countdown_remaining)))
		_hold_all_cars()
		_update_active_cameras(delta)
		_refresh_visible_hud()
		return

	_countdown_label.text = ""
	_elapsed_time += delta

	if _race_mode == MODE_LOCAL_COOP:
		_process_local_coop_frame(delta)
	else:
		_process_ai_frame(delta)


func _process_ai_frame(delta: float) -> void:
	if _player_driver != null:
		_player_driver.update_driver(delta, _get_score_for_car(_ai_car))
	else:
		_apply_player_input()

	_ai_driver.update_driver(delta, _get_score_for_car(_player_car))

	var player_metrics := _sync_car_state(_player_car, _player_progress)
	var ai_metrics := _sync_car_state(_ai_car, _ai_progress)

	if not _race_started:
		_race_started = true
		_show_status("Старт!")

	_update_status_timer(delta)
	_update_active_cameras(delta)
	_refresh_single_hud(player_metrics, ai_metrics)


func _process_local_coop_frame(delta: float) -> void:
	_apply_player_input()
	_apply_player_two_input()

	var player_metrics := _sync_car_state(_player_car, _player_progress)
	var player_two_metrics := _sync_car_state(_player_two_car, _player_two_progress)

	if not _race_started:
		_race_started = true
		_show_status("Старт!")
		_show_player_two_status("Старт!")

	_update_status_timer(delta)
	_update_player_two_status_timer(delta)
	_update_active_cameras(delta)
	_refresh_coop_huds(player_metrics, player_two_metrics)


func _hold_all_cars() -> void:
	for car in _get_active_cars():
		car.set_drive_input(0.0, 0.0, 1.0, false)


func _get_active_cars() -> Array[RaceCar]:
	var cars: Array[RaceCar] = []
	if is_instance_valid(_player_car):
		cars.append(_player_car)

	if _race_mode == MODE_LOCAL_COOP:
		if is_instance_valid(_player_two_car):
			cars.append(_player_two_car)
	elif is_instance_valid(_ai_car):
		cars.append(_ai_car)

	return cars


func _update_viewport_size() -> void:
	_race_viewport.size = Vector2i(max(1, int(_viewport_host.size.x)), max(1, int(_viewport_host.size.y)))
	_player_one_viewport.size = Vector2i(max(1, int(_player_one_viewport_host.size.x)), max(1, int(_player_one_viewport_host.size.y)))
	_player_two_viewport.size = Vector2i(max(1, int(_player_two_viewport_host.size.x)), max(1, int(_player_two_viewport_host.size.y)))


func _apply_player_input() -> void:
	if bool(_player_progress.get("finished", false)):
		_player_car.set_drive_input(0.0, 0.0, 1.0, false)
		return

	var accelerate := Input.get_action_strength("player_accelerate")
	var brake_or_reverse := Input.get_action_strength("player_brake")
	var steer := Input.get_action_strength("player_right") - Input.get_action_strength("player_left")
	var brake := 0.0
	var throttle := accelerate

	var forward_speed: float = Vector3(_player_car.velocity.x, 0.0, _player_car.velocity.z).dot(-_player_car.global_basis.z)
	if brake_or_reverse > 0.0:
		if forward_speed > 2.5:
			brake = brake_or_reverse
		else:
			throttle -= brake_or_reverse * 0.72

	_player_car.set_drive_input(throttle, steer, brake, Input.is_action_pressed("player_nitro"))


func _apply_player_two_input() -> void:
	if bool(_player_two_progress.get("finished", false)):
		_player_two_car.set_drive_input(0.0, 0.0, 1.0, false)
		return

	var accelerate := Input.get_action_strength("player_two_accelerate")
	var brake_or_reverse := Input.get_action_strength("player_two_brake")
	var steer := Input.get_action_strength("player_two_right") - Input.get_action_strength("player_two_left")
	var brake := 0.0
	var throttle := accelerate

	var forward_speed: float = Vector3(_player_two_car.velocity.x, 0.0, _player_two_car.velocity.z).dot(-_player_two_car.global_basis.z)
	if brake_or_reverse > 0.0:
		if forward_speed > 2.5:
			brake = brake_or_reverse
		else:
			throttle -= brake_or_reverse * 0.72

	_player_two_car.set_drive_input(throttle, steer, brake, Input.is_action_pressed("player_two_nitro"))


func _sync_car_state(car: RaceCar, state: Dictionary) -> Dictionary:
	var metrics: Dictionary = _track.get_track_metrics(car.global_position, float(state["progress_hint"]))
	state["previous_progress_hint"] = float(state["progress_hint"])
	state["progress_hint"] = metrics["progress"]
	state["distance_to_center"] = metrics["distance_to_center"]
	car.set_surface_factor(_track.get_surface_factor(car.global_position))
	_advance_progress_from_distance(car, state)
	return metrics


func _update_active_cameras(delta: float) -> void:
	if _race_mode == MODE_LOCAL_COOP:
		_update_camera(_player_one_camera, _player_car, delta)
		_update_camera(_player_two_camera, _player_two_car, delta)
	else:
		_update_camera(_single_camera, _player_car, delta)


func _update_camera(camera: Camera3D, target_car: RaceCar, delta: float) -> void:
	if camera == null or target_car == null:
		return

	var forward := -target_car.global_basis.z
	var target_position := target_car.global_position + forward * -7.2 + Vector3.UP * 3.2
	var look_target := target_car.global_position + Vector3.UP * 1.1
	camera.global_position = camera.global_position.lerp(target_position, minf(1.0, 4.4 * delta if delta > 0.0 else 1.0))
	camera.look_at(look_target, Vector3.UP)
	camera.fov = lerpf(68.0, 78.0, clampf(target_car.get_speed_mps() / maxf(target_car.get_base_top_speed(), 0.01), 0.0, 1.0))


func _refresh_visible_hud() -> void:
	if _race_mode == MODE_LOCAL_COOP:
		_refresh_coop_huds({}, {})
	else:
		_refresh_single_hud({}, {})


func _refresh_single_hud(player_metrics: Dictionary, ai_metrics: Dictionary) -> void:
	var next_checkpoint := int(_player_progress["next_checkpoint_index"])
	var lap_display := mini(int(_player_progress["laps_completed"]) + 1, TOTAL_LAPS)
	if bool(_player_progress["finished"]):
		lap_display = TOTAL_LAPS

	_speed_value.text = "Скорость: %03d км/ч" % int(round(_player_car.get_speed_kph()))
	_position_value.text = "Позиция: %d / 2" % _get_place_for_car(_player_car)
	_difficulty_value.text = "Сложность: %s" % String(_difficulty.get("name", "Средняя"))
	_lap_value.text = "Круг: %d / %d" % [lap_display, TOTAL_LAPS]
	_progress_value.text = "Чекпоинт: %d / %d" % [min(next_checkpoint, CHECKPOINT_TOTAL), CHECKPOINT_TOTAL]
	_timer_value.text = "Таймер: %s" % _format_time(_elapsed_time)
	_nitro_label.text = "Нитро: %d%% (R)" % int(round(_player_car.get_nitro_ratio() * 100.0))
	_nitro_bar.value = _player_car.get_nitro_ratio() * 100.0
	_status_value.text = _status_message if _status_timer > 0.0 else _get_default_status(player_metrics, ai_metrics)


func _refresh_coop_huds(player_metrics: Dictionary, player_two_metrics: Dictionary) -> void:
	if _coop_huds.size() < 2:
		return

	_refresh_coop_hud(
		_coop_huds[0],
		_player_car,
		_player_progress,
		_status_message,
		_status_timer,
		player_metrics,
		player_two_metrics
	)
	_refresh_coop_hud(
		_coop_huds[1],
		_player_two_car,
		_player_two_progress,
		_player_two_status_message,
		_player_two_status_timer,
		player_two_metrics,
		player_metrics
	)


func _refresh_coop_hud(
	hud_refs: Dictionary,
	car: RaceCar,
	progress: Dictionary,
	status_message: String,
	status_timer: float,
	player_metrics: Dictionary,
	opponent_metrics: Dictionary
) -> void:
	var next_checkpoint := int(progress["next_checkpoint_index"])
	var lap_display := mini(int(progress["laps_completed"]) + 1, TOTAL_LAPS)
	if bool(progress["finished"]):
		lap_display = TOTAL_LAPS

	hud_refs["position_value"].text = "Позиция %d / 2" % _get_place_for_car(car)
	hud_refs["speed_value"].text = "%03d км/ч" % int(round(car.get_speed_kph()))
	hud_refs["lap_value"].text = "Круг %d / %d" % [lap_display, TOTAL_LAPS]
	hud_refs["progress_value"].text = "Чекпоинт %d / %d" % [min(next_checkpoint, CHECKPOINT_TOTAL), CHECKPOINT_TOTAL]
	hud_refs["timer_value"].text = "Таймер %s" % _format_time(_elapsed_time)
	hud_refs["nitro_label"].text = "Нитро %d%% (%s)" % [int(round(car.get_nitro_ratio() * 100.0)), String(hud_refs["nitro_hint"])]
	hud_refs["nitro_bar"].value = car.get_nitro_ratio() * 100.0
	hud_refs["status_value"].text = status_message if status_timer > 0.0 else _get_default_status_for_coop_player(car, player_metrics, opponent_metrics)


func _get_default_status(player_metrics: Dictionary, ai_metrics: Dictionary) -> String:
	if not player_metrics.is_empty() and float(player_metrics.get("distance_to_center", 0.0)) > _track.get_road_half_width() * 0.72:
		return "Держись ворот: они ведут по кругу до финиша."
	if not ai_metrics.is_empty() and _get_place_for_car(_player_car) == 2:
		return "Соперник впереди: длинная прямая подходит для нитро."
	return "ESC — пауза, R — нитро."


func _get_default_status_for_coop_player(car: RaceCar, player_metrics: Dictionary, opponent_metrics: Dictionary) -> String:
	if not player_metrics.is_empty() and float(player_metrics.get("distance_to_center", 0.0)) > _track.get_road_half_width() * 0.72:
		return "Держись внутри ворот, чтобы не потерять круг."
	if not opponent_metrics.is_empty() and _get_place_for_car(car) == 2:
		return "Соперник впереди: нитро лучше прожимать на прямой."
	return "Nitro: R" if car == _player_car else "Nitro: M"


func _update_status_timer(delta: float) -> void:
	if _status_timer <= 0.0:
		return
	_status_timer = max(0.0, _status_timer - delta)


func _update_player_two_status_timer(delta: float) -> void:
	if _player_two_status_timer <= 0.0:
		return
	_player_two_status_timer = max(0.0, _player_two_status_timer - delta)


func _show_status(message: String, duration: float = 2.1) -> void:
	_status_message = message
	_status_timer = duration


func _show_player_two_status(message: String, duration: float = 2.1) -> void:
	_player_two_status_message = message
	_player_two_status_timer = duration


func _get_place_for_car(car: RaceCar) -> int:
	var target_score := _get_score_for_car(car)
	var place := 1

	for other_car in _get_active_cars():
		if other_car == car:
			continue
		if _get_score_for_car(other_car) > target_score:
			place += 1

	return place


func _get_score_for_car(car: RaceCar) -> float:
	if car == _player_car:
		return _get_competitor_score(_player_progress)
	if car == _player_two_car:
		return _get_competitor_score(_player_two_progress)
	if car == _ai_car:
		return _get_competitor_score(_ai_progress)
	return 0.0


func _get_competitor_score(state: Dictionary) -> float:
	var laps_completed := float(state.get("laps_completed", 0))
	var checkpoints_passed := float(state.get("next_checkpoint_index", 0))
	var track_progress := float(state.get("progress_hint", 0.0))
	var finish_bonus := 500000.0 if bool(state.get("finished", false)) else 0.0
	return finish_bonus + laps_completed * 100000.0 + checkpoints_passed * 10000.0 + track_progress


func _make_progress_state() -> Dictionary:
	return {
		"laps_completed": 0,
		"next_checkpoint_index": 0,
		"previous_progress_hint": 0.0,
		"progress_hint": 0.0,
		"distance_to_center": 0.0,
		"finished": false,
		"finish_time": -1.0,
	}


func _advance_progress_from_distance(car: RaceCar, state: Dictionary) -> void:
	if bool(state["finished"]):
		return

	var progress: float = float(state["progress_hint"])
	var previous_progress: float = float(state["previous_progress_hint"])
	var checkpoint_index: int = int(state["next_checkpoint_index"])

	if checkpoint_index < _checkpoint_distances.size():
		var checkpoint_distance: float = _checkpoint_distances[checkpoint_index]
		if progress >= checkpoint_distance - 2.0:
			state["next_checkpoint_index"] = checkpoint_index + 1
			if car == _player_car:
				_show_status("Чекпоинт %d / %d" % [int(state["next_checkpoint_index"]), CHECKPOINT_TOTAL])
			elif car == _player_two_car:
				_show_player_two_status("Чекпоинт %d / %d" % [int(state["next_checkpoint_index"]), CHECKPOINT_TOTAL])
			return

	var wrapped_to_finish := checkpoint_index >= _checkpoint_distances.size() \
		and previous_progress > _track.get_track_length() - 28.0 \
		and progress < _track.get_finish_distance() + 8.0
	if not wrapped_to_finish:
		return

	state["next_checkpoint_index"] = 0
	state["laps_completed"] = int(state["laps_completed"]) + 1

	if int(state["laps_completed"]) >= TOTAL_LAPS:
		state["finished"] = true
		state["finish_time"] = _elapsed_time
		car.set_drive_input(0.0, 0.0, 1.0, false)
		car.set_physics_process(false)

		if _race_mode == MODE_LOCAL_COOP:
			if car == _player_car:
				_show_status("Финиш!", 3.0)
				if not bool(_player_two_progress["finished"]):
					_show_player_two_status("P1 уже финишировал", 2.6)
			elif car == _player_two_car:
				_show_player_two_status("Финиш!", 3.0)
				if not bool(_player_progress["finished"]):
					_show_status("P2 уже финишировал", 2.6)

			if bool(_player_progress["finished"]) and bool(_player_two_progress["finished"]):
				_race_finished = true
				_results_delay = 1.35
		elif car == _player_car:
			_race_finished = true
			_results_delay = 1.35
			_ai_car.set_drive_input(0.0, 0.0, 1.0, false)
			_ai_car.set_physics_process(false)
			_show_status("Финиш!", 3.0)
		else:
			_show_status("Соперник финишировал первым", 2.6)
	elif car == _player_car:
		_show_status("Круг %d / %d" % [int(state["laps_completed"]) + 1, TOTAL_LAPS])
	elif car == _player_two_car:
		_show_player_two_status("Круг %d / %d" % [int(state["laps_completed"]) + 1, TOTAL_LAPS])


func _on_player_nitro_state_changed(active: bool) -> void:
	if active:
		_show_status("Нитро включено", 1.1)


func _on_player_two_nitro_state_changed(active: bool) -> void:
	if active:
		_show_player_two_status("Нитро включено", 1.1)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _race_finished:
			return
		_toggle_pause()


func _toggle_pause() -> void:
	_race_paused = not _race_paused
	_pause_overlay.visible = _race_paused
	_set_pause_state_for_car(_player_car, _player_progress)
	if _race_mode == MODE_LOCAL_COOP:
		_set_pause_state_for_car(_player_two_car, _player_two_progress)
	elif _ai_car != null:
		_set_pause_state_for_car(_ai_car, _ai_progress)
	_resume_button.grab_focus()


func _set_pause_state_for_car(car: RaceCar, progress: Dictionary) -> void:
	if car == null:
		return
	car.set_physics_process(not _race_paused and not bool(progress.get("finished", false)))


func _format_time(time_seconds: float) -> String:
	var minutes := int(time_seconds / 60.0)
	var seconds := int(fmod(time_seconds, 60.0))
	var centiseconds := int(floor(fmod(time_seconds, 1.0) * 100.0))
	return "%02d:%02d.%02d" % [minutes, seconds, centiseconds]


func _open_results_screen() -> void:
	if _race_mode == MODE_LOCAL_COOP:
		screen_change_requested.emit(
			"results",
			{
				"mode": MODE_LOCAL_COOP,
				"winner_label": _get_coop_winner_label(),
				"player_one_time": float(_player_progress["finish_time"]),
				"player_two_time": float(_player_two_progress["finish_time"]),
				"player_one_car_name": _player_car.get_car_name(),
				"player_two_car_name": _player_two_car.get_car_name(),
				"restart_context": _session_context.duplicate(true),
			}
		)
		return

	screen_change_requested.emit(
		"results",
		{
			"mode": MODE_AI,
			"player_position": _get_place_for_car(_player_car),
			"player_time": float(_player_progress["finish_time"]),
			"ai_time": float(_ai_progress["finish_time"]),
			"ai_finished": bool(_ai_progress["finished"]),
			"difficulty_name": String(_difficulty.get("name", "Средняя")),
			"player_car_name": _player_car.get_car_name(),
			"ai_car_name": _ai_car.get_car_name(),
			"restart_context": _session_context.duplicate(true),
		}
	)


func _get_coop_winner_label() -> String:
	var player_time := float(_player_progress.get("finish_time", -1.0))
	var player_two_time := float(_player_two_progress.get("finish_time", -1.0))
	if player_time < 0.0 or player_two_time < 0.0:
		return "Ничья"
	if is_equal_approx(player_time, player_two_time):
		return "Ничья"
	return "P1" if player_time < player_two_time else "P2"


func _create_environment() -> WorldEnvironment:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.0627451, 0.113725, 0.2, 1.0)
	sky_material.sky_horizon_color = Color(0.627451, 0.356863, 0.223529, 1.0)
	sky_material.ground_horizon_color = Color(0.113725, 0.133333, 0.180392, 1.0)
	sky_material.ground_bottom_color = Color(0.0509804, 0.0705882, 0.101961, 1.0)
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.658824, 0.694118, 0.772549, 1.0)
	environment.ambient_light_energy = 0.65
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	return environment_node


func _create_lighting() -> Node3D:
	var lights_root := Node3D.new()
	var sunlight := DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-42.0, -38.0, 0.0)
	sunlight.light_energy = 2.2
	sunlight.shadow_enabled = true
	lights_root.add_child(sunlight)

	var fill_light := OmniLight3D.new()
	fill_light.light_color = Color(0.917647, 0.639216, 0.431373, 1.0)
	fill_light.light_energy = 0.65
	fill_light.omni_range = 140.0
	fill_light.position = Vector3(0.0, 16.0, 0.0)
	lights_root.add_child(fill_light)
	return lights_root


func _on_resume_pressed() -> void:
	_toggle_pause()


func _on_restart_pressed() -> void:
	screen_change_requested.emit("race_session", _session_context)


func _on_menu_pressed() -> void:
	screen_change_requested.emit("main_menu", {})
