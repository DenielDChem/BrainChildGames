extends CanvasLayer

@onready var orbs_bar: ProgressBar = $Bars/OrbsBar
@onready var key_bar: ProgressBar = $Bars/KeyBar
@onready var hearts_label: Label = $Bars/HeartsLabel
@onready var shields_label: Label = $Bars/ShieldsLabel
@onready var msg_label: Label = $MsgLabel
@onready var level_kicker: Label = $Brand/Kicker
@onready var level_title: Label = $Brand/Title
@onready var intro_panel: Panel = $IntroPanel
@onready var end_panel: Panel = $EndPanel

var _msg_timer: float = 0.0

func _ready() -> void:
	GameState.orbs_changed.connect(_on_orbs_changed)
	GameState.key_collected.connect(_on_key_collected)
	GameState.hearts_changed.connect(_on_hearts_changed)
	GameState.shield_changed.connect(_on_shield_changed)
	GameState.level_changed.connect(_on_level_changed)
	_on_level_changed(0)
	_on_hearts_changed(Config.MAX_HEARTS)
	_on_shield_changed(0)
	intro_panel.hide()
	end_panel.hide()

func _process(delta: float) -> void:
	if _msg_timer > 0.0:
		_msg_timer -= delta
		if _msg_timer <= 0.0:
			msg_label.hide()

func show_message(text: String, duration: float) -> void:
	msg_label.text = text
	msg_label.show()
	_msg_timer = duration

func show_level_intro(lvl: int) -> void:
	intro_panel.get_node("Kicker").text = Config.LEVEL_KICKERS[lvl]
	intro_panel.get_node("Title").text = Config.LEVEL_TITLES[lvl]
	intro_panel.get_node("Intro").text = Config.LEVEL_INTROS[lvl]
	intro_panel.show()
	await get_tree().create_timer(3.5).timeout
	intro_panel.hide()

func show_game_end() -> void:
	end_panel.show()

func _on_orbs_changed(count: int, need: int) -> void:
	orbs_bar.max_value = need
	orbs_bar.value = count

func _on_key_collected() -> void:
	key_bar.value = 1.0

func _on_hearts_changed(h: int) -> void:
	var t: String = ""
	for i in h:
		t += "♥ "
	hearts_label.text = t.strip_edges()

func _on_shield_changed(s: int) -> void:
	var t: String = ""
	for i in s:
		t += "□ "
	shields_label.text = t.strip_edges()

func _on_level_changed(lvl: int) -> void:
	level_kicker.text = Config.LEVEL_KICKERS[lvl]
	level_title.text = Config.LEVEL_TITLES[lvl]
	orbs_bar.max_value = Config.LEVEL_NEEDS[lvl]
	orbs_bar.value = 0
	key_bar.value = 0
