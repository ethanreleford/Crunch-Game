# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Running the Project

Launch from the Godot 4.5 editor by opening `project.godot` and pressing F5. There is no build step — Godot runs GDScript directly. No test suite exists. Testing is done by running two local instances with ENet.

To switch between ENet and Steam backends, select the `multiplayerSceneSteam` node inside `main.tscn` in the Godot editor and change the `net_mode` export property (`ENet` is the default and used for all local testing).

## Architecture Overview

This is a 3D multiplayer tower-defense / third-person action game (Garden Warfare Garden Ops style, Godot 4.5, Forward Plus) with dual-backend networking: **ENet** (LAN/local testing) and **Steam** (via GodotSteam). ENet is used for all active development/testing.

### Scene Flow

```
main.tscn (Start / Host / Join)
  → Start: ClassSelectScreen.tscn → map.tscn  (solo)
  → Host (ENet):  CreateServer.tscn → HostLobby.tscn → MultiplayerClassSelect.tscn → map.tscn
  → Host (Steam): (lobby created in-place)    → HostLobby.tscn → MultiplayerClassSelect.tscn → map.tscn
  → Join (ENet):  ServerBrowser.tscn (UDP discovery) → HostLobby.tscn → MultiplayerClassSelect.tscn → map.tscn
  → Join (Steam): SteamJoin.tscn (lobby ID input)    → HostLobby.tscn → MultiplayerClassSelect.tscn → map.tscn
```

`main_3D_Map.tscn` still exists but is no longer the active game scene — `map.tscn` is. `ClassSelectScreen.tscn` is only reached via the solo "Start" path; multiplayer skips it (class defaults to `"damage_default"`).

### Gameplay Entity Hierarchy

All game actors use composition via `HealthComponent`:

- **`scripts/entity.gd`** (`Entity extends CharacterBody3D`) — base for all moving actors. Holds `speed`/`max_health` exports and a `$HealthComponent` reference. Exposes `take_damage(amount)`. Has a `$DebugLabel` (Label3D) showing current HP and speed; toggled globally by the `debug_stats` input action via a `static var _debug_visible` shared across all Entity instances. The first entity to receive the input calls `set_input_as_handled()` and iterates the `"entities"` group to update all labels at once; new entities read `_debug_visible` in `_ready()`.
- **`scripts/health_component.gd`** (`HealthComponent extends Node`) — tracks `health`/`max_health`, emits `health_changed(new_health)` and `died`, calls `queue_free()` on the parent when health reaches zero. Has a `_dead: bool` guard — once dead, `take_damage` is a no-op, preventing double-die if two damage sources hit the same frame.
- **`scripts/enemy.gd`** (`Enemy extends Entity`) — AI that moves toward the first node in the `"objective"` group. `elite_level` (0/1/2) scales speed and health via `pow(2.5, elite_level)` and overrides mesh color (white/orange/purple). `_physics_process` is gated to `multiplayer.is_server()` — movement only runs on the server; clients receive position via `MultiplayerSynchronizer`. When within 5 units of the objective calls `take_damage(max_health)` to self-destruct through the health pipeline (so the `died` signal fires and the round counter decrements).
- **`scripts/tower.gd`** (`Tower extends StaticBody3D`) — placed defences. Exports `cost`, `damage`, `range`, `attack_speed`. Owns its own `$HealthComponent` and delegates `take_damage` to it.
- **`scripts/statue.gd`** (`Statue extends StaticBody3D`) — a damageable structure with `max_health` and `upgrade_level` exports. Owns `$HealthComponent`. Does **not** join the `"objective"` group — it is distinct from the house enemy target.
- **`scripts/spawn_point.gd`** (`SpawnPoint extends Marker3D`) — marker used as children of `EnemySpawner` nodes. `EnemySpawner.spawn_count()` distributes enemies across all `SpawnPoint` children, adding ±2 unit random offsets per spawn.
- **`scripts/player.gd`** (extends `Entity`) — sets `multiplayer_authority` from node name in `_enter_tree`. Authority peer reads `GameState.selected_class_id` for stats; non-authority peers read `GameState.player_class_ids[peer_id]`. Only authority processes input/physics. Movement direction is derived from `$CameraPivot.global_transform.basis`; mesh yaw tracks `$CameraPivot.rotation.y`.
- **`scripts/camera_controller.gd`** (extends `SpringArm3D`) — sits inside `$CameraPivot` (Node3D under Entity). Handles mouse-look (reads `SettingsManager.mouse_sensitivity`) and scroll-wheel zoom for the authority peer. Excludes player body from SpringArm collision. Captures mouse and calls `camera.make_current()` only for the authority peer. Does **not** handle `ui_cancel` — it simply skips processing when `Input.mouse_mode != MOUSE_MODE_CAPTURED`. Mouse mode is owned by `PauseMenu`.

