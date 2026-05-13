extends CharacterBody2D

var facing: int = 1
var jump_buffer: float = 0.0
var coyote_time: float = 0.0
var jump_locked: bool = false
var cat_jumps: int = 0
var glow: float = 0.0
var bear_shield_timer: float = 0.0

func _ready() -> void:
	position = Config.LEVEL_STARTS[GameState.current_level]

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		jump_buffer = Config.JUMP_BUF
		jump_locked = false
	if event.is_action_released("jump"):
		jump_locked = false

func _physics_process(delta: float) -> void:
	match GameState.mode:
		"walk":   _update_platformer(delta, Config.JUMP_WALK)
		"jump":   _update_platformer(delta, Config.JUMP_FLOW)
		"flight": _update_flight(delta)
	move_and_slide()
	_check_fall()

func _update_platformer(delta: float, jump_strength: float) -> void:
	var sf := Config.SLOW_FACTOR if Input.is_action_pressed("slow") else 1.0
	var on_floor := is_on_floor()

	if on_floor:
		coyote_time = Config.COYOTE
		cat_jumps = 1 if GameState.buff_cat else 0
	else:
		coyote_time = maxf(0.0, coyote_time - delta)

	jump_buffer = maxf(0.0, jump_buffer - delta)

	var accel := Config.MOVE if on_floor else Config.AIR_MOVE
	if Input.is_action_pressed("move_left"):
		velocity.x -= accel * delta * sf
		facing = -1
	if Input.is_action_pressed("move_right"):
		velocity.x += accel * delta * sf
		facing = 1

	velocity.x *= pow(Config.FRICTION, delta * 60.0)
	velocity.x = clampf(velocity.x, -Config.MAX_RUN * sf, Config.MAX_RUN * sf)

	if jump_buffer > 0.0 and not jump_locked:
		if coyote_time > 0.0:
			_perform_jump(jump_strength)
		elif cat_jumps > 0:
			cat_jumps -= 1
			_perform_jump(jump_strength * 0.88)

	# Shorter jump arc on early release
	if velocity.y < 0.0 and not Input.is_action_pressed("jump"):
		velocity.y += Config.GRAVITY * 0.55 * delta

	velocity.y += Config.GRAVITY * delta
	position.y = maxf(position.y, -120.0)
	position.x = clampf(position.x, 0.0, Config.WORLD_W - 32.0)

func _perform_jump(strength: float) -> void:
	velocity.y = -strength
	jump_buffer = 0.0
	jump_locked = true
	coyote_time = 0.0

func _update_flight(delta: float) -> void:
	var slow := Input.is_action_pressed("slow")

	velocity.x = Config.FLIGHT_BASE_VX
	if Input.is_action_pressed("move_left"):
		velocity.x -= Config.FLIGHT_SIDE
	if Input.is_action_pressed("move_right"):
		velocity.x += Config.FLIGHT_SIDE

	if slow:
		velocity.x *= 0.78
		velocity.y *= 0.98
		glow = lerpf(glow, 1.0, 0.1 * delta * 60.0)
	else:
		glow = lerpf(glow, 0.0, 0.08 * delta * 60.0)

	if jump_buffer > 0.0:
		velocity.y = Config.FLIGHT_FLAP
		jump_buffer = 0.0

	velocity.y += Config.FLIGHT_GRAVITY * delta
	velocity.y = clampf(velocity.y, Config.FLIGHT_MAX_UP, Config.FLIGHT_MAX_DOWN)
	position.x = clampf(position.x, 0.0, Config.WORLD_W - 32.0)

	if position.y < Config.FLIGHT_TOP:
		position.y = Config.FLIGHT_TOP
		velocity.y = maxf(velocity.y, 80.0)

func _check_fall() -> void:
	if position.y > Config.WORLD_H + 180.0:
		GameState.damage_center(Config.CENTER_FALL_LOSS)
		respawn()

func respawn() -> void:
	position = GameState.checkpoint
	velocity = Vector2.ZERO

func activate_bear_shield() -> void:
	bear_shield_timer = 2.5

func _process(delta: float) -> void:
	if bear_shield_timer > 0.0:
		bear_shield_timer = maxf(0.0, bear_shield_timer - delta)
