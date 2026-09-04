extends GameState
class_name GameStateFailed

func _ready(game: BeepSaber_Game) -> void:
	game.song_player.stop()
	game.song_player.volume_db = 0.0
	game._in_wall = false
	Scoreboard.paused = true
	game._clear_track()

	var current_percent: float = 1.0
	if Scoreboard.right_notes + Scoreboard.wrong_notes > 0.0:
		current_percent = (
			Scoreboard.right_notes / (Scoreboard.right_notes + Scoreboard.wrong_notes)
		)
	game.endscore.show_failed(
		Scoreboard.points,
		current_percent,
		"%s By %s\n%s     Map author: %s" % [
			Map.current_info.song_name,
			Map.current_info.song_author_name,
			Map.current_difficulty.custom_name,
			Map.current_info.level_author_name,
		]
	)

	game.endscore.set_buttons_disabled(false)
	game.main_menu._hide()
	game.settings_canvas._hide()
	game.show_MapSourceDialogs(false)
	game.endscore._show()
	game.pause_menu._hide()
	game.highscore_canvas._hide()
	game.name_selector_canvas._hide()
	game.left_saber._hide()
	game.right_saber._hide()
	game.multiplier_label.visible = false
	game.point_label.visible = false
	game.percent_indicator.visible = false
	game.track.visible = false
	game.left_ui_raycast.visible = true
	game.right_ui_raycast.visible = true
	game.highscore_keyboard._hide()
	game.online_search_keyboard._hide()
	game.left_saber.set_swingcast_enabled(false)
	game.right_saber.set_swingcast_enabled(false)
