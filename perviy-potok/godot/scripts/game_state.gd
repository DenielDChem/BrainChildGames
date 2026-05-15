extends Node

signal level_changed(lvl: int)
signal orbs_changed(count: int, need: int)
signal key_collected
signal hearts_changed(h: int)
signal shield_changed(s: int)
signal record_found(title: String, text: String)
signal animal_met(kind: String, anim_name: String, desc: String)
signal player_died

var current_level: int = 0
var mode: String = "walk"

var orbs_collected: int = 0
var has_key: bool = false
var hearts: int = Config.MAX_HEARTS
var shields: int = 0

var buff_bear: bool = false
var buff_fox: bool = false
var buff_raven: bool = false
var buff_cat: bool = false
var buff_wolf: bool = false

var checkpoint: Vector2 = Vector2.ZERO
var records_found: Array[Dictionary] = []

func start_level(lvl: int) -> void:
	current_level = lvl
	mode = Config.LEVEL_MODES[lvl]
	orbs_collected = 0
	has_key = false
	hearts = Config.MAX_HEARTS
	shields = 0
	buff_bear = false
	buff_fox = false
	buff_raven = false
	buff_cat = false
	buff_wolf = false
	checkpoint = Config.LEVEL_STARTS[lvl]
	records_found = []
	level_changed.emit(lvl)
	hearts_changed.emit(hearts)
	shield_changed.emit(shields)

func collect_orb() -> void:
	orbs_collected += 1
	orbs_changed.emit(orbs_collected, Config.LEVEL_NEEDS[current_level])

func collect_key() -> void:
	has_key = true
	key_collected.emit()

func portal_unlocked() -> bool:
	return orbs_collected >= Config.LEVEL_NEEDS[current_level] and has_key

func take_damage() -> void:
	if shields > 0:
		shields -= 1
		shield_changed.emit(shields)
	else:
		hearts -= 1
		hearts_changed.emit(hearts)
		if hearts <= 0:
			hearts = Config.MAX_HEARTS
			hearts_changed.emit(hearts)
			player_died.emit()

func gain_shield(amount: int) -> void:
	shields = mini(shields + amount, Config.MAX_SHIELDS)
	shield_changed.emit(shields)

func find_record(title: String, text: String) -> void:
	records_found.append({"title": title, "text": text})
	record_found.emit(title, text)

func meet_animal(kind: String, anim_name: String, desc: String) -> void:
	match kind:
		"bear":  buff_bear = true
		"fox":   buff_fox = true
		"raven": buff_raven = true
		"cat":   buff_cat = true
		"wolf":  buff_wolf = true
	animal_met.emit(kind, anim_name, desc)
