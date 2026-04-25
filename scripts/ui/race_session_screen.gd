extends Control

const CarCatalog = preload("res://scripts/data/car_catalog.gd")
const RaceDifficultyCatalog = preload("res://scripts/data/race_difficulty_catalog.gd")
const UIPalette = preload("res://scripts/ui/ui_palette.gd")
const RaceTrack = preload("res://scripts/race/race_track.gd")
const RaceCar = preload("res://scripts/race/race_car.gd")
const AIDriver = preload("res://scripts/race/ai_driver.gd")

signal screen_change_requested(screen_name: String, context: Dictionary)

const TOTAL_LAPS := 3
const CHECKPOINT_TOTAL := 5

var _session_context: Dictionary = {}
var _difficulty: Dictionary = {}
var _player_car_data: Dictionary = {}
var _ai_car_data: Dictionary = {}

var _track: RaceTrack
var _player_car: RaceCar
var _ai_car: RaceCar
var _player_driver: AIDriver
var _ai_driver: AIDriver
var _camera: Camera3D
var _checkpoint_distances: Array[float] = []

var _countdown_remaining := 3.2
var _elapsed_time := 0.0
var _race_started := false
var _race_finished := false
var _race_paused := false
var _results_delay := -1.0
var _status_message := ""
var _status_timer := 0.0

var _player_progress: Dictionary = {}
var _ai_progress: Dictionary = {}

