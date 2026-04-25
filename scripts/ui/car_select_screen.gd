extends Control

const CarCatalog = preload("res://scripts/data/car_catalog.gd")
const RaceDifficultyCatalog = preload("res://scripts/data/race_difficulty_catalog.gd")
const UIPalette = preload("res://scripts/ui/ui_palette.gd")

signal screen_change_requested(screen_name: String, context: Dictionary)

var _difficulty_id := "normal"
var _garage_entries: Array[Dictionary] = []
var _roster_buttons: Array[Button] = []
var _selected_index := 0
var _difficulty: Dictionary = {}
var _opponent_car: Dictionary = {}

@onready var _header_row: BoxContainer = $RootLayout/HeaderRow
@onready var _content_row: BoxContainer = $RootLayout/ContentRow
@onready var _title: Label = $RootLayout/HeaderRow/Title
@onready var _difficulty_badge: PanelContainer = $RootLayout/HeaderRow/DifficultyBadge
@onready var _difficulty_value: Label = $RootLayout/HeaderRow/DifficultyBadge/DifficultyPadding/DifficultyValue
@onready var _back_button: Button = $RootLayout/HeaderRow/BackButton
@onready var _summary_label: Label = $RootLayout/SummaryLabel
@onready var _preview_stage: PanelContainer = $RootLayout/ContentRow/PreviewColumn/PreviewStage
@onready var _stats_card: PanelContainer = $RootLayout/ContentRow/PreviewColumn/StatsCard
@onready var _status_badge: PanelContainer = $RootLayout/ContentRow/PreviewColumn/PreviewStage/StagePadding/StageContent/StageTopRow/StatusBadge
@onready var _status_value: Label = $RootLayout/ContentRow/PreviewColumn/PreviewStage/StagePadding/StageContent/StageTopRow/StatusBadge/StatusPadding/StatusValue
@onready var _selected_role: Label = $RootLayout/ContentRow/PreviewColumn/PreviewStage/StagePadding/StageContent/StageTopRow/SelectedRole
@onready var _selected_name: Label = $RootLayout/ContentRow/PreviewColumn/PreviewStage/StagePadding/StageContent/SelectedName
@onready var _selected_description: Label = $RootLayout/ContentRow/PreviewColumn/PreviewStage/StagePadding/StageContent/SelectedDescription
@onready var _preview_backdrop: ColorRect = $RootLayout/ContentRow/PreviewColumn/PreviewStage/StagePadding/StageContent/PreviewArea/PreviewCar/PreviewBackdrop
@onready var _accent_stripe: ColorRect = $RootLayout/ContentRow/PreviewColumn/PreviewStage/StagePadding/StageContent/PreviewArea/PreviewCar/AccentStripe
@onready var _body: ColorRect = $RootLayout/ContentRow/PreviewColumn/PreviewStage/StagePadding/StageContent/PreviewArea/PreviewCar/Body
@onready var _cabin: ColorRect = $RootLayout/ContentRow/PreviewColumn/PreviewStage/StagePadding/StageContent/PreviewArea/PreviewCar/Cabin
@onready var _roster_card: PanelContainer = $RootLayout/ContentRow/RosterCard
@onready var _opponent_label: Label = $RootLayout/ContentRow/RosterCard/RosterPadding/RosterColumn/OpponentLabel
@onready var _roster_hint: Label = $RootLayout/ContentRow/RosterCard/RosterPadding/RosterColumn/RosterHint
@onready var _roster_list: VBoxContainer = $RootLayout/ContentRow/RosterCard/RosterPadding/RosterColumn/RosterList
@onready var _stats_title: Label = $RootLayout/ContentRow/PreviewColumn/StatsCard/StatsPadding/StatsColumn/StatsTitle
@onready var _stats_hint: Label = $RootLayout/ContentRow/PreviewColumn/StatsCard/StatsPadding/StatsColumn/StatsHint
@onready var _stat_list: VBoxContainer = $RootLayout/ContentRow/PreviewColumn/StatsCard/StatsPadding/StatsColumn/StatList
@onready var _footer_row: BoxContainer = $RootLayout/ContentRow/PreviewColumn/FooterRow
@onready var _start_button: Button = $RootLayout/ContentRow/PreviewColumn/FooterRow/StartButton
@onready var _footer_hint: Label = $RootLayout/ContentRow/PreviewColumn/FooterRow/FooterHint


