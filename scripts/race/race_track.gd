class_name RaceTrack
extends Node3D


signal gate_crossed(car: Node, gate_type: String, gate_index: int)

const TRACK_VISUAL := preload("res://assets/models/tracks/stonebrook_race_circuit.glb")

const _MODEL_CENTER_RAW := Vector3(6948.091, 0.0, -6271.735)
const _MODEL_SCALE := 0.012
const _ROAD_WIDTH := 7.2
const _ROAD_HEIGHT := 0.32
const _ROAD_THICKNESS := 0.18
const _MARKER_HEIGHT := 6.6
const _MARKER_THICKNESS := 0.12

const _RAW_CONTROL_POINTS := [
	Vector3(6141.2, 0.0, -3402.2),
	Vector3(9152.4, 0.0, -3402.2),
	Vector3(11724.5, 0.0, -3402.2),
	Vector3(12665.5, 0.0, -5403.2),
	Vector3(11159.9, 0.0, -8888.9),
	Vector3(9403.4, 0.0, -9534.4),
	Vector3(7646.8, 0.0, -8759.8),
	Vector3(6266.6, 0.0, -6952.4),
	Vector3(5137.4, 0.0, -6048.7),
	Vector3(3255.4, 0.0, -7985.2),
	Vector3(1749.8, 0.0, -7210.6),
	Vector3(2251.6, 0.0, -5532.3),
	Vector3(4384.6, 0.0, -4886.8),
	Vector3(5388.4, 0.0, -3725.0),
]

const _START_DISTANCE := 10.0
const _FINISH_DISTANCE := 22.0
const _CHECKPOINT_FRACTIONS := [0.18, 0.35, 0.54, 0.72, 0.86]

var _curve := Curve3D.new()
var _baked_points := PackedVector3Array()
var _baked_lengths: Array[float] = []
var _track_length := 0.0


func _ready() -> void:
	_build_curve()
	_build_visual_model()
	_build_road_mesh()
	_build_edge_line_mesh()
	_build_markers()


func get_track_length() -> float:
	return _track_length


func get_road_width() -> float:
	return _ROAD_WIDTH


func get_road_half_width() -> float:
	return _ROAD_WIDTH * 0.5


func get_race_height() -> float:
	return _ROAD_HEIGHT


func get_position_at_distance(distance: float) -> Vector3:
	return _curve.sample_baked(_wrap_distance(distance), true)


func get_forward_at_distance(distance: float) -> Vector3:
	var previous := get_position_at_distance(distance - 1.4)
	var upcoming := get_position_at_distance(distance + 1.4)
	return (upcoming - previous).normalized()


func get_track_metrics(position: Vector3, _hint_progress: float = 0.0) -> Dictionary:
	var nearest_index := 0
	var best_distance := INF
	var flat_position := Vector2(position.x, position.z)

	for index in range(_baked_points.size()):
		var point := _baked_points[index]
		var current_distance := flat_position.distance_squared_to(Vector2(point.x, point.z))
		if current_distance < best_distance:
			best_distance = current_distance
			nearest_index = index

	var nearest_point := _baked_points[nearest_index]
	return {
		"progress": _baked_lengths[nearest_index],
		"distance_to_center": sqrt(best_distance),
		"nearest_point": nearest_point,
	}


func get_surface_factor(position: Vector3) -> float:
	return 1.0


func get_spawn_transform(slot_index: int) -> Transform3D:
	var distance := _wrap_distance(_START_DISTANCE - 8.0 - slot_index * 4.8)
	var position := get_position_at_distance(distance)
	var forward := get_forward_at_distance(distance)
	var right := forward.cross(Vector3.UP).normalized()
	position += right * (-_ROAD_WIDTH * 0.18 if slot_index == 0 else _ROAD_WIDTH * 0.18)
	position.y = get_race_height()
	var basis := Basis.looking_at(forward, Vector3.UP)
	return Transform3D(basis, position)


func get_finish_distance() -> float:
	return _FINISH_DISTANCE


func get_checkpoint_distances() -> Array[float]:
	var distances: Array[float] = []
	for fraction in _CHECKPOINT_FRACTIONS:
		distances.append(_track_length * float(fraction))
	return distances