@onready var _viewport_host: SubViewportContainer = $RaceViewportHost
@onready var _race_viewport: SubViewport = $RaceViewportHost/RaceViewport
@onready var _world_root: Node3D = $RaceViewportHost/RaceViewport/WorldRoot
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
	resized.connect(_update_viewport_size)
	_update_viewport_size()

	if _session_context.is_empty():
		_session_context = {
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


func _setup_session() -> void:
	_difficulty = RaceDifficultyCatalog.get_by_id(String(_session_context.get("difficulty_id", "normal")))
	_player_car_data = CarCatalog.get_car_by_id(String(_session_context.get("player_car_id", "urban_racer")))
	_ai_car_data = CarCatalog.get_car_by_id(String(_session_context.get("ai_car_id", _difficulty.get("ai_car_id", "dodge_challenger_srt"))))

	for child in _world_root.get_children():
		child.queue_free()

	_track = RaceTrack.new()
	_world_root.add_child(_create_environment())
	_world_root.add_child(_create_lighting())
	_world_root.add_child(_track)

	_player_car = RaceCar.new()
	_player_car.configure(_player_car_data, true, false)
	_track.add_child(_player_car)

	_ai_car = RaceCar.new()
	_ai_car.configure(_ai_car_data, false, true)
	_track.add_child(_ai_car)
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

	_player_car.nitro_state_changed.connect(_on_player_nitro_state_changed)

	_camera = Camera3D.new()
	_camera.current = true
	_camera.fov = 68.0
	_world_root.add_child(_camera)

	_player_car.reset_to_transform(_track.get_spawn_transform(0))
	_ai_car.reset_to_transform(_track.get_spawn_transform(1))

	_player_progress = _make_progress_state()
	_ai_progress = _make_progress_state()
	_checkpoint_distances = _track.get_checkpoint_distances()

	_countdown_remaining = 3.2
	_elapsed_time = 0.0
	_race_started = false
	_race_finished = false
	_race_paused = false
	_results_delay = -1.0
	_show_status("Приготовьтесь к старту")
	_pause_overlay.visible = false
	_update_camera(0.0)
	_refresh_hud()


func _physics_process(delta: float) -> void:
	if _track == null or _player_car == null or _ai_car == null:
		return

	if _race_paused:
		_refresh_hud()
		return

	if _race_finished:
		_results_delay -= delta
		if _results_delay <= 0.0:
			_open_results_screen()
			return
		_update_camera(delta)
		_refresh_hud()
		return

	if _countdown_remaining > 0.0:
		_countdown_remaining -= delta
		var countdown_text: String = "GO!" if _countdown_remaining < 0.5 else str(int(ceil(_countdown_remaining)))
		_countdown_label.text = countdown_text
		_player_car.set_drive_input(0.0, 0.0, 1.0, false)
		_ai_car.set_drive_input(0.0, 0.0, 1.0, false)
		_update_camera(delta)
		_refresh_hud()
		return

	_countdown_label.text = ""
	_elapsed_time += delta

	if _player_driver != null:
		_player_driver.update_driver(delta, _get_competitor_score(_ai_progress))
	else:
		_apply_player_input()

	_ai_driver.update_driver(delta, _get_competitor_score(_player_progress))
	var player_metrics: Dictionary = _sync_car_state(_player_car, _player_progress, delta)
	var ai_metrics: Dictionary = _sync_car_state(_ai_car, _ai_progress, delta)

	if not _race_started:
		_race_started = true
		_show_status("Старт!")

	_update_status_timer(delta)
	_update_camera(delta)
	_refresh_hud(player_metrics, ai_metrics)


func _update_viewport_size() -> void:
	_race_viewport.size = Vector2i(max(1, int(_viewport_host.size.x)), max(1, int(_viewport_host.size.y)))


func _apply_player_input() -> void:
	var accelerate: float = Input.get_action_strength("player_accelerate")
	var brake_or_reverse: float = Input.get_action_strength("player_brake")
	var steer: float = Input.get_action_strength("player_right") - Input.get_action_strength("player_left")
	var brake: float = 0.0
	var throttle: float = accelerate

	var forward_speed: float = Vector3(_player_car.velocity.x, 0.0, _player_car.velocity.z).dot(-_player_car.global_basis.z)
	if brake_or_reverse > 0.0:
		if forward_speed > 2.5:
			brake = brake_or_reverse
		else:
			throttle -= brake_or_reverse * 0.72

	_player_car.set_drive_input(throttle, steer, brake, Input.is_action_pressed("player_nitro"))


func _sync_car_state(car: RaceCar, state: Dictionary, delta: float) -> Dictionary:
	var metrics: Dictionary = _track.get_track_metrics(car.global_position, float(state["progress_hint"]))
	state["previous_progress_hint"] = float(state["progress_hint"])
	state["progress_hint"] = metrics["progress"]
	state["distance_to_center"] = metrics["distance_to_center"]
	car.set_surface_factor(_track.get_surface_factor(car.global_position))
	_advance_progress_from_distance(car, state)
	return metrics


func _update_camera(delta: float) -> void:
	if _camera == null or _player_car == null:
		return

	var forward: Vector3 = -_player_car.global_basis.z
	var target_position: Vector3 = _player_car.global_position + forward * -7.2 + Vector3.UP * 3.2
	var look_target: Vector3 = _player_car.global_position + Vector3.UP * 1.1
	_camera.global_position = _camera.global_position.lerp(target_position, minf(1.0, 4.4 * delta if delta > 0.0 else 1.0))
	_camera.look_at(look_target, Vector3.UP)
	_camera.fov = lerpf(68.0, 78.0, clampf(_player_car.get_speed_mps() / maxf(_player_car.get_base_top_speed(), 0.01), 0.0, 1.0))


func _refresh_hud(player_metrics: Dictionary = {}, ai_metrics: Dictionary = {}) -> void:
	var player_place := _get_player_place()
	var next_checkpoint := int(_player_progress["next_checkpoint_index"])
	var lap_display: int = mini(int(_player_progress["laps_completed"]) + 1, TOTAL_LAPS)
	if bool(_player_progress["finished"]):
		lap_display = TOTAL_LAPS

	_speed_value.text = "Скорость: %03d км/ч" % int(round(_player_car.get_speed_kph()))
	_position_value.text = "Позиция: %d / 2" % player_place
	_difficulty_value.text = "Сложность: %s" % String(_difficulty.get("name", "Средняя"))
	_lap_value.text = "Круг: %d / %d" % [lap_display, TOTAL_LAPS]
	_progress_value.text = "Чекпоинт: %d / %d" % [min(next_checkpoint, CHECKPOINT_TOTAL), CHECKPOINT_TOTAL]
	_timer_value.text = "Таймер: %s" % _format_time(_elapsed_time)
	_nitro_label.text = "Нитро: %d%% (R)" % int(round(_player_car.get_nitro_ratio() * 100.0))
	_nitro_bar.value = _player_car.get_nitro_ratio() * 100.0
	_status_value.text = _status_message if _status_timer > 0.0 else _get_default_status(player_metrics, ai_metrics)


func _get_default_status(player_metrics: Dictionary, ai_metrics: Dictionary) -> String:
	if not player_metrics.is_empty() and float(player_metrics.get("distance_to_center", 0.0)) > _track.get_road_half_width() * 0.72:
		return "Держись ворот: они ведут по кругу до финиша."
	if not ai_metrics.is_empty() and _get_player_place() == 2:
		return "Соперник впереди: длинная прямая подходит для нитро."
	return "ESC — пауза, R — нитро."


func _update_status_timer(delta: float) -> void:
	if _status_timer <= 0.0:
		return
	_status_timer = max(0.0, _status_timer - delta)


func _show_status(message: String, duration: float = 2.1) -> void:
	_status_message = message
	_status_timer = duration


func _get_player_place() -> int:
	return 1 if _get_competitor_score(_player_progress) >= _get_competitor_score(_ai_progress) else 2


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
		if car == _player_car:
			_race_finished = true
			_results_delay = 1.35
			_player_car.set_drive_input(0.0, 0.0, 1.0, false)
			_ai_car.set_drive_input(0.0, 0.0, 1.0, false)
			_player_car.set_physics_process(false)
			_ai_car.set_physics_process(false)
			_show_status("Финиш!", 3.0)
		else:
			_show_status("Соперник финишировал первым", 2.6)
	elif car == _player_car:
		_show_status("Круг %d / %d" % [int(state["laps_completed"]) + 1, TOTAL_LAPS])


func _on_player_nitro_state_changed(active: bool) -> void:
	if active:
		_show_status("Нитро включено", 1.1)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _race_finished:
			return
		_toggle_pause()


func _toggle_pause() -> void:
	_race_paused = not _race_paused
	_pause_overlay.visible = _race_paused
	_player_car.set_physics_process(not _race_paused)
	_ai_car.set_physics_process(not _race_paused)
	_resume_button.grab_focus()


func _format_time(time_seconds: float) -> String:
	var minutes := int(time_seconds / 60.0)
	var seconds := int(fmod(time_seconds, 60.0))
	var centiseconds := int(floor(fmod(time_seconds, 1.0) * 100.0))
	return "%02d:%02d.%02d" % [minutes, seconds, centiseconds]


func _open_results_screen() -> void:
	var player_position := _get_player_place()
	screen_change_requested.emit(
		"results",
		{
			"player_position": player_position,
			"player_time": float(_player_progress["finish_time"]),
			"ai_time": float(_ai_progress["finish_time"]),
			"ai_finished": bool(_ai_progress["finished"]),
			"difficulty_name": String(_difficulty.get("name", "Средняя")),
			"player_car_name": _player_car.get_car_name(),
			"ai_car_name": _ai_car.get_car_name(),
			"restart_context": _session_context.duplicate(true),
		}
	)


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