func _ready() -> void:
	_apply_context()
	_apply_styles()
	_connect_actions()
	_build_roster_buttons()
	_render_selected_car()
	resized.connect(_update_layout)
	_update_layout()


func configure_screen(context: Dictionary) -> void:
	_difficulty_id = String(context.get("difficulty_id", "normal"))
	_apply_context()

	if is_node_ready():
		_build_roster_buttons()
		_render_selected_car()


func _apply_context() -> void:
	_garage_entries = CarCatalog.get_player_cars()
	_difficulty = RaceDifficultyCatalog.get_by_id(_difficulty_id)
	_opponent_car = CarCatalog.get_ai_car_for_difficulty(_difficulty_id)
	var default_car_id := String(CarCatalog.get_default_player_car().get("id", ""))

	_selected_index = 0
	for index in range(_garage_entries.size()):
		if _garage_entries[index]["id"] == default_car_id:
			_selected_index = index
			break


func _apply_styles() -> void:
	UIPalette.apply_panel_style(_preview_stage, UIPalette.SURFACE_PANEL, UIPalette.ACCENT_ORANGE, 30, 2)
	UIPalette.apply_panel_style(_stats_card, UIPalette.SURFACE_CARD, UIPalette.ACCENT_GOLD, 24, 2)
	UIPalette.apply_panel_style(_roster_card, UIPalette.SURFACE_PANEL, UIPalette.ACCENT_CYAN, 30, 2)
	UIPalette.apply_panel_style(
		_difficulty_badge,
		Color(_difficulty.get("panel_color", UIPalette.SURFACE_CARD)),
		Color(_difficulty.get("accent_color", UIPalette.ACCENT_CYAN)),
		18,
		2
	)

	_title.add_theme_color_override("font_color", UIPalette.TEXT_PRIMARY)
	_difficulty_value.add_theme_color_override("font_color", Color(_difficulty.get("accent_color", UIPalette.TEXT_PRIMARY)))
	_summary_label.add_theme_color_override("font_color", UIPalette.TEXT_MUTED)
	_status_value.add_theme_color_override("font_color", UIPalette.TEXT_PRIMARY)
	_selected_name.add_theme_color_override("font_color", UIPalette.TEXT_PRIMARY)
	_selected_role.add_theme_color_override("font_color", UIPalette.TEXT_MUTED)
	_selected_description.add_theme_color_override("font_color", UIPalette.TEXT_MUTED)
	_opponent_label.add_theme_color_override("font_color", UIPalette.TEXT_PRIMARY)
	_roster_hint.add_theme_color_override("font_color", UIPalette.TEXT_MUTED)
	_stats_title.add_theme_color_override("font_color", UIPalette.ACCENT_GOLD)
	_stats_hint.add_theme_color_override("font_color", UIPalette.TEXT_MUTED)
	_footer_hint.add_theme_color_override("font_color", UIPalette.TEXT_MUTED)

	UIPalette.apply_button_style(
		_back_button,
		Color(0.164706, 0.2, 0.270588, 0.95),
		Color(0.235294, 0.286275, 0.372549, 1.0),
		Color(0.133333, 0.160784, 0.219608, 1.0)
	)
	UIPalette.apply_button_style(
		_start_button,
		Color(0.541176, 0.239216, 0.176471, 0.95),
		UIPalette.ACCENT_ORANGE,
		Color(0.639216, 0.254902, 0.180392, 1.0)
	)

	_difficulty_value.text = "Сложность: %s" % String(_difficulty.get("name", "Средняя"))
	_summary_label.text = "Подберите машину под связки StoneBrook: быстрый выход с верхней прямой, стабильная дуга внизу и запас нитро для обгона."
	_opponent_label.text = "Соперник: %s" % String(_opponent_car.get("name", "Не выбран"))
	_roster_hint.text = "BMW остаётся закрытой в гараже, поэтому выбирайте из открытых машин."
	_stats_hint.text = "Параметры машины напрямую меняют разгон, зацеп и эффективность нитро."
	_footer_hint.text = "Старт заезда запускает 3 круга против призрачного ИИ."


func _connect_actions() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	_start_button.pressed.connect(_on_start_pressed)


