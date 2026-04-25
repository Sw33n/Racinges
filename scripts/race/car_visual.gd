class_name CarVisual
extends Node3D


var _car_data: Dictionary = {}
var _ghost_mode := false
var _visual_root: Node3D


func _ready() -> void:
	if not _car_data.is_empty():
		_rebuild_visual()


func configure(car_data: Dictionary, ghost_mode: bool = false) -> void:
	_car_data = car_data.duplicate(true)
	_ghost_mode = ghost_mode

	if is_node_ready():
		_rebuild_visual()


func _rebuild_visual() -> void:
	if is_instance_valid(_visual_root):
		_visual_root.queue_free()

	var scene_path := String(_car_data.get("asset_path", ""))
	var visual_scene: PackedScene = load(scene_path)
	if visual_scene == null:
		push_warning("Unable to load car scene: %s" % scene_path)
		return

	_visual_root = visual_scene.instantiate() as Node3D
	add_child(_visual_root)

	var hidden_nodes: PackedStringArray = _car_data.get("hidden_nodes", PackedStringArray())
	for node_name in hidden_nodes:
		var target := _visual_root.find_child(node_name, true, false)
		if target != null:
			target.visible = false

	var scale_factor := float(_car_data.get("visual_scale", 1.0))
	_visual_root.scale = Vector3.ONE * scale_factor

	var yaw_offset := deg_to_rad(float(_car_data.get("visual_yaw_degrees", 0.0)))
	if not is_zero_approx(yaw_offset):
		_visual_root.rotate_y(yaw_offset)

	var local_box := _calculate_local_aabb(_visual_root, Transform3D.IDENTITY)
	var box_center := local_box.position + local_box.size * 0.5
	_visual_root.position = Vector3(-box_center.x, -local_box.position.y, -box_center.z)

	if _ghost_mode:
		_apply_ghost_treatment(_visual_root)


func _apply_ghost_treatment(node: Node) -> void:
	if node is GeometryInstance3D:
		node.transparency = 0.33
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	for child in node.get_children():
		_apply_ghost_treatment(child)


func _calculate_local_aabb(node: Node, parent_transform: Transform3D) -> AABB:
	var merged := AABB()
	var has_box := false

	var node_transform := parent_transform
	if node is Node3D:
		node_transform = parent_transform * node.transform

	if node is MeshInstance3D and node.visible and node.mesh != null:
		merged = node_transform * node.mesh.get_aabb()
		has_box = true

	for child in node.get_children():
		var child_box := _calculate_local_aabb(child, node_transform)
		if child_box.size != Vector3.ZERO:
			merged = child_box if not has_box else merged.merge(child_box)
			has_box = true

	return merged if has_box else AABB()
