extends Cuttable
class_name ChainHead

func spawn(chain_info: Map.ChainInfo, current_beat: float, color: Color) -> void:
	speed = Constants.BEAT_DISTANCE * Map.current_info.beats_per_minute * 0.016666666666666667
	beat = chain_info.head_beat
	
	transform.origin.x = (chain_info.head_line_index - 1.5) * Constants.CUBE_DISTANCE
	transform.origin.y = Constants.CUBE_HEIGHT_OFFSET + ((chain_info.head_line_layer + 1) * Constants.CUBE_DISTANCE)
	transform.origin.z = -(chain_info.head_beat - current_beat) * Constants.BEAT_DISTANCE
	
	rotation.z = Constants.CUBE_ROTATIONS[chain_info.head_cut_direction]
	
	var instance := $MeshInstance3D as MeshInstance3D
	var mesh := instance.mesh as TextMesh
	var material := mesh.material as StandardMaterial3D
	material.albedo_color = color
	
	visible = true

func on_miss() -> void:
	Scoreboard.reset_combo()
	queue_free()
