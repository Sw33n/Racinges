extends Control

const MAIN_MENU_SCREEN := preload("res://scenes/ui/main_menu_screen.tscn")
const MODE_SELECT_SCREEN := preload("res://scenes/ui/mode_select_screen.tscn")
const GARAGE_SCREEN := preload("res://scenes/ui/garage_screen.tscn")
const DIFFICULTY_SELECT_SCREEN := preload("res://scenes/ui/difficulty_select_screen.tscn")
const CAR_SELECT_SCREEN := preload("res://scenes/ui/car_select_screen.tscn")
const COOP_PREP_SCREEN := preload("res://scenes/ui/coop_prep_screen.tscn")
const RACE_SESSION_SCREEN := preload("res://scenes/race/race_session_screen.tscn")
const RESULTS_SCREEN := preload("res://scenes/ui/results_screen.tscn")
const UIPalette = preload("res://scripts/ui/ui_palette.gd")

var _screen_registry := {
	"main_menu": MAIN_MENU_SCREEN,
	"mode_select": MODE_SELECT_SCREEN,
	"garage": GARAGE_SCREEN,
	"difficulty_select": DIFFICULTY_SELECT_SCREEN,
	"car_select": CAR_SELECT_SCREEN,
	"coop_prep": COOP_PREP_SCREEN,
	"race_session": RACE_SESSION_SCREEN,
	"results": RESULTS_SCREEN,
}

var _current_screen: Control

@onready var _brand_title: Label = $MainMargin/RootStack/TopRow/BrandTitle
@onready var _screen_frame: PanelContainer = $MainMargin/RootStack/ScreenFrame
@onready var _screen_host: Control = $MainMargin/RootStack/ScreenFrame/ScreenPadding/ScreenHost


func _ready() -> void:
	_set_window_title()
	_apply_shell_styles()
	resized.connect(_update_shell_layout)
	_update_shell_layout()
	_show_screen("main_menu")


func _set_window_title() -> void:
	get_window().title = "Racinges"


func _apply_shell_styles() -> void:
	UIPalette.apply_panel_style(_screen_frame, UIPalette.SURFACE_FRAME, UIPalette.ACCENT_MAGENTA, 32, 2)
	_brand_title.add_theme_color_override("font_color", UIPalette.TEXT_PRIMARY)


func _update_shell_layout() -> void:
	_brand_title.add_theme_font_size_override("font_size", 44 if size.y < 760.0 else 54)


func _show_screen(screen_name: String, context: Dictionary = {}) -> void:
	var screen_scene: PackedScene = _screen_registry.get(screen_name)
	if screen_scene == null:
		push_warning("Unknown screen requested: %s" % screen_name)
		return

	if is_instance_valid(_current_screen):
		_current_screen.queue_free()

	_current_screen = screen_scene.instantiate()
	_screen_host.add_child(_current_screen)
	_current_screen.connect("screen_change_requested", Callable(self, "_on_screen_change_requested"))

	if _current_screen.has_signal("exit_requested"):
		_current_screen.connect("exit_requested", Callable(self, "_on_exit_requested"))

	if _current_screen.has_method("configure_screen"):
		_current_screen.call("configure_screen", context)


func _on_screen_change_requested(screen_name: String, context: Dictionary = {}) -> void:
	_show_screen(screen_name, context)


func _on_exit_requested() -> void:
	get_tree().quit()
