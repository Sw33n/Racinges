extends Control

const RaceDifficultyCatalog = preload("res://scripts/data/race_difficulty_catalog.gd")
const UIPalette = preload("res://scripts/ui/ui_palette.gd")

signal screen_change_requested(screen_name: String, context: Dictionary)

@onready var _header_row: BoxContainer = $RootLayout/HeaderRow
@onready var _title: Label = $RootLayout/HeaderRow/Title
@onready var _back_button: Button = $RootLayout/HeaderRow/BackButton
@onready var _description: Label = $RootLayout/Description
@onready var _cards_row: BoxContainer = $RootLayout/CardsRow


func _ready() -> void:
	_apply_styles()
	_connect_actions()
	_build_cards()
	resized.connect(_update_layout)
	_update_layout()


func _apply_styles() -> void:
	_title.add_theme_color_override("font_color", UIPalette.TEXT_PRIMARY)
	_description.add_theme_color_override("font_color", UIPalette.TEXT_MUTED)
	UIPalette.apply_button_style(
		_back_button,
		Color(0.164706, 0.2, 0.270588, 0.95),
		Color(0.235294, 0.286275, 0.372549, 1.0),
		Color(0.133333, 0.160784, 0.219608, 1.0)
	)


func _connect_actions() -> void:
	_back_button.pressed.connect(_on_back_pressed)


func _build_cards() -> void:
	for child in _cards_row.get_children():
		child.queue_free()

	for difficulty in RaceDifficultyCatalog.get_difficulties():
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(0, 260)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UIPalette.apply_panel_style(
			card,
			difficulty["panel_color"],
			difficulty["accent_color"],
			28,
			2
		)

		var padding := MarginContainer.new()
		padding.add_theme_constant_override("margin_left", 22)
		padding.add_theme_constant_override("margin_top", 22)
		padding.add_theme_constant_override("margin_right", 22)
		padding.add_theme_constant_override("margin_bottom", 22)
		card.add_child(padding)

		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 12)
		padding.add_child(content)

		var name_label := Label.new()
		name_label.text = difficulty["name"]
		name_label.add_theme_font_size_override("font_size", 30)
		name_label.add_theme_color_override("font_color", difficulty["accent_color"])
		content.add_child(name_label)

		var description_label := Label.new()
		description_label.text = difficulty["description"]
		description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description_label.add_theme_font_size_override("font_size", 18)
		description_label.add_theme_color_override("font_color", UIPalette.TEXT_MUTED)
		content.add_child(description_label)

		var action_button := Button.new()
		action_button.text = "Выбрать"
		UIPalette.apply_button_style(
			action_button,
			Color(difficulty["panel_color"]).darkened(0.06),
			Color(difficulty["accent_color"]).darkened(0.18),
			Color(difficulty["accent_color"]).darkened(0.08)
		)
		action_button.pressed.connect(_on_difficulty_pressed.bind(String(difficulty["id"])))
		content.add_child(action_button)

		_cards_row.add_child(card)


func _update_layout() -> void:
	var is_narrow := size.x < 1180.0
	_header_row.vertical = size.x < 980.0
	_cards_row.vertical = is_narrow
	_back_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if _header_row.vertical else 0
	_title.add_theme_font_size_override("font_size", 36 if is_narrow else 42)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()


func _on_difficulty_pressed(difficulty_id: String) -> void:
	screen_change_requested.emit("car_select", {"difficulty_id": difficulty_id})


func _on_back_pressed() -> void:
	screen_change_requested.emit("mode_select", {"focus_mode": "ai"})
