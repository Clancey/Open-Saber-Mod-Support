extends Node3D


func show_points(position=Vector3(),value="x",color = Color(1,1,1)):
	transform.origin = position
	$SubViewport/Label.text = str(value)
	$SubViewport/Label.modulate = color
	$AnimationPlayer.stop()
	$AnimationPlayer.play("hit")
#	$AudioStreamPlayer3D.play()
