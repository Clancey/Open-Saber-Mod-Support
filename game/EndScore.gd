extends Node3D
class_name EndScore

var animated_percent: float = 0.0
@onready var percent_indicator := $PercentIndicator as PercentIndicator

func show_score(score: int,record: int,percent: float,song_string: String="",is_full_combo: bool=false,is_new_record: bool=false) -> void:
	percent_indicator.endscore()
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(self,^"animated_percent",percent,3.0).from(0.0)
	tw.play()
	while tw.is_running():
		percent_indicator.update_percent(animated_percent)
		await get_tree().process_frame
	#_on_Tween_tween_completed()
