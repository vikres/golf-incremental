# golf-incremental

Incremental mini-golf game built in Godot 4.4 with GDScript, July to September 2025.

- Upgrade system with costs, levels, caps and prerequisites that recompute object stats (`scripts/UpgradeManager.gd`)
- Money economy, save and load, and collectibles spawned on free tilemap tiles (`scripts/GameManager.gd`)
- Ball movement and visuals: rolling rotation, shadow, divots and surface types (`ball.gd`, `BallVisual.gd`, `DivotRenderer.gd`, `SurfaceManager.gd`)
- Five levels and two tutorials, a shop, and a completion board

`addons/scene_manager` is a third-party Godot plugin. Fonts and the grassland tiles are third-party assets.