func _build_curve() -> void:
	_curve = Curve3D.new()
	_curve.bake_interval = 1.6
	_curve.closed = true

	var points: Array[Vector3] = []
	for raw_point in _RAW_CONTROL_POINTS:
		points.append(_to_track_space(raw_point))

	for index in range(points.size()):
		var point := points[index]
		var previous := points[(index - 1 + points.size()) % points.size()]
		var next := points[(index + 1) % points.size()]
		var tangent := (next - previous) / 6.0
		_curve.add_point(point, -tangent, tangent)

	_baked_points = _curve.get_baked_points()
	_baked_lengths.clear()
	_baked_lengths.append(0.0)
	_track_length = 0.0

	for index in range(1, _baked_points.size()):
		_track_length += _baked_points[index - 1].distance_to(_baked_points[index])
		_baked_lengths.append(_track_length)


func _build_visual_model() -> void:
	var visual_root := TRACK_VISUAL.instantiate() as Node3D
	visual_root.scale = Vector3.ONE * _MODEL_SCALE
	visual_root.position = Vector3(-_MODEL_CENTER_RAW.x * _MODEL_SCALE, 0.0, -_MODEL_CENTER_RAW.z * _MODEL_SCALE)
	add_child(visual_root)


func _build_road_mesh() -> void:
	var road_mesh := MeshInstance3D.new()
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.102, 0.117, 0.145, 1.0)
	material.roughness = 0.96
	material.metallic = 0.02
	road_mesh.material_override = material

	for index in range(_baked_points.size()):
		var current := _baked_points[index]
		var next := _baked_points[(index + 1) % _baked_points.size()]
		var tangent := (next - current).normalized()
		var right := tangent.cross(Vector3.UP).normalized()

		var current_left := current - right * _ROAD_WIDTH * 0.5
		var current_right := current + right * _ROAD_WIDTH * 0.5
		var next_left := next - right * _ROAD_WIDTH * 0.5
		var next_right := next + right * _ROAD_WIDTH * 0.5

		current_left.y = _ROAD_HEIGHT
		current_right.y = _ROAD_HEIGHT
		next_left.y = _ROAD_HEIGHT
		next_right.y = _ROAD_HEIGHT

		surface_tool.set_normal(Vector3.UP)
		surface_tool.set_uv(Vector2(0.0, _baked_lengths[index] * 0.08))
		surface_tool.add_vertex(current_left)
		surface_tool.set_uv(Vector2(1.0, _baked_lengths[index] * 0.08))
		surface_tool.add_vertex(current_right)
		surface_tool.set_uv(Vector2(0.0, _baked_lengths[(index + 1) % _baked_lengths.size()] * 0.08))
		surface_tool.add_vertex(next_left)

		surface_tool.set_normal(Vector3.UP)
		surface_tool.set_uv(Vector2(1.0, _baked_lengths[index] * 0.08))
		surface_tool.add_vertex(current_right)
		surface_tool.set_uv(Vector2(1.0, _baked_lengths[(index + 1) % _baked_lengths.size()] * 0.08))
		surface_tool.add_vertex(next_right)
		surface_tool.set_uv(Vector2(0.0, _baked_lengths[(index + 1) % _baked_lengths.size()] * 0.08))
		surface_tool.add_vertex(next_left)

	var mesh := surface_tool.commit()
	road_mesh.mesh = mesh
	add_child(road_mesh)


