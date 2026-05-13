class_name GameHUD
extends CanvasLayer

signal stealth_pressed
signal hack_pressed
signal sonar_pressed
signal pause_pressed
signal restart_pressed

var _alert_bar: ProgressBar
var _energy_bar: ProgressBar
var _compute_bar: ProgressBar
var _timer_label: Label
var _terminals_label: Label
var _detect_bar: ProgressBar
var _msg_label: Label
var _overlay: ColorRect
var _overlay_label: Label
var _stealth_btn: Button
var _hack_btn: Button
var _sonar_btn: Button
var _pause_btn: Button

const BTN_MIN_SIZE := Vector2(130, 64)
const BAR_HEIGHT   := 12

func _ready() -> void:
	_build_top_bar()
	_build_bottom_bar()
	_build_overlay()

func _build_top_bar() -> void:
	var panel := Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.custom_minimum_size = Vector2(0, 40)
	_style_panel(panel, Color("06090f"), Color(0, 0.878, 1, 0.4))
	add_child(panel)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 16)
	panel.add_child(hbox)

	hbox.add_child(_make_label("ALERT", Config.C_HUD_TEXT, 11))
	_alert_bar = _make_bar(120, Config.C_HUD_GOOD)
	hbox.add_child(_alert_bar)
	hbox.add_child(_make_spacer())

	_timer_label = _make_label("4:00", Config.C_HUD_TITLE, 14)
	hbox.add_child(_timer_label)
	hbox.add_child(_make_spacer())

	_terminals_label = _make_label("Terminals: 0/3", Config.C_HUD_TEXT, 11)
	hbox.add_child(_terminals_label)
	hbox.add_child(_make_label("DETECT", Config.C_HUD_TEXT, 11))
	_detect_bar = _make_bar(100, Config.C_HUD_GOOD)
	hbox.add_child(_detect_bar)

	_msg_label = Label.new()
	_msg_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg_label.add_theme_color_override("font_color", Config.C_ENEMY_ALERT)
	_msg_label.add_theme_font_size_override("font_size", 13)
	_msg_label.visible = false
	panel.add_child(_msg_label)

func _build_bottom_bar() -> void:
	var panel := Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.custom_minimum_size = Vector2(0, 80)
	_style_panel(panel, Color("06090f"), Color(0, 0.878, 1, 0.4))
	add_child(panel)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	hbox.add_child(vbox)
	var e_row := _make_bar_row("ENERGY",  150)
	_energy_bar  = e_row[1]; vbox.add_child(e_row[0])
	var c_row := _make_bar_row("COMPUTE", 150)
	_compute_bar = c_row[1]; vbox.add_child(c_row[0])

	hbox.add_child(_make_spacer())

	_stealth_btn = _make_button("STEALTH", Color("0077aa"))
	_hack_btn    = _make_button("HACK",    Color("006633"))
	_sonar_btn   = _make_button("SONAR",   Color("441188"))
	_pause_btn   = _make_button("PAUSE",   Color("333333"))

	hbox.add_child(_stealth_btn)
	hbox.add_child(_hack_btn)
	hbox.add_child(_sonar_btn)
	hbox.add_child(_pause_btn)

	_stealth_btn.pressed.connect(func(): emit_signal("stealth_pressed"))
	_hack_btn.pressed.connect(func(): emit_signal("hack_pressed"))
	_sonar_btn.pressed.connect(func(): emit_signal("sonar_pressed"))
	_pause_btn.pressed.connect(func(): emit_signal("pause_pressed"))

func _build_overlay() -> void:
	_overlay = ColorRect.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.color   = Color(0, 0, 0, 0.82)
	_overlay.visible = false
	add_child(_overlay)

	_overlay_label = Label.new()
	_overlay_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_overlay_label.add_theme_font_size_override("font_size", 28)
	_overlay_label.add_theme_color_override("font_color", Config.C_HUD_TITLE)
	_overlay.add_child(_overlay_label)

	var restart := _make_button("RESTART", Color("222244"))
	restart.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	restart.position.y    = -80.0
	restart.custom_minimum_size = Vector2(200, 60)
	restart.pressed.connect(func(): emit_signal("restart_pressed"))
	_overlay.add_child(restart)

