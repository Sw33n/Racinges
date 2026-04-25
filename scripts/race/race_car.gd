class_name RaceCar
extends CharacterBody3D


const CarVisual = preload("res://scripts/race/car_visual.gd")

signal nitro_state_changed(active: bool)

const _BODY_SIZE: Vector3 = Vector3(1.75, 0.95, 3.2)

var car_data: Dictionary = {}
var is_player: bool = false

var _throttle_input: float = 0.0
var _steer_input: float = 0.0
var _brake_input: float = 0.0
var _nitro_requested: bool = false
var _surface_factor: float = 1.0
var _ride_height: float = 0.58

var _max_speed: float = 42.0
var _reverse_speed: float = 14.0
var _engine_force: float = 26.0
var _reverse_force: float = 10.0
var _brake_force: float = 34.0
var _grip: float = 7.4
var _steer_low_speed: float = 1.82
var _steer_high_speed: float = 0.66
var _nitro_acceleration: float = 12.5
var _nitro_bonus_speed: float = 8.0
var _nitro_capacity: float = 4.2
var _nitro_charge: float = 4.2
var _nitro_recharge: float = 0.32
var _nitro_active: bool = false

var _body_shape: CollisionShape3D
var _visual: CarVisual


func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = 1 << 1
	collision_mask = 0

	_body_shape = CollisionShape3D.new()
	var body_box: BoxShape3D = BoxShape3D.new()
	body_box.size = _BODY_SIZE
	_body_shape.shape = body_box
	_body_shape.position.y = _BODY_SIZE.y * 0.5
	add_child(_body_shape)

	_visual = CarVisual.new()
	add_child(_visual)

	if not car_data.is_empty():
		_apply_car_setup(false)


func configure(car_config: Dictionary, player_controlled: bool, ghost_mode: bool = false) -> void:
	car_data = car_config.duplicate(true)
	is_player = player_controlled

	if is_node_ready():
		_apply_car_setup(ghost_mode)


func set_drive_input(throttle: float, steer: float, brake: float, nitro_active: bool) -> void:
	_throttle_input = clampf(throttle, -1.0, 1.0)
	_steer_input = clampf(steer, -1.0, 1.0)
	_brake_input = clampf(brake, 0.0, 1.0)
	_nitro_requested = nitro_active


func set_surface_factor(surface_factor: float) -> void:
	_surface_factor = clampf(surface_factor, 0.38, 1.0)


func set_ride_height(ride_height: float) -> void:
	_ride_height = ride_height


func reset_to_transform(spawn_transform: Transform3D) -> void:
	global_transform = spawn_transform
	global_position.y = _ride_height
	velocity = Vector3.ZERO
	_nitro_charge = _nitro_capacity
	_set_nitro_state(false)


func get_speed_kph() -> float:
	return get_speed_mps() * 3.6


func get_speed_mps() -> float:
	return Vector3(velocity.x, 0.0, velocity.z).length()


func get_nitro_ratio() -> float:
	return 0.0 if is_zero_approx(_nitro_capacity) else clampf(_nitro_charge / _nitro_capacity, 0.0, 1.0)


func get_car_name() -> String:
	return String(car_data.get("name", "Unknown"))


func get_accent_color() -> Color:
	return car_data.get("accent_color", Color.WHITE)


func get_base_top_speed() -> float:
	return _max_speed


