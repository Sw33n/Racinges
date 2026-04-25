class_name CarCatalog
extends RefCounted


static var _cars_cache: Array[Dictionary] = []


static func _get_source_entries() -> Array[Dictionary]:
	if _cars_cache.is_empty():
		_cars_cache = [
	{
		"id": "bmw_m3_gtr",
		"name": "BMW M3 GTR",
		"role": "Легенда для позднего открытия",
		"description": "Культовая уличная гоночная машина с мощным разгоном, стабильной управляемостью и сильной трансмиссией.",
		"locked": true,
		"status_text": "Не открыта",
		"asset_path": "res://assets/models/cars/bmw_m3_gtr.glb",
		"visual_scale": 0.86,
		"visual_yaw_degrees": 180.0,
		"hidden_nodes": PackedStringArray(),
		"body_color": Color(0.823529, 0.878431, 0.956863, 1.0),
		"cabin_color": Color(0.945098, 0.968627, 0.992157, 1.0),
		"accent_color": Color(0.286275, 0.588235, 0.937255, 1.0),
		"stats": {
			"engine": 92,
			"nitro": 86,
			"tires": 84,
			"transmission": 90,
		},
	},
	{
		"id": "dodge_challenger_srt",
		"name": "Dodge Challenger SRT",
		"role": "Тяжёлый маслкар",
		"description": "Тяжёлый маслкар с очень мощным двигателем, высоким запасом скорости и менее резким прохождением поворотов.",
		"locked": false,
		"status_text": "Доступна",
		"asset_path": "res://assets/models/cars/dodge_challenger_srt.glb",
		"visual_scale": 0.64,
		"visual_yaw_degrees": 180.0,
		"hidden_nodes": PackedStringArray(["Light", "Camera", "Plane", "Plane_001"]),
		"body_color": Color(0.196078, 0.164706, 0.180392, 1.0),
		"cabin_color": Color(0.913725, 0.262745, 0.188235, 1.0),
		"accent_color": Color(0.890196, 0.254902, 0.188235, 1.0),
		"stats": {
			"engine": 88,
			"nitro": 78,
			"tires": 68,
			"transmission": 74,
		},
	},
	{
		"id": "toyota_ae86_trueno",
		"name": "Toyota AE86 Trueno",
		"role": "Точность на дуге",
		"description": "Лёгкая классика для техничной езды: не самая быстрая на прямой, зато отлично держит траекторию.",
		"locked": false,
		"status_text": "Доступна",
		"asset_path": "res://assets/models/cars/toyota_ae86_trueno.glb",
		"visual_scale": 0.25,
		"visual_yaw_degrees": 180.0,
		"hidden_nodes": PackedStringArray(["Camera"]),
		"body_color": Color(0.933333, 0.945098, 0.952941, 1.0),
		"cabin_color": Color(0.184314, 0.196078, 0.247059, 1.0),
		"accent_color": Color(0.27451, 0.301961, 0.380392, 1.0),
		"stats": {
			"engine": 68,
			"nitro": 64,
			"tires": 88,
			"transmission": 76,
		},
	},
	{
		"id": "retro_sprint_80",
		"name": "Retro Sprint 80",
		"role": "Ретро для старта",
		"description": "Простая ретро-машина с мягким разгоном и предсказуемым поведением, хороший вариант для новичка.",
		"locked": false,
		"status_text": "Доступна",
		"asset_path": "res://assets/models/cars/retro_sprint_80.glb",
		"visual_scale": 2.78,
		"visual_yaw_degrees": 180.0,
		"hidden_nodes": PackedStringArray(),
		"body_color": Color(0.745098, 0.627451, 0.258824, 1.0),
		"cabin_color": Color(0.941176, 0.8, 0.352941, 1.0),
		"accent_color": Color(0.905882, 0.713726, 0.176471, 1.0),
		"stats": {
			"engine": 62,
			"nitro": 58,
			"tires": 72,
			"transmission": 66,
		},
	},
	{
		"id": "urban_racer",
		"name": "Urban Racer",
		"role": "Сбалансированный старт",
		"description": "Сбалансированный городской прототип, подходит для тестов и базового прохождения.",
		"locked": false,
		"status_text": "Доступна",
		"asset_path": "res://assets/models/cars/urban_racer.glb",
		"visual_scale": 0.01,
		"visual_yaw_degrees": 180.0,
		"hidden_nodes": PackedStringArray(),
		"body_color": Color(0.243137, 0.454902, 0.627451, 1.0),
		"cabin_color": Color(0.376471, 0.698039, 0.839216, 1.0),
		"accent_color": Color(0.231373, 0.72549, 0.831373, 1.0),
		"stats": {
			"engine": 74,
			"nitro": 70,
			"tires": 74,
			"transmission": 72,
		},
	},
		]
	return _cars_cache


static func get_prototype_cars() -> Array[Dictionary]:
	return _clone_entries(_get_source_entries())


static func get_cars() -> Array[Dictionary]:
	return get_prototype_cars()


static func get_player_cars() -> Array[Dictionary]:
	return _filter_locked(false)


static func get_default_player_car() -> Dictionary:
	return get_car_by_id("urban_racer")


static func get_car_by_id(car_id: String) -> Dictionary:
	for entry in _get_source_entries():
		if entry["id"] == car_id:
			return entry.duplicate(true)
	return {}


static func get_ai_car_for_difficulty(difficulty_id: String) -> Dictionary:
	match difficulty_id:
		"easy":
			return get_car_by_id("retro_sprint_80")
		"hard":
			return get_car_by_id("bmw_m3_gtr")
		_:
			return get_car_by_id("dodge_challenger_srt")


static func has_locked_cars() -> bool:
	for entry in _get_source_entries():
		if entry["locked"]:
			return true
	return false


static func _clone_entries(entries: Array) -> Array[Dictionary]:
	var cloned: Array[Dictionary] = []
	for entry in entries:
		cloned.append(entry.duplicate(true))
	return cloned


static func _filter_locked(locked_state: bool) -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []
	for entry in _get_source_entries():
		if bool(entry["locked"]) == locked_state:
			filtered.append(entry.duplicate(true))
	return filtered
