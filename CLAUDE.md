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
  → Host: creates ENet server (port 1027) → HostLobby.tscn
  → Join: ServerBrowser.tscn (UDP discovery list) → HostLobby.tscn
      → Start (host only): main_3D_Map.tscn
```

### Key Scripts

- **`scripts/multiplayerSTEAM.gd`** — Attached to `multiplayerSceneSteam.tscn`, instanced inside `main.tscn`. Despite the name, handles both ENet and Steam via the `net_mode` export. Host creates server on ENet port 1027 or Steam lobby. Join button goes to `ServerBrowser.tscn`. Start button goes directly to game.
- **`HostLobby.gd`** — Lobby controller. Shows player list via RPC-synced dictionary (`players: Dictionary`). Host binds UDP port 4567 and responds to discovery pings. Start button only visible to host. Leave closes the peer and all clients return to main menu via the `server_disconnected` signal.
- **`scripts/server_browser.gd`** — Binds a random UDP port, sends "discover" pings to `127.0.0.1:4567` and `255.255.255.255:4567` every second, deduplicates responses by `id` field, and builds the server list dynamically in code (no scene rows — uses `HBoxContainer` + `Label` + `Button` added to a `VBoxContainer`).
- **`scripts/game.gd`** — Attached to `main_3D_Map.tscn` root. Server spawns a player for each peer via `add_child` (name = peer ID string), then sends `_set_spawn_position` RPC directly to each client so they position their own character. Spawn positions are `Vector3(index * 5.0, 3.0, 0.0)`. Client is authority for their own player — setting position server-side gets overwritten.
- **`scripts/player.gd`** — `CharacterBody3D`. Sets `multiplayer_authority` from node name (peer ID string) in `_enter_tree`. In `_ready`, enables `Camera3D` only for the authority player. Only authority processes input/physics.
- **`scripts/multiplayerENET.gd`** — Empty stub, not used.

### Player Replication

`Scenes/player.tscn`: `CharacterBody3D` → `MultiplayerSynchronizer` (replicates `position`, spawn=true) + `SpringArm3D/Camera3D`. Players are spawned by the server via `add_child` with node name = peer ID string. `MultiplayerSpawner` in `main_3D_Map.tscn` has `_spawnable_scenes = [player.tscn]` and `spawn_path = ".."` (the root Node3D). Spawn positions are sent via RPC to each client after spawning — do not rely on setting position before `add_child` as clients (being authority) overwrite it.

### UDP Discovery Protocol

- **Host** (in `HostLobby.gd`): binds port 4567, responds to every incoming packet with `{"name": "Server", "port": 1027, "id": server_id}` sent to the requester's IP:port.
- **Client** (in `server_browser.gd`): binds port 0 (random), sends "discover" ping to `127.0.0.1:4567` and `255.255.255.255:4567` every second, reads responses and deduplicates by `id`. Multiple clients can browse simultaneously since each uses a random source port.

### Steam Integration

Steam is initialized in `scripts/multiplayerSTEAM.gd._ready()` with app ID `480` (Spacewar test app). Steam lobby creation/joining goes through Steam signals (`lobby_created`, `lobby_joined`). `HostLobby.gd` detects peer type via `multiplayer.multiplayer_peer is SteamMultiplayerPeer` to show Steam persona names instead of peer ID labels.

### Input Actions

Defined in `project.godot`: `left`=A, `right`=D, `up`=W, `down`=S, `ui_accept`=Space (jump).

### Terrain3D Addon

`addons/terrain_3d/` is a third-party terrain editing plugin. The `demo/` folder is also from the addon. Neither is core game logic — avoid modifying them.