func _physics_process(delta: float) -> void:
	if car_data.is_empty():
		return

	var forward: Vector3 = -global_basis.z
	var planar_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var forward_speed: float = planar_velocity.dot(forward)
	var top_speed: float = _max_speed * _surface_factor
	var grip_factor: float = _grip * _surface_factor

	var speed_ratio: float = clampf(abs(forward_speed) / maxf(top_speed, 0.01), 0.0, 1.0)
	var steer_strength: float = lerpf(_steer_low_speed, _steer_high_speed, speed_ratio) * (0.45 + 0.55 * _surface_factor)
	var steering: float = _steer_input * steer_strength
	var steering_direction: float = sign(forward_speed)
	if is_zero_approx(steering_direction):
		steering_direction = sign(_throttle_input) if not is_zero_approx(_throttle_input) else 1.0
	rotate_y(-steering * steering_direction * delta)

	forward = -global_basis.z
	forward_speed = planar_velocity.dot(forward)
	var lateral_velocity: Vector3 = planar_velocity - forward * forward_speed
	planar_velocity -= lateral_velocity * minf(1.0, grip_factor * delta)

	var acceleration: float = 0.0
	if _throttle_input > 0.0:
		acceleration += _engine_force * _throttle_input * _surface_factor
	elif _throttle_input < 0.0:
		var reverse_factor: float = 1.0 if forward_speed < 2.0 else 0.35
		acceleration += _reverse_force * _throttle_input * reverse_factor

	if _brake_input > 0.0:
		acceleration -= sign(forward_speed) * _brake_force * _brake_input
		if abs(forward_speed) < 1.4:
			planar_velocity = planar_velocity.lerp(Vector3.ZERO, minf(1.0, 5.0 * delta))

	var can_use_nitro: bool = _nitro_requested and _throttle_input > 0.2 and _nitro_charge > 0.05 and forward_speed > 3.0
	if can_use_nitro:
		acceleration += _nitro_acceleration
		top_speed += _nitro_bonus_speed
		_nitro_charge = maxf(0.0, _nitro_charge - delta)
	else:
		_nitro_charge = minf(_nitro_capacity, _nitro_charge + _nitro_recharge * delta)

	_set_nitro_state(can_use_nitro)

	planar_velocity += forward * acceleration * delta
	var drag: float = 0.95 + speed_ratio * 1.3 + (0.35 if _surface_factor < 0.7 else 0.0)
	planar_velocity -= planar_velocity * minf(0.92, drag * delta)

	var clamped_limit: float = top_speed if forward_speed >= 0.0 else _reverse_speed
	if planar_velocity.length() > clamped_limit:
		planar_velocity = planar_velocity.normalized() * clamped_limit

	velocity.x = planar_velocity.x
	velocity.y = 0.0
	velocity.z = planar_velocity.z
	move_and_slide()
	global_position.y = _ride_height
	rotation.x = 0.0
	rotation.z = 0.0


func _apply_car_setup(ghost_mode: bool) -> void:
	_visual.configure(car_data, ghost_mode)
	_build_performance_profile()
	_nitro_charge = _nitro_capacity


func _build_performance_profile() -> void:
	var stats: Dictionary = car_data.get("stats", {})
	var engine: float = float(stats.get("engine", 70)) / 100.0
	var nitro: float = float(stats.get("nitro", 70)) / 100.0
	var tires: float = float(stats.get("tires", 70)) / 100.0
	var transmission: float = float(stats.get("transmission", 70)) / 100.0

	_max_speed = lerpf(37.0, 53.5, engine * 0.62 + transmission * 0.38)
	_reverse_speed = lerpf(10.5, 14.5, transmission)
	_engine_force = lerpf(21.0, 31.5, engine)
	_reverse_force = lerpf(8.0, 12.5, transmission)
	_brake_force = lerpf(30.0, 38.0, tires * 0.55 + transmission * 0.45)
	_grip = lerpf(6.1, 9.8, tires)
	_steer_low_speed = lerpf(1.44, 1.95, tires)
	_steer_high_speed = lerpf(0.52, 0.82, transmission * 0.4 + tires * 0.6)
	_nitro_acceleration = lerpf(9.5, 15.0, nitro)
	_nitro_bonus_speed = lerpf(5.0, 9.5, nitro * 0.75 + engine * 0.25)
	_nitro_capacity = lerpf(3.0, 5.1, nitro)
	_nitro_recharge = lerpf(0.21, 0.42, nitro * 0.6 + transmission * 0.4)


func _set_nitro_state(active: bool) -> void:
	if _nitro_active == active:
		return

	_nitro_active = active
	nitro_state_changed.emit(_nitro_active)
