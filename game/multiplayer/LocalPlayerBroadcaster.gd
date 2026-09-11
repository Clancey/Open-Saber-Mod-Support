extends Node
class_name LocalPlayerBroadcaster

# Copies the local XR camera and controller transforms into the local player's
# RemotePlayer avatar every frame so its MultiplayerSynchronizer replicates
# them. Point the paths at the nodes in BeepSaber_Game.tscn:
#   XROrigin3D/XRCamera3D, XROrigin3D/LeftController, XROrigin3D/RightController
# and either set `avatar` directly or give it the MultiplayerAvatars node,
# from which it picks up the local avatar whenever the roster changes.

@export var camera_path: NodePath
@export var left_controller_path: NodePath
@export var right_controller_path: NodePath
@export var avatars_path: NodePath

var avatar: RemotePlayer
var _camera: Node3D
var _left: Node3D
var _right: Node3D
var _avatars: MultiplayerAvatars


func _ready() -> void:
	if not camera_path.is_empty():
		_camera = get_node_or_null(camera_path) as Node3D
	if not left_controller_path.is_empty():
		_left = get_node_or_null(left_controller_path) as Node3D
	if not right_controller_path.is_empty():
		_right = get_node_or_null(right_controller_path) as Node3D
	if not avatars_path.is_empty():
		_avatars = get_node_or_null(avatars_path) as MultiplayerAvatars


func bind_sources(camera: Node3D, left: Node3D, right: Node3D) -> void:
	_camera = camera
	_left = left
	_right = right


func _process(_delta: float) -> void:
	if _avatars != null:
		avatar = _avatars.get_local_avatar()
	if avatar == null or not avatar.is_inside_tree() or not avatar.is_multiplayer_authority():
		return
	if _camera == null or _left == null or _right == null:
		return
	avatar.set_pose(_camera.global_transform, _left.global_transform, _right.global_transform)
