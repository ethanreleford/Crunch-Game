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
  → Start: main_3D_Map.tscn (solo/direct)
  → Host: CreateServer.tscn (name input + create) → HostLobby.tscn
  → Join: ServerBrowser.tscn (UDP discovery list) → HostLobby.tscn
      → Start (host only): main_3D_Map.tscn
```

### Key Scripts

- **`scripts/multiplayerSTEAM.gd`** — Attached to `multiplayerSceneSteam.tscn`, instanced inside `main.tscn`. Handles ENet and Steam via `net_mode` export. For ENet, Host button navigates to `CreateServer.tscn`. For Steam, triggers `Steam.createLobby`. Join button goes to `ServerBrowser.tscn`.
- **`scripts/GameState.gd`** — Static class (no autoload needed). Holds `server_port: int` and `server_name: String` so values survive scene changes. Written by `create_server.gd`, read by `HostLobby.gd`.
- **`scripts/create_server.gd`** — Shown before hosting. Reads server name from `LineEdit`, tries ENet ports 1027–1037 until one succeeds (`create_server()` returns `OK`), stores result in `GameState`, then navigates to `HostLobby.tscn`. Each port attempt requires a fresh `ENetMultiplayerPeer` — a failed `create_server()` corrupts the object.
- **`scripts/HostLobby.gd`** — Lobby controller. Shows player list via RPC-synced dictionary (`players: Dictionary`). Host tries UDP discovery ports 4567–4577 until `bind()` succeeds, responds to pings with `GameState.server_name` and `GameState.server_port`. Start button only visible to host. Leave closes the peer; all clients return to main menu via `server_disconnected`.
- **`scripts/server_browser.gd`** — Binds a random UDP port, sends "discover" pings to `127.0.0.1` and `255.255.255.255` across ports 4567–4577 every second (to reach multiple servers on the same machine). Deduplicates responses by `id` field. On join failure (`connection_failed`), resets the peer and restarts discovery.
- **`scripts/game.gd`** — Attached to `main_3D_Map.tscn` root. Server spawns a player for each peer via `add_child` (name = peer ID string), then sends `_set_spawn_position` RPC to each client. Spawn positions are `Vector3(index * 5.0, 3.0, 0.0)`. Client is authority for their own player — setting position server-side gets overwritten.
- **`scripts/player.gd`** — `CharacterBody3D`. Sets `multiplayer_authority` from node name (peer ID) in `_enter_tree`. Enables `Camera3D` only for the authority player. Only authority processes input/physics.

### Multi-Server on Same Machine

ENet ports (1027–1037) and UDP discovery ports (4567–4577) are tried in sequence until one binds successfully. This allows multiple servers to run on the same machine simultaneously. The first `create_server()` attempt on port 1027 will print a C++ ENet error to the console — this is expected and harmless when port 1027 is already in use.

### Player Replication

`Scenes/player.tscn`: `CharacterBody3D` → `MultiplayerSynchronizer` (replicates `position`, spawn=true) + `SpringArm3D/Camera3D`. Players are spawned by the server via `add_child`. `MultiplayerSpawner` in `main_3D_Map.tscn` has `_spawnable_scenes = [player.tscn]` and `spawn_path = ".."`. Spawn positions are sent via RPC to each client after spawning — do not set position before `add_child` as clients (being authority) overwrite it.

### UDP Discovery Protocol

- **Host** (`HostLobby.gd`): binds first available port in 4567–4577, responds to every packet with `{"name": GameState.server_name, "port": GameState.server_port, "id": server_id}`.
- **Client** (`server_browser.gd`): binds port 0 (random), pings all ports 4567–4577 on both localhost and broadcast every second, deduplicates by `id`.

### Steam Integration

Steam is initialized in `scripts/multiplayerSTEAM.gd._ready()` with app ID `480` (Spacewar test app). Steam lobby creation/joining goes through Steam signals (`lobby_created`, `lobby_joined`). `HostLobby.gd` detects peer type via `multiplayer.multiplayer_peer is SteamMultiplayerPeer` to show Steam persona names instead of peer ID labels.

### Input Actions

Defined in `project.godot`: `left`=A, `right`=D, `up`=W, `down`=S, `ui_accept`=Space (jump).

### Terrain3D Addon

`addons/terrain_3d/` is a third-party terrain editing plugin. The `demo/` folder is also from the addon. Neither is core game logic — avoid modifying them.
