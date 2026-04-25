class_name RaceDifficultyCatalog
extends RefCounted


static var _difficulty_cache: Array[Dictionary] = []


static func _get_source_entries() -> Array[Dictionary]:
	if _difficulty_cache.is_empty():
		_difficulty_cache = [
	{
		"id": "easy",
		"name": "Лёгкая",
		"description": "Соперник едет на более слабой машине, чаще ошибается и раньше отпускает газ в поворотах.",
		"accent_color": Color(0.345098, 0.843137, 0.490196, 1.0),
		"panel_color": Color(0.113725, 0.227451, 0.172549, 0.96),
		"ai_car_id": "retro_sprint_80",
		"target_speed_factor": 0.86,
		"corner_factor": 0.83,
		"error_interval": 4.6,
		"error_strength": 0.24,
		"mistake_duration": 0.85,
		"lookahead_distance": 13.0,
		"straight_bias": -0.06,
		"ai_nitro_enabled": false,
		"nitro_cooldown": 0.0,
	},
	{
		"id": "normal",
		"name": "Средняя",
		"description": "Ровный темп без лишней агрессии: соперник держится ближе к траектории и меньше теряет время на выходах.",
		"accent_color": Color(0.215686, 0.870588, 0.909804, 1.0),
		"panel_color": Color(0.0980392, 0.176471, 0.254902, 0.96),
		"ai_car_id": "dodge_challenger_srt",
		"target_speed_factor": 0.95,
		"corner_factor": 0.91,
		"error_interval": 3.2,
		"error_strength": 0.16,
		"mistake_duration": 0.55,
		"lookahead_distance": 15.0,
		"straight_bias": -0.01,
		"ai_nitro_enabled": false,
		"nitro_cooldown": 0.0,
	},
	{
		"id": "hard",
		"name": "Сложная",
		"description": "Быстрый и аккуратный соперник на сильной машине. Может прожимать нитро на длинных прямых, но всё ещё оставляет пространство для победы.",
		"accent_color": Color(0.992157, 0.427451, 0.223529, 1.0),
		"panel_color": Color(0.243137, 0.113725, 0.0745098, 0.96),
		"ai_car_id": "bmw_m3_gtr",
		"target_speed_factor": 1.01,
		"corner_factor": 0.98,
		"error_interval": 2.4,
		"error_strength": 0.11,
		"mistake_duration": 0.35,
		"lookahead_distance": 16.5,
		"straight_bias": 0.03,
		"ai_nitro_enabled": true,
		"nitro_cooldown": 5.2,
	},
		]
	return _difficulty_cache


static func get_difficulties() -> Array[Dictionary]:
	var cloned: Array[Dictionary] = []
	for entry in _get_source_entries():
		cloned.append(entry.duplicate(true))
	return cloned


static func get_by_id(difficulty_id: String) -> Dictionary:
	for entry in _get_source_entries():
		if entry["id"] == difficulty_id:
			return entry.duplicate(true)
	return _get_source_entries()[1].duplicate(true)
