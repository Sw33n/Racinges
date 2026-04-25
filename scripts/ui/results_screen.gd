extends Control

const RaceDifficultyCatalog = preload("res://scripts/data/race_difficulty_catalog.gd")
const UIPalette = preload("res://scripts/ui/ui_palette.gd")

signal screen_change_requested(screen_name: String, context: Dictionary)

var _context: Dictionary = {}

@onready var _header_tag: Label = $RootLayout/HeaderTag
@onready var _results_card: PanelContainer = $RootLayout/ResultsCard
@onready var _result_title: Label = $RootLayout/ResultsCard/CardPadding/CardColumn/ResultTitle
@onready var _summary_label: Label = $RootLayout/ResultsCard/CardPadding/CardColumn/SummaryLabel
@onready var _detail_list: VBoxContainer = $RootLayout/ResultsCard/CardPadding/CardColumn/DetailList
@onready var _restart_button: Button = $RootLayout/ResultsCard/CardPadding/CardColumn/ActionsRow/RestartButton
@onready var _menu_button: Button = $RootLayout/ResultsCard/CardPadding/CardColumn/ActionsRow/MenuButton


func _ready() -> void:
	_apply_styles()
	_connect_actions()
	_render_context()


func configure_screen(context: Dictionary) -> void:
	_context = context.duplicate(true)

	if is_node_ready():
		_render_context()


func _apply_styles() -> void:
	UIPalette.apply_panel_style(_results_card, UIPalette.SURFACE_PANEL, UIPalette.ACCENT_CYAN, 30, 2)
	_header_tag.add_theme_color_override("font_color", UIPalette.ACCENT_CYAN)
	_result_title.add_theme_color_override("font_color", UIPalette.TEXT_PRIMARY)
	_summary_label.add_theme_color_override("font_color", UIPalette.TEXT_MUTED)

	UIPalette.apply_button_style(
		_restart_button,
		Color(0.541176, 0.239216, 0.176471, 0.95),
		UIPalette.ACCENT_ORANGE,
		Color(0.639216, 0.254902, 0.180392, 1.0)
	)
	UIPalette.apply_button_style(
		_menu_button,
		Color(0.164706, 0.2, 0.270588, 0.95),
		Color(0.235294, 0.286275, 0.372549, 1.0),
		Color(0.133333, 0.160784, 0.219608, 1.0)
	)


func _connect_actions() -> void:
	_restart_button.pressed.connect(_on_restart_pressed)
	_menu_button.pressed.connect(_on_menu_pressed)


func _render_context() -> void:
	var place := int(_context.get("player_position", 1))
	var difficulty_name := String(_context.get("difficulty_name", RaceDifficultyCatalog.get_by_id("normal")["name"]))
	var player_time := _format_time(float(_context.get("player_time", 0.0)))
	var ai_time := _format_time(float(_context.get("ai_time", -1.0)))
	var ai_finished := bool(_context.get("ai_finished", true))

	_result_title.text = "Победа" if place == 1 else "Финиш на втором месте"
	_summary_label.text = "Одиночный заезд против ИИ завершён. Можно сразу перезапустить с тем же пресетом или вернуться в меню."

	for child in _detail_list.get_children():
		child.queue_free()

	_add_detail_row("Сложность", difficulty_name, UIPalette.ACCENT_CYAN)
	_add_detail_row("Ваша машина", String(_context.get("player_car_name", "Unknown")), UIPalette.ACCENT_ORANGE)
	_add_detail_row("Соперник", String(_context.get("ai_car_name", "Unknown")), UIPalette.ACCENT_MAGENTA)
	_add_detail_row("Ваше время", player_time, UIPalette.ACCENT_GREEN)
	_add_detail_row("Время ИИ", ai_time if ai_finished else "Не финишировал", UIPalette.ACCENT_GOLD)
	_add_detail_row("Позиция", "%d / 2" % place, UIPalette.TEXT_PRIMARY)


func _add_detail_row(label_text: String, value_text: String, accent: Color) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 14)

	var name_label := Label.new()
	name_label.text = label_text
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", UIPalette.TEXT_MUTED)
	name_label.add_theme_font_size_override("font_size", 18)

	var value_label := Label.new()
	value_label.text = value_text
	value_label.add_theme_color_override("font_color", accent)
	value_label.add_theme_font_size_override("font_size", 18)

	row.add_child(name_label)
	row.add_child(value_label)
	_detail_list.add_child(row)


func _format_time(time_seconds: float) -> String:
	if time_seconds < 0.0:
		return "--:--.--"
	var minutes := int(time_seconds / 60.0)
	var seconds := int(fmod(time_seconds, 60.0))
	var centiseconds := int(round(fmod(time_seconds, 1.0) * 100.0))
	return "%02d:%02d.%02d" % [minutes, seconds, centiseconds]


func _on_restart_pressed() -> void:
	screen_change_requested.emit("race_session", _context.get("restart_context", {}))


func _on_menu_pressed() -> void:
	screen_change_requested.emit("main_menu", {})
