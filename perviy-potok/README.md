# Первый Поток

Narrative platformer, 3 levels with escalating mechanics.

## Levels

| # | Name | Mode | Mechanic |
|---|------|------|----------|
| 1 | Земля / Предел | walk | Basic platformer, 5 orbs |
| 2 | Первый Поток | jump | Enhanced jump, Cat = double-jump |
| 3 | Чёрный Рой | flight | Flappy gravity, Swarm hazards |

## Animals (buffs)

- **Медведь** — Bear Shield: reduced Center damage
- **Лиса** — Fox: reveals secret platforms
- **Ворон** — Raven: reveal beams on orbs/records
- **Кот** — Cat: double jump (level 2 only)
- **Волк** — Wolf: Swarm zones become readable

## Files

```
html5/
  index.html          — original HTML5 single-file version
godot/
  project.godot
  scripts/
    config.gd         — physics constants, palette, level data
    game_state.gd     — signals, buffs, center, orb/key state
    main.gd           — scene root: camera, collision checks, level transitions
    player.gd         — CharacterBody2D: walk/jump/flight physics
    level_manager.gd  — level data builders + collision queries
    renderer.gd       — draw_* canvas renderer (no scene nodes per object)
    hud.gd            — ProgressBars, message label, intro/end panels
  scenes/
    Main.tscn         — root scene wiring all nodes
```

## Physics (ported exact from HTML)

```
GRAVITY = 1450  MOVE = 1420  AIR_MOVE = 1180  MAX_RUN = 620
FRICTION = 0.89^(delta*60)  JUMP_WALK = 770  JUMP_FLOW = 835
COYOTE = 0.14s  JUMP_BUF = 0.16s
Flight: base_vx=225, gravity=500, vy clamp(-360,320)
```

## Mobile controls

Touch buttons (LeftBtn / RightBtn / JumpBtn) inject InputEventAction events — same code path as keyboard.
