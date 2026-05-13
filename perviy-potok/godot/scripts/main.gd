extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var level_mgr: Node2D = $LevelManager
@onready var camera: Camera2D = $Camera
@onready var renderer: Node2D = $Renderer
@onready var hud: CanvasLayer = $HUD
@onready var touch_controls: CanvasLayer = $TouchControls

var _phase: String = "playing"

func _ready() -> void:
	# Wire renderer data refs
	renderer.level_mgr = level_mgr
	renderer.player = player

	GameState.start_level(0)
	level_mgr._build_level(0)
	player.position = Config.LEVEL_STARTS[0]
	level_mgr.portal_entered.connect(_on_portal_entered)
	GameState.center_changed.connect(_on_center_changed)
	GameState.record_found.connect(_on_record_found)
	GameState.animal_met.connect(_on_animal_met)

	# Touch button → InputEventAction injection
	var left_btn: Button = touch_controls.get_node("LeftBtn")
	var right_btn: Button = touch_controls.get_node("RightBtn")
	var jump_btn: Button = touch_controls.get_node("JumpBtn")
	left_btn.button_down.connect(func(): _inject_action("move_left", true))
	left_btn.button_up.connect(func(): _inject_action("move_left", false))
	right_btn.button_down.connect(func(): _inject_action("move_right", true))
	right_btn.button_up.connect(func(): _inject_action("move_right", false))
	jump_btn.button_down.connect(func(): _inject_action("jump", true))
	jump_btn.button_up.connect(func(): _inject_action("jump", false))

func _inject_action(action: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)

func _physics_process(delta: float) -> void:
	if _phase != "playing":
		return
	var ps := player.position
	var psize := Vector2(32.0, 48.0)
	level_mgr.check_orb_collect(ps, psize)
	level_mgr.check_record_collect(ps, psize)
	level_mgr.check_animal_meet(ps, psize)
	level_mgr.check_portal(ps, psize)
	if GameState.mode == "flight":
		level_mgr.check_swarm_damage(ps, delta)
	_update_camera()

func _update_camera() -> void:
	var tx := clampf(player.position.x, 640.0, Config.WORLD_W - 640.0)
	var ty := clampf(player.position.y - 120.0, 0.0, Config.WORLD_H - 720.0) + 360.0
	camera.position = Vector2(tx, ty)

func _on_portal_entered(to_level: int) -> void:
	if to_level >= 3:
		_phase = "game_end"
		hud.show_game_end()
		return
	GameState.start_level(to_level)
	level_mgr._build_level(to_level)
	player.position = Config.LEVEL_STARTS[to_level]
	player.velocity = Vector2.ZERO
	hud.show_level_intro(to_level)

func _on_center_changed(value: float) -> void:
	if value <= 0.0:
		player.respawn()
		GameState.heal_center(20.0)

func _on_record_found(title: String, text: String) -> void:
	hud.show_message("%s. %s" % [title, text], 4.2)

func _on_animal_met(_kind: String, anim_name: String, desc: String) -> void:
	hud.show_message("%s. %s" % [anim_name, desc], 5.0)
