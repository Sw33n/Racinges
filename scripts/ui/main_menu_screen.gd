extends Control

const UIPalette = preload("res://scripts/ui/ui_palette.gd")

signal screen_change_requested(screen_name: String, context: Dictionary)
signal exit_requested()

@onready var _root_layout: BoxContainer = $RootLayout
@onready var _headline: Label = $RootLayout/HeroColumn/Headline
@onready var _description: Label = $RootLayout/HeroColumn/Description
@onready var _actions_card: PanelContainer = $RootLayout/ActionsCard
@onready var _play_button: Button = $RootLayout/ActionsCard/ActionsPadding/ActionsColumn/PlayButton
@onready var _garage_button: Button = $RootLayout/ActionsCard/ActionsPadding/ActionsColumn/GarageButton
@onready var _settings_button: Button = $RootLayout/ActionsCard/ActionsPadding/ActionsColumn/SettingsButton
@onready var _exit_button: Button = $RootLayout/ActionsCard/ActionsPadding/ActionsColumn/ExitButton


func _ready() -> void:
	_apply_styles()
	_connect_actions()
	resized.connect(_update_layout)
	_update_layout()
	_play_button.grab_focus()


func _apply_styles() -> void:
	UIPalette.apply_panel_style(_actions_card, UIPalette.SURFACE_PANEL, UIPalette.ACCENT_ORANGE, 30, 2)

	_headline.add_theme_color_override("font_color", UIPalette.TEXT_PRIMARY)
	_description.add_theme_color_override("font_color", UIPalette.TEXT_MUTED)

	UIPalette.apply_button_style(
		_play_button,
		Color(0.541176, 0.239216, 0.176471, 0.95),
		UIPalette.ACCENT_ORANGE,
		Color(0.639216, 0.254902, 0.180392, 1.0)
	)
	UIPalette.apply_button_style(
		_garage_button,
		Color(0.431373, 0.14902, 0.305882, 0.95),
		UIPalette.ACCENT_MAGENTA,
		Color(0.517647, 0.141176, 0.341176, 1.0)
	)
	UIPalette.apply_button_style(
		_settings_button,
		Color(0.298039, 0.262745, 0.113725, 0.95),
		UIPalette.ACCENT_GOLD,
		Color(0.403922, 0.337255, 0.0784314, 1.0),
		Color(0.0823529, 0.105882, 0.14902, 1.0)
	)
	UIPalette.apply_button_style(
		_exit_button,
		Color(0.180392, 0.215686, 0.286275, 0.95),
		Color(0.27451, 0.313726, 0.403922, 1.0),
		Color(0.141176, 0.176471, 0.243137, 1.0)
	)


func _update_layout() -> void:
	var is_narrow := size.x < 1080.0
	_root_layout.vertical = is_narrow
	_actions_card.custom_minimum_size = Vector2(0 if is_narrow else 360, 0)
	_actions_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL if is_narrow else 0
	_headline.add_theme_font_size_override("font_size", 38 if size.y < 720.0 else 44)
	_description.add_theme_font_size_override("font_size", 18 if is_narrow else 20)


func _connect_actions() -> void:
	_play_button.pressed.connect(_on_play_pressed)
	_garage_button.pressed.connect(_on_garage_pressed)
	_exit_button.pressed.connect(_on_exit_pressed)


func _on_play_pressed() -> void:
	screen_change_requested.emit("mode_select", {"focus_mode": "ai"})


func _on_garage_pressed() -> void:
	screen_change_requested.emit("garage", {})


func _on_exit_pressed() -> void:
	exit_requested.emit()
