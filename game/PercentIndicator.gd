extends TextureProgressBar


func set_percent(val,anim=true):
	$Label.text = "%d%%" % val
	value = val
	if anim:
		$AnimationPlayer.stop()
		$AnimationPlayer.play("change")
