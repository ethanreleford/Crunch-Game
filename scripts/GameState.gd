class_name GameState

# Networking
static var server_port: int = 1027
static var server_name: String = "My Server"
static var steam_lobby_id: int = 0

# Class selection — set before entering the game, cannot change mid-round
static var selected_class_id: String = "damage"
static var player_class_ids: Dictionary = {}  # peer_id -> class_id, populated in MultiplayerClassSelect
static var player_names: Dictionary = {}      # peer_id -> display name, populated in HostLobby