### Round / Wave System

`GameManager` (attached to `GameManager` node in `map.tscn`) is **server-only**: the timer only starts when `multiplayer.is_server()`. On clients the node exists but does nothing locally.

Signal flow for HUD sync: instead of emitting signals directly, `GameManager` calls `@rpc("authority", "call_local", "reliable")` methods (`_rpc_round_started`, `_rpc_round_ended`, `_rpc_enemy_count_changed`) which re-emit the actual signals on all peers. `GameHUD` connects to these signals in `_ready()` and updates normally on every client.

Wave logic:
- Each round has a total enemy budget (`base_enemies + (round-1) * enemies_per_round`), split randomly into `num_mini_waves` portions.
- Mini-wave N+1 fires when `total_living_enemies <= next_wave_threshold` (threshold-triggered, not time-triggered).
- When all mini-waves are exhausted and living count reaches 0, the round ends and the inter-round timer starts.
- Elite chance = `min(elite_chance_base * current_round, 0.75)`. Among elites: 25% are level-2 (purple/ultra), 75% are level-1 (orange/super).
- `GameManager` adds itself to the `"game_manager"` group. `GameHUD` (`scripts/game_hud.gd`) finds it via `get_first_node_in_group("game_manager")` in `_ready()` and connects directly to its signals — the RPC wrappers re-emit those signals on all peers so `GameHUD` code is identical on server and clients.

### Enemy Replication (Server-Authoritative)

Enemies are replicated via a **custom spawn function** on `EnemyMultiplayerSpawner` (a `MultiplayerSpawner` node in `map.tscn`). Do not use `_spawnable_scenes` for enemies — Godot requires a scene UID for automatic matching, which hand-written `.tscn` files may not have.

Pattern:
1. `game.gd._ready()` sets `$EnemyMultiplayerSpawner.spawn_function = _create_enemy` on all peers.
2. `EnemySpawner._spawn_at()` calls `_mp_spawner.spawn({"position": ..., "elite_level": ...})` on the server only.
3. Godot calls `_create_enemy(data)` on the server (instantiates + returns the enemy), adds it to the map root, then sends a spawn RPC to all clients who call the same function.
4. Enemy position is synced each frame via `MultiplayerSynchronizer` in `enemy.tscn` (`replication_mode = 1`, always).
5. When the server calls `queue_free()` on a dead enemy, the spawner auto-despawns it on all clients.

`EnemySpawner` nodes (`SpawnerNorth/South/East/West`) are children of the map root. Their `_mp_spawner` reference is resolved in `_ready()` via `get_parent().get_node_or_null("EnemyMultiplayerSpawner")`.

### Player Replication

`Scenes/player.tscn`: `Entity (CharacterBody3D)` → `HealthComponent` + `MultiplayerSynchronizer` (replicates `position`, spawn=true) + `CameraPivot (Node3D)` → `SpringArm3D` → `Camera3D` + `HUD`. Server spawns players via `add_child` (name = peer ID string). `MultiplayerSpawner` in `map.tscn` has `_spawnable_scenes = [player.tscn uid]`. Spawn positions sent via RPC after `add_child` — do not set position before `add_child` as the authority client overwrites it.

### Class Selection

`data/classes/` holds six flat `.tres` files (`PlayerClassData` resources): `damage.tres`, `healer.tres`, `tank.tres`, `scout.tres`, `engineer.tres`, `support.tres`. There is no subclass layer — each file is a standalone selectable class. `ClassRegistry` (static class, no autoload) scans the directory lazily and exposes `get_class_data(id)` and `get_all_classes()`.

Each resource has: `class_id`, `display_name`, `description`, `max_health`, `speed`, `base_damage`, and `on_hit_effect` (+ `on_hit_dot_dps`/`on_hit_dot_duration` for the Support class, which applies poison on hit).

`GameState` (static class) stores `selected_class_id` (defaults to `"damage"`, set locally when a player locks in), `player_class_ids: Dictionary` (peer_id → class_id, populated and synced during `MultiplayerClassSelect`), and `player_names: Dictionary` (peer_id → display name, copied from `HostLobby.players` before the scene transition).

**Multiplayer class selection flow** (`scripts/multiplayer_class_select.gd`, `Scenes/MultiplayerClassSelect.tscn`): All peers land here after the host clicks Start in the lobby. Server initialises a `_ready_players` dict (all peer IDs → `""`), broadcasts it via `_sync_ready_players.rpc()`, and keeps it updated as players lock in. When a player clicks "Lock In", the client sets `GameState.selected_class_id` locally and RPCs the choice to the server (`_submit_class`); the server records it, updates `GameState.player_class_ids`, re-broadcasts the dict, then calls `_begin_game.rpc()` once every entry is non-empty. All peers update their local `GameState.player_class_ids` in `_sync_ready_players` so `player.gd` can read correct stats for other players when the game loads. If a peer disconnects during selection they are removed from the dict and readiness is re-checked.

