class_name UIPalette
extends RefCounted

const BASE_BACKGROUND := Color(0.0509804, 0.0705882, 0.101961, 1.0)
const SURFACE_PANEL := Color(0.0941176, 0.133333, 0.192157, 0.96)
const SURFACE_FRAME := Color(0.0823529, 0.113725, 0.168627, 0.94)
const SURFACE_CARD := Color(0.121569, 0.164706, 0.239216, 0.98)
const SURFACE_CARD_ALT := Color(0.137255, 0.176471, 0.258824, 0.98)
const TEXT_PRIMARY := Color(0.952941, 0.964706, 0.988235, 1.0)
const TEXT_MUTED := Color(0.690196, 0.756863, 0.831373, 1.0)
const TEXT_SUBTLE := Color(0.545098, 0.615686, 0.694118, 1.0)
const ACCENT_CYAN := Color(0.215686, 0.870588, 0.909804, 1.0)
const ACCENT_ORANGE := Color(0.992157, 0.427451, 0.223529, 1.0)
const ACCENT_MAGENTA := Color(0.968627, 0.286275, 0.501961, 1.0)
const ACCENT_GOLD := Color(0.968627, 0.768627, 0.262745, 1.0)
const ACCENT_GREEN := Color(0.345098, 0.843137, 0.490196, 1.0)


static func apply_panel_style(
	panel: PanelContainer,
	fill_color: Color,
	border_color: Color,
	corner_radius: int = 24,
	border_width: int = 2
) -> void:
	panel.add_theme_stylebox_override(
		"panel",
		_create_panel_style(fill_color, border_color, corner_radius, border_width)
	)


static func apply_button_style(
	button: Button,
	normal_color: Color,
	hover_color: Color,
	pressed_color: Color,
	text_color: Color = TEXT_PRIMARY
) -> void:
	button.custom_minimum_size = Vector2(0, 58)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override(
		"normal",
		_create_panel_style(normal_color, normal_color.lightened(0.18), 22, 2)
	)
	button.add_theme_stylebox_override(
		"hover",
		_create_panel_style(hover_color, hover_color.lightened(0.14), 22, 2)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_create_panel_style(pressed_color, pressed_color.lightened(0.08), 22, 2)
	)
	button.add_theme_stylebox_override(
		"focus",
		_create_panel_style(hover_color, ACCENT_GOLD, 22, 3)
	)
	button.add_theme_stylebox_override(
		"disabled",
		_create_panel_style(normal_color.darkened(0.45), Color(1, 1, 1, 0.08), 22, 1)
	)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
	button.add_theme_color_override("font_focus_color", text_color)
	button.add_theme_color_override("font_disabled_color", TEXT_SUBTLE)
	button.add_theme_font_size_override("font_size", 18)


static func apply_progress_bar_style(progress_bar: ProgressBar, fill_color: Color) -> void:
	progress_bar.add_theme_stylebox_override(
		"background",
		_create_panel_style(SURFACE_FRAME, SURFACE_FRAME.lightened(0.04), 10, 1)
	)
	progress_bar.add_theme_stylebox_override(
		"fill",
		_create_panel_style(fill_color, fill_color.lightened(0.15), 10, 1)
	)
	progress_bar.add_theme_color_override("font_color", TEXT_PRIMARY)


static func _create_panel_style(
	fill_color: Color,
	border_color: Color,
	corner_radius: int,
	border_width: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = border_color
	style.set_corner_radius_all(corner_radius)
	style.set_border_width_all(border_width)
	style.shadow_color = Color(0, 0, 0, 0.2)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 6)
	return style
