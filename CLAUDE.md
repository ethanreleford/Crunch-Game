# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Running the Project

Launch from the Godot 4.5 editor by opening `project.godot` and pressing F5. There is no build step — Godot runs GDScript directly. No test suite exists. Testing is done by running two local instances with ENet.

To switch between ENet and Steam backends, select the `multiplayerSceneSteam` node inside `main.tscn` in the Godot editor and change the `net_mode` export property (`ENet` is the default and used for all local testing).

## Architecture Overview

This is a 3D multiplayer game (Godot 4.5, Forward Plus) with dual-backend networking: **ENet** (LAN/local testing) and **Steam** (via GodotSteam). ENet is used for all active development/testing. Steam requires separate accounts per instance so is not used for local testing.

### Scene Flow

```
main.tscn (Start / Host / Join)
  → Start: TestingEnemies.tscn (solo/sandbox)
  → Host (ENet):  CreateServer.tscn → HostLobby.tscn → main_3D_Map.tscn
  → Host (Steam): (lobby created in-place) → HostLobby.tscn → main_3D_Map.tscn
  → Join (ENet):  ServerBrowser.tscn (UDP discovery) → HostLobby.tscn → main_3D_Map.tscn
  → Join (Steam): SteamJoin.tscn (lobby ID input)   → HostLobby.tscn → main_3D_Map.tscn
```

### Gameplay Entity Hierarchy

All game actors use composition via `HealthComponent`:

- **`scripts/entity.gd`** (`Entity extends CharacterBody3D`) — base for all moving actors. Holds `speed`/`max_health` exports and a `$HealthComponent` reference. Exposes `take_damage(amount)`. Has a `$DebugLabel` (Label3D) that shows current HP and speed; toggled by the `debug_stats` input action.
- **`scripts/health_component.gd`** (`HealthComponent extends Node`) — tracks `health`/`max_health`, emits `health_changed(new_health)` and `died`, calls `queue_free()` on the parent when health reaches zero.
- **`scripts/enemy.gd`** (`Enemy extends Entity`) — sets `speed=4.0`, `max_health=60.0`; applies gravity and calls `move_and_slide` each physics frame. AI targeting not yet implemented.
- **`scripts/tower.gd`** (`Tower extends StaticBody3D`) — placed defences. Exports `cost`, `damage`, `range`, `attack_speed`. Owns its own `$HealthComponent` and delegates `take_damage` to it (same pattern as Entity, but StaticBody3D not CharacterBody3D).
- **`scripts/player.gd`** (extends `Entity`) — sets `multiplayer_authority` from node name in `_enter_tree`. Connects `health_component.health_changed` to update the on-screen `$HUD/Control/HealthBar` (authority only). Only authority processes input/physics. Movement direction is derived from `$CameraPivot.global_transform.basis`; mesh yaw tracks `$CameraPivot.rotation.y`.
- **`scripts/camera_controller.gd`** (extends `SpringArm3D`) — sits inside `$CameraPivot` (Node3D under Entity). Handles mouse-look and scroll-wheel zoom for the authority player. Excludes player body from SpringArm collision. Captures mouse and calls `camera.make_current()` only for the authority peer. `ui_cancel` (Escape) toggles mouse capture.

### Key Networking Scripts

- **`scripts/multiplayerSTEAM.gd`** — Attached to `multiplayerSceneSteam.tscn`, instanced inside `main.tscn`. Handles ENet and Steam via `net_mode` export. For ENet, Host navigates to `CreateServer.tscn`; Join navigates to `ServerBrowser.tscn`. For Steam, Host triggers `Steam.createLobby`; Join navigates to `SteamJoin.tscn`.
- **`scripts/GameState.gd`** — Static class (no autoload needed). Holds `server_port`, `server_name`, and `steam_lobby_id` so values survive scene changes. Written by `create_server.gd` (ENet) or `multiplayerSTEAM.gd` (Steam), read by `HostLobby.gd`.
- **`scripts/create_server.gd`** — Tries ENet ports 1027–1037 until one succeeds, stores result in `GameState`, then navigates to `HostLobby.tscn`. Each port attempt requires a fresh `ENetMultiplayerPeer` — a failed `create_server()` corrupts the object.
- **`scripts/HostLobby.gd`** — Lobby controller for both backends. Shows player list via RPC-synced `players: Dictionary`. ENet host binds UDP discovery ports 4567–4577 and responds to pings. Steam host shows `GameState.steam_lobby_id` as lobby code. Start button only visible to host; triggers `_start_game.rpc()` → all peers change scene to `main_3D_Map.tscn`.
- **`scripts/server_browser.gd`** — ENet only. Binds a random UDP port, sends "discover" pings to `127.0.0.1` and `255.255.255.255` across ports 4567–4577 every second. Deduplicates responses by `id`. On join failure, resets the peer and restarts discovery.
- **`scripts/steam_join.gd`** — Steam only. Accepts a lobby ID in a `LineEdit`, calls `Steam.joinLobby`, creates a `SteamMultiplayerPeer` client on `lobby_joined`, then navigates to `HostLobby.tscn` on connection success.
- **`scripts/game.gd`** — Attached to `main_3D_Map.tscn` root. Server spawns a player for each peer via `add_child` (name = peer ID string), then sends `_set_spawn_position` RPC to each client. Spawn positions are `Vector3(index * 5.0, 3.0, 0.0)`. Client is authority for their own player — setting position server-side gets overwritten.

### Multi-Server on Same Machine

ENet ports (1027–1037) and UDP discovery ports (4567–4577) are tried in sequence until one binds successfully. The first `create_server()` attempt on port 1027 prints a C++ ENet error when that port is already in use — expected and harmless.

### Player Replication

`Scenes/player.tscn`: `Entity (CharacterBody3D)` → `HealthComponent` + `MultiplayerSynchronizer` (replicates `position`, spawn=true) + `CameraPivot (Node3D)` → `SpringArm3D (camera_controller.gd)` → `Camera3D` + `HUD`. Players are spawned by the server via `add_child`. `MultiplayerSpawner` in `main_3D_Map.tscn` has `_spawnable_scenes = [player.tscn]`. Spawn positions are sent via RPC to each client after spawning — do not set position before `add_child` as the authority client will overwrite it.

### UDP Discovery Protocol

- **Host** (`HostLobby.gd`): binds first available port in 4567–4577, responds to every packet with `{"name": GameState.server_name, "port": GameState.server_port, "id": server_id}`.
- **Client** (`server_browser.gd`): binds port 0 (random), pings all ports 4567–4577 on both localhost and broadcast every second, deduplicates by `id`.

### Steam Integration

Steam is initialized in `scripts/multiplayerSTEAM.gd._ready()` with app ID `480` (Spacewar test app). Steam lobby creation/joining goes through Steam signals (`lobby_created`, `lobby_joined`). `HostLobby.gd` detects peer type via `multiplayer.multiplayer_peer is SteamMultiplayerPeer` to show Steam persona names instead of peer ID labels.

### Input Actions

Defined in `project.godot`: `left`=A, `right`=D, `up`=W, `down`=S, `ui_accept`=Space (jump), `ui_cancel`=Escape (toggle mouse capture), `debug_stats`=toggles the HP/speed Label3D on Entity.

### Terrain3D Addon

`addons/terrain_3d/` is a third-party terrain editing plugin. The `demo/` folder is also from the addon. Neither is core game logic — avoid modifying them.