### Key Networking Scripts

- **`scripts/multiplayerSTEAM.gd`** — Attached to `multiplayerSceneSteam.tscn`, instanced inside `main.tscn`. ENet Start button → `ClassSelectScreen.tscn`; ENet Host → `CreateServer.tscn`; ENet Join → `ServerBrowser.tscn`. Steam paths use GodotSteam lobby API.
- **`scripts/GameState.gd`** — Static class. Holds `server_port`, `server_name`, `steam_lobby_id`, `selected_class_id`, `player_class_ids`. Survives scene changes.
- **`scripts/create_server.gd`** — Tries ENet ports 1027–1037 until one succeeds. Each failed attempt requires a fresh `ENetMultiplayerPeer` (failed `create_server()` corrupts the object).
- **`scripts/HostLobby.gd`** — Shows player list via RPC-synced `players: Dictionary`. ENet host binds UDP discovery ports 4567–4577. Start button (host only) triggers `_start_game.rpc()` → all peers change scene to `map.tscn`.
- **`scripts/server_browser.gd`** — ENet only. Pings ports 4567–4577 on localhost and broadcast every second; deduplicates by `id`.
- **`scripts/game.gd`** — Attached to `map.tscn` root (`Node3D`). Server spawns players via `add_child`; sets `spawn_function` on `EnemyMultiplayerSpawner` for all peers. `_create_enemy(data)` instantiates `enemy.tscn`, sets `elite_level` and `position` from data dict. Spawn positions are sequential: `Vector3(index * 5.0, 2.0, 10.0)` — not tied to `SpawnPoint` nodes. Also handles `multiplayer.server_disconnected` by clearing the peer and returning to `main.tscn`.
- **`scripts/settings_manager.gd`** (`SettingsManager`, static class, no autoload) — reads/writes `user://settings.cfg` via `ConfigFile`. Fields: `master_volume`, `fullscreen`, `vsync`, `mouse_sensitivity`. `load_and_apply()` reads the file then calls `apply_all()`; `apply_all()` sets `AudioServer` volume and `DisplayServer` window/vsync modes immediately. Camera look speed reads `SettingsManager.mouse_sensitivity` directly.
- **`scripts/pause_menu.gd`** (attached to `Scenes/PauseMenu.tscn`, `CanvasLayer`) — **owns mouse mode** in-game. Handles `ui_cancel` (Escape) in `_unhandled_input`: open → `show()` + `MOUSE_MODE_VISIBLE`; close → `hide()` + `MOUSE_MODE_CAPTURED`. Contains sliders/toggles that delegate directly to `SettingsManager`. "Quit to Menu" resets mouse mode and calls `change_scene_to_file("res://Scenes/main.tscn")`.
- **`scripts/multiplayerENET.gd`** — empty file. ENet (and Steam) menu logic both live in `scripts/multiplayerSTEAM.gd` despite the name.

### Multi-Server on Same Machine

ENet ports (1027–1037) and UDP discovery ports (4567–4577) are tried in sequence. The first `create_server()` attempt on port 1027 prints a harmless C++ ENet error when that port is already in use.

### UDP Discovery Protocol

- **Host** (`HostLobby.gd`): binds first available port in 4567–4577, responds to every packet with `{"name": GameState.server_name, "port": GameState.server_port, "id": server_id}`.
- **Client** (`server_browser.gd`): binds port 0 (random), pings all ports 4567–4577 on both localhost and broadcast every second, deduplicates by `id`.

### Steam Integration

Steam is initialized in `scripts/multiplayerSTEAM.gd._ready()` with app ID `480` (Spacewar test app). `HostLobby.gd` detects peer type via `multiplayer.multiplayer_peer is SteamMultiplayerPeer` to show Steam persona names.

### Objective System

The house in `map.tscn` runs `scripts/house.gd` which calls `add_to_group("objective")` in `_ready()`. Do not rely on `groups = [...]` in hand-written `.tscn` files — Godot's text scene loader does not reliably register it. Always use `add_to_group()` in a script instead. Enemies find the objective via `get_tree().get_nodes_in_group("objective")[0]`.

### Input Actions

Defined in `project.godot`: `left`=A, `right`=D, `up`=W, `down`=S, `ui_accept`=Space (jump), `ui_cancel`=Escape (opens/closes `PauseMenu`, which controls mouse capture), `debug_stats`=toggles the HP/speed Label3D on all Entity instances.

### Terrain3D Addon

`addons/terrain_3d/` is a third-party terrain editing plugin. The `demo/` folder is also from the addon. Neither is core game logic — avoid modifying them.