func _update_layout() -> void:
	var is_narrow := size.x < 1220.0
	_header_row.vertical = size.x < 1040.0
	_content_row.vertical = false if size.x >= 1280.0 else is_narrow
	_footer_row.vertical = size.x < 980.0
	_back_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if _header_row.vertical else 0
	_start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if _footer_row.vertical else 0
	_roster_card.custom_minimum_size = Vector2(320 if not _content_row.vertical else 0, 0)
	_roster_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL if _content_row.vertical else 0
	_preview_stage.custom_minimum_size = Vector2(0, 280 if size.y < 760.0 else 300)
	_selected_name.add_theme_font_size_override("font_size", 30 if is_narrow else 34)
	_title.add_theme_font_size_override("font_size", 34 if is_narrow else 40)


func _build_roster_buttons() -> void:
	for child in _roster_list.get_children():
		child.queue_free()

	_roster_buttons.clear()

	for index in range(_garage_entries.size()):
		var entry: Dictionary = _garage_entries[index]
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.text = entry["name"]
		button.pressed.connect(_on_roster_button_pressed.bind(index))
		_roster_list.add_child(button)
		_roster_buttons.append(button)

	_refresh_roster_button_styles()


func _render_selected_car() -> void:
	if _garage_entries.is_empty():
		return

	var entry: Dictionary = _garage_entries[_selected_index]
	var accent_color: Color = entry["accent_color"]
	UIPalette.apply_panel_style(_status_badge, accent_color, accent_color.lightened(0.08), 18, 2)

	_status_value.text = entry["status_text"]
	_selected_role.text = entry["role"]
	_selected_name.text = entry["name"]
	_selected_description.text = entry["description"]
	_preview_backdrop.color = entry["body_color"].darkened(0.55)
	_accent_stripe.color = accent_color
	_body.color = entry["body_color"]
	_cabin.color = entry["cabin_color"]

	_rebuild_stat_rows(entry["stats"], accent_color)
	_refresh_roster_button_styles()


func _rebuild_stat_rows(stats: Dictionary, accent_color: Color) -> void:
	for child in _stat_list.get_children():
		child.queue_free()

	for stat_key in ["engine", "nitro", "tires", "transmission"]:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 6)

		var header := HBoxContainer.new()
		header.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var stat_name := Label.new()
		stat_name.text = _format_stat_name(stat_key)
		stat_name.add_theme_color_override("font_color", UIPalette.TEXT_PRIMARY)
		stat_name.add_theme_font_size_override("font_size", 16)
		stat_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var stat_value := Label.new()
		stat_value.text = "%d" % int(stats.get(stat_key, 0))
		stat_value.add_theme_color_override("font_color", accent_color)
		stat_value.add_theme_font_size_override("font_size", 16)

		var progress_bar := ProgressBar.new()
		progress_bar.show_percentage = false
		progress_bar.min_value = 0
		progress_bar.max_value = 100
		progress_bar.value = int(stats.get(stat_key, 0))
		progress_bar.custom_minimum_size = Vector2(0, 18)
		UIPalette.apply_progress_bar_style(progress_bar, accent_color)

		header.add_child(stat_name)
		header.add_child(stat_value)
		row.add_child(header)
		row.add_child(progress_bar)
		_stat_list.add_child(row)


func _refresh_roster_button_styles() -> void:
	for index in range(_roster_buttons.size()):
		var entry: Dictionary = _garage_entries[index]
		var button := _roster_buttons[index]
		var accent_color: Color = entry["accent_color"]
		var is_selected := index == _selected_index

		if is_selected:
			UIPalette.apply_button_style(
				button,
				accent_color.darkened(0.18),
				accent_color,
				accent_color.darkened(0.08)
			)
		else:
			UIPalette.apply_button_style(
				button,
				UIPalette.SURFACE_CARD,
				UIPalette.SURFACE_CARD_ALT,
				UIPalette.SURFACE_PANEL
			)

		button.text = entry["name"]


func _format_stat_name(stat_key: String) -> String:
	var labels := {
		"engine": "Двигатель",
		"nitro": "Нитро",
		"tires": "Шины",
		"transmission": "Трансмиссия",
	}
	return labels.get(stat_key, stat_key.capitalize())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()


func _on_roster_button_pressed(index: int) -> void:
	_selected_index = index
	_render_selected_car()


func _on_start_pressed() -> void:
	if _garage_entries.is_empty():
		return

	screen_change_requested.emit(
		"race_session",
		{
			"difficulty_id": _difficulty_id,
			"player_car_id": _garage_entries[_selected_index]["id"],
			"ai_car_id": _opponent_car.get("id", "dodge_challenger_srt"),
		}
	)


func _on_back_pressed() -> void:
	screen_change_requested.emit("difficulty_select", {})