# ── State update (called each frame from game.gd) ──────────────
func update_bars(alert: float, energy: float, compute: float, detected: float) -> void:
	_alert_bar.value   = alert
	_energy_bar.value  = energy
	_compute_bar.value = compute
	_detect_bar.value  = detected

	var ac := Config.C_HUD_BAD if alert > 70.0 else (Config.C_HUD_WARN if alert > 40.0 else Config.C_HUD_GOOD)
	_set_bar_color(_alert_bar, ac)
	var dc := Config.C_HUD_BAD if detected > 70.0 else (Config.C_HUD_WARN if detected > 40.0 else Config.C_HUD_GOOD)
	_set_bar_color(_detect_bar, dc)
	_set_bar_color(_energy_bar,  Config.C_HUD_WARN if energy < 25.0 else Config.C_HUD_GOOD)
	_set_bar_color(_compute_bar, Config.C_HUD_WARN if compute < 25.0 else Config.C_HUD_GOOD)

func update_timer(seconds: float) -> void:
	var m := int(seconds) / 60
	var s := int(seconds) % 60
	_timer_label.text = "%d:%02d" % [m, s]
	_timer_label.add_theme_color_override("font_color", Config.C_HUD_BAD if seconds < 30.0 else Config.C_HUD_TITLE)

func update_terminals(hacked: int, total: int) -> void:
	_terminals_label.text = "Terminals: %d/%d" % [hacked, total]

func show_message(text: String, duration: float) -> void:
	_msg_label.text    = text
	_msg_label.visible = true
	await get_tree().create_timer(duration).timeout
	_msg_label.visible = false

func show_overlay(text: String) -> void:
	_overlay_label.text = text
	_overlay.visible    = true

func hide_overlay() -> void:
	_overlay.visible = false

func set_stealth_active(on: bool) -> void:
	_stealth_btn.modulate = Color(0, 1, 1, 1) if on else Color.WHITE

func set_paused(on: bool) -> void:
	_pause_btn.text = "RESUME" if on else "PAUSE"

# ── Helpers ────────────────────────────────────────────────────
func _make_label(text: String, color: Color, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", size)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l

func _make_bar(width: int, color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(width, BAR_HEIGHT)
	b.max_value      = 100.0
	b.value          = 100.0
	b.show_percentage = false
	_set_bar_color(b, color)
	return b

func _make_bar_row(label_text: String, width: int) -> Array:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.add_child(_make_label(label_text, Config.C_HUD_TEXT, 10))
	var bar := _make_bar(width, Config.C_HUD_GOOD)
	hb.add_child(bar)
	return [hb, bar]

func _make_button(text: String, bg: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = BTN_MIN_SIZE
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", Config.C_HUD_TITLE)

	var ns := StyleBoxFlat.new()
	ns.bg_color            = bg
	ns.border_width_left   = 1
	ns.border_width_right  = 1
	ns.border_width_top    = 1
	ns.border_width_bottom = 1
	ns.border_color        = Config.C_HUD_TITLE
	ns.set_corner_radius_all(4)
	b.add_theme_stylebox_override("normal", ns)

	var hs := ns.duplicate() as StyleBoxFlat
	hs.bg_color = bg.lightened(0.2)
	b.add_theme_stylebox_override("hover",   hs)
	b.add_theme_stylebox_override("pressed", hs)

	return b

func _make_spacer() -> Control:
	var s := Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return s

func _style_panel(panel: Panel, bg: Color, border: Color) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color            = bg
	s.border_color        = border
	s.border_width_bottom = 1
	panel.add_theme_stylebox_override("panel", s)

func _set_bar_color(bar: ProgressBar, color: Color) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	bar.add_theme_stylebox_override("fill", s)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(color.r * 0.15, color.g * 0.15, color.b * 0.15)
	bar.add_theme_stylebox_override("background", bg)
