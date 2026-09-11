extends Node3D
class_name MultiplayerAvatars

# Spawns one RemotePlayer per lobby member (manually, from roster_changed, so
# every peer builds the same node names under the same path and the
# synchronizers find each other without a MultiplayerSpawner). Players stand
# side by side on X, `spacing` apart, in peer-id order, and the arrangement is
# shifted so the local player is always at this node's origin (the local rig
# is at the world origin). The local avatar is kept invisible; it only exists
# to feed the synchronizer.
#
# Put this node at the same scene path on every client (for example
# BeepSaber_Game/MultiplayerAvatars).

@export var remote_player_scene: PackedScene = preload("res://game/multiplayer/RemotePlayer.tscn")
@export var spacing := 1.2
@export var hide_local_avatar := true

var _avatars: Dictionary = {}  # peer id -> RemotePlayer
var _local_id := 0


func _ready() -> void:
	if not Engine.is_editor_hint() and has_node("/root/MultiplayerSession"):
		var session: Node = get_node("/root/MultiplayerSession")
		session.roster_changed.connect(_on_session_roster_changed)
		session.lobby_left.connect(_on_session_lobby_left)


func get_local_avatar() -> RemotePlayer:
	return _avatars.get(_local_id) as RemotePlayer


func get_avatar(peer_id: int) -> RemotePlayer:
	return _avatars.get(peer_id) as RemotePlayer


func get_avatar_count() -> int:
	return _avatars.size()


func clear() -> void:
	for avatar: RemotePlayer in _avatars.values():
		avatar.queue_free()
	_avatars.clear()


## Rebuilds the avatar set from a roster ([{id, name, ...}]) as seen by `local_id`.
func apply_roster(players: Array[Dictionary], local_id: int) -> void:
	_local_id = local_id
	var ids: Array[int] = []
	for player: Dictionary in players:
		ids.append(int(player["id"]))
	ids.sort()

	for existing_id: int in _avatars.keys():
		if not ids.has(existing_id):
			(_avatars[existing_id] as RemotePlayer).queue_free()
			_avatars.erase(existing_id)

	var local_slot := maxi(ids.find(local_id), 0)
	for player: Dictionary in players:
		var id := int(player["id"])
		var avatar: RemotePlayer = _avatars.get(id)
		if avatar == null:
			avatar = remote_player_scene.instantiate() as RemotePlayer
			avatar.name = "Player_%d" % id
			avatar.peer_id = id
			avatar.player_name = str(player.get("name", ""))
			add_child(avatar)
			_avatars[id] = avatar
		else:
			avatar.player_name = str(player.get("name", ""))
		var slot := ids.find(id)
		avatar.position = Vector3((slot - local_slot) * spacing, 0.0, 0.0)
		avatar.visible = not (hide_local_avatar and id == local_id)


func _on_session_roster_changed(players: Array[Dictionary]) -> void:
	var session: Node = get_node("/root/MultiplayerSession")
	apply_roster(players, session.get_local_id())


func _on_session_lobby_left(_reason: String) -> void:
	clear()
