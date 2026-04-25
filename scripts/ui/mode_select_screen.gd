extends Control

const UIPalette = preload("res://scripts/ui/ui_palette.gd")

signal screen_change_requested(screen_name: String, context: Dictionary)

var _focus_mode := "ai"

@onready var _header_row: BoxContainer = $RootLayout/HeaderRow
@onready var _cards_row: BoxContainer = $RootLayout/CardsRow
@onready var _title: Label = $RootLayout/HeaderRow/Title
@onready var _back_button: Button = $RootLayout/HeaderRow/BackButton
@onready var _ai_card: PanelContainer = $RootLayout/CardsRow/AIRaceCard
@onready var _coop_card: PanelContainer = $RootLayout/CardsRow/CoopCard
@onready var _ai_title: Label = $RootLayout/CardsRow/AIRaceCard/AIRacePadding/AIRaceContent/AIRaceTitle
@onready var _ai_description: Label = $RootLayout/CardsRow/AIRaceCard/AIRacePadding/AIRaceContent/AIRaceDescription
@onready var _coop_title: Label = $RootLayout/CardsRow/CoopCard/CoopPadding/CoopContent/CoopTitle
@onready var _coop_description: Label = $RootLayout/CardsRow/CoopCard/CoopPadding/CoopContent/CoopDescription
@onready var _ai_action_button: Button = $RootLayout/CardsRow/AIRaceCard/AIRacePadding/AIRaceContent/AIRaceActionButton
@onready var _coop_action_button: Button = $RootLayout/CardsRow/CoopCard/CoopPadding/CoopContent/CoopActionButton


func _ready() -> void:
	_apply_styles()
	_connect_actions()
	resized.connect(_update_layout)
	_update_layout()
	_refresh_focus_state()


func configure_screen(context: Dictionary) -> void:
	var requested_mode := String(context.get("focus_mode", "ai"))
	_focus_mode = "local_coop" if requested_mode == "local_coop" else "ai"

	if is_node_ready():
		_refresh_focus_state()


func _apply_styles() -> void:
	_title.add_theme_color_override("font_color", UIPalette.TEXT_PRIMARY)
	_ai_description.add_theme_color_override("font_color", UIPalette.TEXT_MUTED)
	_coop_description.add_theme_color_override("font_color", UIPalette.TEXT_MUTED)

	UIPalette.apply_button_style(
		_back_button,
		Color(0.164706, 0.2, 0.270588, 0.95),
		Color(0.235294, 0.286275, 0.372549, 1.0),
		Color(0.133333, 0.160784, 0.219608, 1.0)
	)


func _connect_actions() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	_ai_action_button.pressed.connect(_on_ai_action_pressed)
	_coop_action_button.pressed.connect(_on_coop_action_pressed)


func _update_layout() -> void:
	var is_narrow := size.x < 1100.0
	_header_row.vertical = size.x < 980.0
	_cards_row.vertical = is_narrow
	_back_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if _header_row.vertical else 0
	_title.add_theme_font_size_override("font_size", 36 if is_narrow else 42)
	_ai_title.add_theme_font_size_override("font_size", 26 if is_narrow else 30)
	_coop_title.add_theme_font_size_override("font_size", 26 if is_narrow else 30)


func _refresh_focus_state() -> void:
	var ai_selected := _focus_mode == "ai"
	var coop_selected := _focus_mode == "local_coop"

	_apply_mode_card(
		_ai_card,
		_ai_title,
		_ai_action_button,
		UIPalette.ACCENT_ORANGE,
		ai_selected
	)
	_apply_mode_card(
		_coop_card,
		_coop_title,
		_coop_action_button,
		UIPalette.ACCENT_CYAN,
		coop_selected
	)


func _apply_mode_card(
	card: PanelContainer,
	title_label: Label,
	action_button: Button,
	accent_color: Color,
	is_selected: bool
) -> void:
	var fill_color := UIPalette.SURFACE_CARD_ALT if is_selected else UIPalette.SURFACE_CARD
	UIPalette.apply_panel_style(card, fill_color, accent_color, 26, 3 if is_selected else 2)
	title_label.add_theme_color_override("font_color", accent_color if is_selected else UIPalette.TEXT_PRIMARY)

	if is_selected:
		UIPalette.apply_button_style(
			action_button,
			accent_color.darkened(0.18),
			accent_color,
			accent_color.darkened(0.08)
		)
		action_button.text = "Открыть"
	else:
		UIPalette.apply_button_style(
			action_button,
			UIPalette.SURFACE_CARD,
			accent_color.darkened(0.22),
			accent_color.darkened(0.32)
		)
		action_button.text = "Выбрать"

	action_button.disabled = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()


func _on_back_pressed() -> void:
	screen_change_requested.emit("main_menu", {})


func _on_ai_action_pressed() -> void:
	_focus_mode = "ai"
	_refresh_focus_state()
	screen_change_requested.emit("difficulty_select", {})


func _on_coop_action_pressed() -> void:
	_focus_mode = "local_coop"
	_refresh_focus_state()
	screen_change_requested.emit("coop_prep", {})
