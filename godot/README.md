# Neural Link — Godot 4 Port

Stealth drone game ported to Godot 4 + Android APK. GDScript only.

## Setup

1. Install **Godot 4.3+** (standard, not Mono/C#)
2. Open Godot → **Import** → select this folder
3. Let it import, then hit **Play**

## Android Export

1. Godot: **Editor → Export → Add → Android**
2. Package name: `com.yourname.neurallink`
3. Install Android SDK + export templates (Godot prompts automatically)
4. Generate a debug keystore or use your own
5. **Export Project** → `.apk`

## File Structure

```
scripts/
  config.gd       constants + palette (autoloaded as Config)
  bsp_gen.gd      BSP dungeon generation
  astar_grid.gd   A* pathfinding (wraps Godot AStar2D)
  drone.gd        drone data + movement
  enemy.gd        enemy patrol / alert / chase AI
  game_hud.gd     mobile HUD (CanvasLayer, built in code)
  game.gd         main scene: orchestrates all + rendering
scenes/
  Main.tscn       root scene
```

## Mobile Controls

| Control | Action |
|---------|--------|
| Tap map tile | Move drone |
| Tap terminal (adjacent) | Hack terminal |
| STEALTH | Toggle stealth (drains energy) |
| HACK | Hack nearest reachable terminal |
| SONAR | Reveal full map 3s (costs 20 compute) |
| PAUSE | Slow time (drains compute) |

## Layout

Viewport 1280x720 landscape — map 960x640 centered, 160px side margins, 40px top/bottom for HUD.
