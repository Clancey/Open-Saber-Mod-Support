extends TextureProgressBar

var viewport : SubViewport

func _ready():
	await get_tree().process_frame
	if get_parent() is SubViewport:
		viewport = get_parent()
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func set_percent(val,anim=true):
	$Label.text = "%d%%" % val
	value = val
	if anim:
		$AnimationPlayer.stop()
		$AnimationPlayer.play("change")
		if viewport:
			viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
			await $AnimationPlayer.animation_finished
			viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	elif viewport:
		$update_once.update_once(viewport)
