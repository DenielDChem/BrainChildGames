extends Node

signal level_changed(lvl: int)
signal orbs_changed(count: int, need: int)
signal key_collected
signal center_changed(value: float)
signal record_found(title: String, text: String)
signal animal_met(kind: String, name: String, desc: String)

var current_level: int = 0
var mode: String = "walk"

var orbs_collected: int = 0
var has_key: bool = false
var center: float = 100.0
var swarm_damage: float = 0.0

# Buffs from animals
var buff_bear: bool = false    # reduced center damage
var buff_fox: bool = false     # reveals secret platforms
var buff_raven: bool = false   # reveal beams on orbs/records
var buff_cat: bool = false     # double jump in jump mode
var buff_wolf: bool = false    # swarm zones become readable

var checkpoint: Vector2 = Vector2.ZERO
var records_found: Array[Dictionary] = []

func start_level(lvl: int) -> void:
	current_level = lvl
	mode = Config.LEVEL_MODES[lvl]
	orbs_collected = 0
	has_key = false
	center = Config.CENTER_MAX
	swarm_damage = 0.0
	buff_bear = false
	buff_fox = false
	buff_raven = false
	buff_cat = false
	buff_wolf = false
	checkpoint = Config.LEVEL_STARTS[lvl]
	records_found = []
	level_changed.emit(lvl)

func collect_orb() -> void:
	orbs_collected += 1
	orbs_changed.emit(orbs_collected, Config.LEVEL_NEEDS[current_level])

func collect_key() -> void:
	has_key = true
	key_collected.emit()

func portal_unlocked() -> bool:
	return orbs_collected >= Config.LEVEL_NEEDS[current_level] and has_key

func damage_center(amount: float) -> void:
	var dmg := amount * (0.6 if GameState.buff_bear else 1.0)
	center = clampf(center - dmg, 0.0, Config.CENTER_MAX)
	center_changed.emit(center)

func heal_center(amount: float) -> void:
	center = clampf(center + amount, 0.0, Config.CENTER_MAX)
	center_changed.emit(center)

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