func _build_edge_line_mesh() -> void:
	var line_mesh := MeshInstance3D.new()
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.878, 0.443, 0.235, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.615, 0.251, 0.141, 1.0)
	material.emission_energy_multiplier = 0.6
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mesh.material_override = material

	for index in range(_baked_points.size()):
		var current := _baked_points[index]
		var next := _baked_points[(index + 1) % _baked_points.size()]
		var tangent := (next - current).normalized()
		var right := tangent.cross(Vector3.UP).normalized()

		for side in [-1.0, 1.0]:
			var inner_current: Vector3 = current + right * (_ROAD_WIDTH * 0.5 - 0.2) * side
			var outer_current: Vector3 = current + right * (_ROAD_WIDTH * 0.5 - 0.05) * side
			var inner_next: Vector3 = next + right * (_ROAD_WIDTH * 0.5 - 0.2) * side
			var outer_next: Vector3 = next + right * (_ROAD_WIDTH * 0.5 - 0.05) * side

			inner_current.y = _ROAD_HEIGHT + 0.01
			outer_current.y = _ROAD_HEIGHT + 0.01
			inner_next.y = _ROAD_HEIGHT + 0.01
			outer_next.y = _ROAD_HEIGHT + 0.01

			surface_tool.set_normal(Vector3.UP)
			surface_tool.add_vertex(inner_current)
			surface_tool.add_vertex(outer_current)
			surface_tool.add_vertex(inner_next)
			surface_tool.add_vertex(outer_current)
			surface_tool.add_vertex(outer_next)
			surface_tool.add_vertex(inner_next)

	var mesh := surface_tool.commit()
	line_mesh.mesh = mesh
	add_child(line_mesh)


func _build_markers() -> void:
	_create_visual_gate("start", -1, _START_DISTANCE, Color(0.345098, 0.843137, 0.490196, 0.38), false)
	_create_visual_gate("finish", -1, _FINISH_DISTANCE, Color(0.968627, 0.286275, 0.501961, 0.38), true)

	var checkpoints := get_checkpoint_distances()
	for index in range(checkpoints.size()):
		_create_visual_gate(
			"checkpoint",
			index,
			checkpoints[index],
			Color(0.215686, 0.870588, 0.909804, 0.3) if index % 2 == 0 else Color(0.992157, 0.768627, 0.262745, 0.3),
			true
		)


func _create_visual_gate(gate_type: String, gate_index: int, distance: float, tint: Color, monitor_crossing: bool) -> void:
	var gate_root := Node3D.new()
	gate_root.name = "%s_gate_%d" % [gate_type, gate_index]
	var gate_position := get_position_at_distance(distance)
	var forward := get_forward_at_distance(distance)
	var basis := Basis.looking_at(forward, Vector3.UP)
	gate_root.transform = Transform3D(basis, gate_position + Vector3.UP * (_MARKER_HEIGHT * 0.5))
	add_child(gate_root)

	if monitor_crossing:
		var area := Area3D.new()
		area.monitoring = true
		area.collision_layer = 0
		area.collision_mask = 1 << 1
		var collision_shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(_ROAD_WIDTH + 1.2, _MARKER_HEIGHT, 2.6)
		collision_shape.shape = box
		area.add_child(collision_shape)
		area.body_entered.connect(_on_gate_body_entered.bind(gate_type, gate_index))
		gate_root.add_child(area)

	var mesh_instance := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(_ROAD_WIDTH + 0.9, _MARKER_HEIGHT)
	mesh_instance.mesh = quad
	mesh_instance.rotation.y = PI * 0.5
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = 1.1
	mesh_instance.material_override = material
	gate_root.add_child(mesh_instance)

	var stripe := MeshInstance3D.new()
	var stripe_mesh := BoxMesh.new()
	stripe_mesh.size = Vector3(_ROAD_WIDTH + 0.4, 0.03, 1.8)
	stripe.mesh = stripe_mesh
	stripe.position.y = -_MARKER_HEIGHT * 0.5 + 0.02
	var stripe_material := StandardMaterial3D.new()
	stripe_material.albedo_color = tint.lightened(0.1)
	stripe_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	stripe_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	stripe.material_override = stripe_material
	gate_root.add_child(stripe)


func _on_gate_body_entered(body: Node, gate_type: String, gate_index: int) -> void:
	gate_crossed.emit(body, gate_type, gate_index)


func _wrap_distance(distance: float) -> float:
	if _track_length <= 0.0:
		return 0.0
	return wrapf(distance, 0.0, _track_length)


func _to_track_space(raw_point: Vector3) -> Vector3:
	return Vector3(
		(raw_point.x - _MODEL_CENTER_RAW.x) * _MODEL_SCALE,
		_ROAD_HEIGHT,
		(raw_point.z - _MODEL_CENTER_RAW.z) * _MODEL_SCALE
	)
