extends Node3D
class_name RemotePlayer

# Simple avatar for one lobby member: a headset-shaped box, a name tag and two
# sabers. Head/LeftHand/RightHand transforms are replicated by the Sync
# MultiplayerSynchronizer (~20 Hz) from the authority peer, so on that peer
# LocalPlayerBroadcaster writes the XR camera and controller transforms into
# them and on every other peer the synchronizer applies the received values.
# Set peer_id BEFORE adding the node to the tree so the authority is right
# when the synchronizer enters the tree.

## Peer that owns this avatar; must match on every client.
@export var peer_id := -1
@export var player_name := "":
	set(value):
		player_name = value
		if is_node_ready():
			_name_label.text = value

@onready var head := $Head as Node3D
@onready var left_hand := $LeftHand as Node3D
@onready var right_hand := $RightHand as Node3D
@onready var left_saber := $LeftHand/LeftSaber as DefaultSaber
@onready var right_saber := $RightHand/RightSaber as DefaultSaber
@onready var _name_label := $Head/NameLabel as Label3D


func _enter_tree() -> void:
	if peer_id > 0:
		set_multiplayer_authority(peer_id)


func _ready() -> void:
	_name_label.text = player_name
	# The controllers use the OpenXR aim pose (-Z forward) and the blade runs
	# along +Y, so rotate like LightSaber.offset_rot does.
	left_saber.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	right_saber.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	set_colors(Settings.color_left, Settings.color_right)
	for saber: DefaultSaber in [left_saber, right_saber]:
		saber.set_thickness(Settings.thickness)
		saber.set_trail(false)
		saber._show()


func set_colors(left: Color, right: Color) -> void:
	left_saber.set_color(left)
	right_saber.set_color(right)


## Authority side: write the tracked transforms (world space of the local rig).
func set_pose(head_transform: Transform3D, left_transform: Transform3D, right_transform: Transform3D) -> void:
	head.global_transform = head_transform
	left_hand.global_transform = left_transform
	right_hand.global_transform = right_transform
