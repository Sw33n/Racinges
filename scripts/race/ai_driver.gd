class_name AIDriver
extends Node


const RaceCar = preload("res://scripts/race/race_car.gd")
const RaceTrack = preload("res://scripts/race/race_track.gd")

var _car: RaceCar
var _track: RaceTrack
var _difficulty: Dictionary = {}
var _rng := RandomNumberGenerator.new()

var _progress_hint := 0.0
var _current_speed := 0.0
var _lane_offset := 0.0
var _mistake_timer := 0.0
var _mistake_bias := 0.0
var _mistake_cooldown := 0.0
var _nitro_cooldown := 0.0


func configure(car: RaceCar, track: RaceTrack, difficulty_data: Dictionary) -> void:
	_car = car
	_track = track
	_difficulty = difficulty_data.duplicate(true)
	_rng.randomize()


func update_driver(delta: float, player_progress: float) -> float:
	if _car == null or _track == null or _difficulty.is_empty():
		return _progress_hint

	if is_zero_approx(_progress_hint):
		var metrics: Dictionary = _track.get_track_metrics(_car.global_position, 0.0)
		_progress_hint = metrics["progress"]

	var lookahead: float = float(_difficulty.get("lookahead_distance", 15.0)) + _car.get_speed_mps() * 0.24
	var current_forward: Vector3 = _track.get_forward_at_distance(_progress_hint + lookahead * 0.35)
	var future_forward: Vector3 = _track.get_forward_at_distance(_progress_hint + lookahead)
	var curvature: float = clampf(1.0 - current_forward.dot(future_forward), 0.0, 1.0)

	var target_speed: float = _car.get_base_top_speed() \
		* float(_difficulty.get("target_speed_factor", 0.95)) \
		* lerpf(1.02, float(_difficulty.get("corner_factor", 0.9)), curvature) \
		* (1.0 + float(_difficulty.get("straight_bias", 0.0)))

	if _mistake_cooldown > 0.0:
		_mistake_cooldown -= delta
	elif _rng.randf() < delta / max(float(_difficulty.get("error_interval", 3.0)), 0.1):
		_mistake_timer = float(_difficulty.get("mistake_duration", 0.5))
		_mistake_bias = _rng.randf_range(-float(_difficulty.get("error_strength", 0.2)), float(_difficulty.get("error_strength", 0.2)))
		_mistake_cooldown = 1.5

	if _mistake_timer > 0.0:
		_mistake_timer -= delta
		target_speed *= 0.92

	var nitro_ready: bool = bool(_difficulty.get("ai_nitro_enabled", false)) and _nitro_cooldown <= 0.0
	var straight_enough: bool = curvature < 0.08
	var is_chasing_player: bool = player_progress > _progress_hint + 4.0
	var nitro_active: bool = nitro_ready and straight_enough and _current_speed > _car.get_base_top_speed() * 0.58 and (is_chasing_player or _rng.randf() < 0.008)
	if nitro_active:
		_nitro_cooldown = float(_difficulty.get("nitro_cooldown", 5.0))
	else:
		_nitro_cooldown = maxf(0.0, _nitro_cooldown - delta)

	var acceleration_rate: float = 18.0
	var deceleration_rate: float = 22.0
	var speed_cap: float = target_speed + (4.8 if nitro_active else 0.0)
	if _current_speed < speed_cap:
		_current_speed = minf(speed_cap, _current_speed + acceleration_rate * delta)
	else:
		_current_speed = maxf(speed_cap, _current_speed - deceleration_rate * delta)

	_progress_hint = wrapf(_progress_hint + _current_speed * delta, 0.0, _track.get_track_length())
	var lane_target: float = _mistake_bias * _track.get_road_half_width() * 0.42 if _mistake_timer > 0.0 else 0.0
	_lane_offset = lerpf(_lane_offset, lane_target, minf(1.0, 2.8 * delta))

	var center_position: Vector3 = _track.get_position_at_distance(_progress_hint)
	var forward: Vector3 = _track.get_forward_at_distance(_progress_hint + 1.3)
	var right: Vector3 = forward.cross(Vector3.UP).normalized()
	var race_position := center_position + right * _lane_offset + Vector3.UP * _track.get_race_height()
	var basis := Basis.looking_at(forward, Vector3.UP)
	_car.global_transform = Transform3D(basis, race_position)
	_car.velocity = forward * _current_speed
	_car.set_surface_factor(1.0)
	return _progress_hint
