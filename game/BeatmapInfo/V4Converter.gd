extends RefCounted
class_name V4Converter


static func to_v3(
	beatmap: Dictionary,
	lightshow: Dictionary = {},
	audio_data: Dictionary = {}
) -> Dictionary:
	var result: Dictionary = {
		"version": "3.3.0",
		"bpmEvents": [],
		"rotationEvents": [],
		"colorNotes": [],
		"bombNotes": [],
		"obstacles": [],
		"sliders": [],
		"burstSliders": [],
		"waypoints": [],
		"basicBeatmapEvents": [],
		"colorBoostBeatmapEvents": [],
		"lightColorEventBoxGroups": [],
		"lightRotationEventBoxGroups": [],
		"lightTranslationEventBoxGroups": [],
		"vfxEventBoxGroups": [],
	}

	var note_data: Array = Utils.get_array(beatmap, "colorNotesData", [])
	for value: Variant in Utils.get_array(beatmap, "colorNotes", []):
		if not value is Dictionary:
			continue
		var item: Dictionary = value as Dictionary
		var data: Dictionary = _indexed_dictionary(note_data, item, "i")
		if data.is_empty():
			continue
		(result["colorNotes"] as Array).append({
			"b": Utils.get_float(item, "b", 0.0),
			"x": int(Utils.get_float(data, "x", 0.0)),
			"y": int(Utils.get_float(data, "y", 0.0)),
			"c": int(Utils.get_float(data, "c", 0.0)),
			"d": int(Utils.get_float(data, "d", 0.0)),
			"a": int(Utils.get_float(data, "a", 0.0)),
		})

	var bomb_data: Array = Utils.get_array(beatmap, "bombNotesData", [])
	for value: Variant in Utils.get_array(beatmap, "bombNotes", []):
		if not value is Dictionary:
			continue
		var item: Dictionary = value as Dictionary
		var data: Dictionary = _indexed_dictionary(bomb_data, item, "i")
		if data.is_empty():
			continue
		(result["bombNotes"] as Array).append({
			"b": Utils.get_float(item, "b", 0.0),
			"x": int(Utils.get_float(data, "x", 0.0)),
			"y": int(Utils.get_float(data, "y", 0.0)),
		})

	var obstacle_data: Array = Utils.get_array(beatmap, "obstaclesData", [])
	for value: Variant in Utils.get_array(beatmap, "obstacles", []):
		if not value is Dictionary:
			continue
		var item: Dictionary = value as Dictionary
		var data: Dictionary = _indexed_dictionary(obstacle_data, item, "i")
		if data.is_empty():
			continue
		(result["obstacles"] as Array).append({
			"b": Utils.get_float(item, "b", 0.0),
			"x": int(Utils.get_float(data, "x", 0.0)),
			"y": int(Utils.get_float(data, "y", 0.0)),
			"d": Utils.get_float(data, "d", 0.0),
			"w": int(Utils.get_float(data, "w", 0.0)),
			"h": int(Utils.get_float(data, "h", 0.0)),
		})

	var arc_data: Array = Utils.get_array(beatmap, "arcsData", [])
	for value: Variant in Utils.get_array(beatmap, "arcs", []):
		if not value is Dictionary:
			continue
		var item: Dictionary = value as Dictionary
		var head: Dictionary = _indexed_dictionary(note_data, item, "hi")
		var tail: Dictionary = _indexed_dictionary(note_data, item, "ti")
		var data: Dictionary = _indexed_dictionary(arc_data, item, "ai")
		if head.is_empty() or tail.is_empty() or data.is_empty():
			continue
		(result["sliders"] as Array).append({
			"b": Utils.get_float(item, "hb", 0.0),
			"c": int(Utils.get_float(head, "c", 0.0)),
			"x": int(Utils.get_float(head, "x", 0.0)),
			"y": int(Utils.get_float(head, "y", 0.0)),
			"d": int(Utils.get_float(head, "d", 0.0)),
			"mu": Utils.get_float(data, "m", 1.0),
			"tb": Utils.get_float(item, "tb", 0.0),
			"tx": int(Utils.get_float(tail, "x", 0.0)),
			"ty": int(Utils.get_float(tail, "y", 0.0)),
			"tc": int(Utils.get_float(tail, "d", 0.0)),
			"tmu": Utils.get_float(data, "tm", 1.0),
			"m": int(Utils.get_float(data, "a", 0.0)),
		})

	var chain_data: Array = Utils.get_array(beatmap, "chainsData", [])
	for value: Variant in Utils.get_array(beatmap, "chains", []):
		if not value is Dictionary:
			continue
		var item: Dictionary = value as Dictionary
		var head: Dictionary = _indexed_dictionary(note_data, item, "i")
		var data: Dictionary = _indexed_dictionary(chain_data, item, "ci")
		if head.is_empty() or data.is_empty():
			continue
		(result["burstSliders"] as Array).append({
			"b": Utils.get_float(item, "hb", 0.0),
			"c": int(Utils.get_float(head, "c", 0.0)),
			"x": int(Utils.get_float(head, "x", 0.0)),
			"y": int(Utils.get_float(head, "y", 0.0)),
			"d": int(Utils.get_float(head, "d", 0.0)),
			"tb": Utils.get_float(item, "tb", 0.0),
			"tx": int(Utils.get_float(data, "tx", 0.0)),
			"ty": int(Utils.get_float(data, "ty", 0.0)),
			"sc": int(Utils.get_float(data, "c", 0.0)),
			"s": Utils.get_float(data, "s", 1.0),
		})

	_convert_lightshow(result, lightshow)
	_convert_bpm_events(result, beatmap, audio_data)
	return result


static func _convert_lightshow(result: Dictionary, lightshow: Dictionary) -> void:
	var basic_data: Array = Utils.get_array(lightshow, "basicEventsData", [])
	for value: Variant in Utils.get_array(lightshow, "basicEvents", []):
		if not value is Dictionary:
			continue
		var item: Dictionary = value as Dictionary
		var data: Dictionary = _indexed_dictionary(basic_data, item, "i")
		if data.is_empty():
			continue
		(result["basicBeatmapEvents"] as Array).append({
			"b": Utils.get_float(item, "b", 0.0),
			"et": int(Utils.get_float(data, "t", 0.0)),
			"i": int(Utils.get_float(data, "i", 0.0)),
			"f": Utils.get_float(data, "f", -1.0),
		})

	var boost_data: Array = Utils.get_array(lightshow, "colorBoostEventsData", [])
	for value: Variant in Utils.get_array(lightshow, "colorBoostEvents", []):
		if not value is Dictionary:
			continue
		var item: Dictionary = value as Dictionary
		var data: Dictionary = _indexed_dictionary(boost_data, item, "i")
		if data.is_empty():
			continue
		(result["colorBoostBeatmapEvents"] as Array).append({
			"b": Utils.get_float(item, "b", 0.0),
			"o": Utils.get_bool(data, "b", false),
		})

	var waypoint_data: Array = Utils.get_array(lightshow, "waypointsData", [])
	for value: Variant in Utils.get_array(lightshow, "waypoints", []):
		if not value is Dictionary:
			continue
		var item: Dictionary = value as Dictionary
		var data: Dictionary = _indexed_dictionary(waypoint_data, item, "i")
		if data.is_empty():
			continue
		(result["waypoints"] as Array).append({
			"b": Utils.get_float(item, "b", 0.0),
			"x": int(Utils.get_float(data, "x", 0.0)),
			"y": int(Utils.get_float(data, "y", 0.0)),
			"d": int(Utils.get_float(data, "d", 0.0)),
		})

	var index_filters: Array = Utils.get_array(lightshow, "indexFilters", [])
	var color_boxes: Array = Utils.get_array(lightshow, "lightColorEventBoxes", [])
	var color_events: Array = Utils.get_array(lightshow, "lightColorEvents", [])
	var rotation_boxes: Array = Utils.get_array(lightshow, "lightRotationEventBoxes", [])
	var rotation_events: Array = Utils.get_array(lightshow, "lightRotationEvents", [])
	for value: Variant in Utils.get_array(lightshow, "eventBoxGroups", []):
		if not value is Dictionary:
			continue
		var group: Dictionary = value as Dictionary
		var group_type: int = int(Utils.get_float(group, "t", 0.0))
		if group_type == 1:
			var converted_group: Dictionary = {
				"b": Utils.get_float(group, "b", 0.0),
				"g": int(Utils.get_float(group, "g", 0.0)),
				"e": [],
			}
			for box_value: Variant in Utils.get_array(group, "e", []):
				if not box_value is Dictionary:
					continue
				var box_ref: Dictionary = box_value as Dictionary
				var filter: Dictionary = _indexed_dictionary(index_filters, box_ref, "f")
				var box_data: Dictionary = _indexed_dictionary(color_boxes, box_ref, "e")
				if filter.is_empty() or box_data.is_empty():
					continue
				var converted_box: Dictionary = {
					"f": filter.duplicate(true),
					"w": Utils.get_float(box_data, "w", 0.0),
					"d": int(Utils.get_float(box_data, "d", 0.0)),
					"r": Utils.get_float(box_data, "s", 0.0),
					# Compatibility for the existing V3LightingInfo parser.
					"s": Utils.get_float(box_data, "s", 0.0),
					"t": int(Utils.get_float(box_data, "t", 0.0)),
					"b": int(Utils.get_float(box_data, "b", 0.0)),
					"i": int(Utils.get_float(box_data, "e", 0.0)),
					"e": [],
				}
				for event_value: Variant in Utils.get_array(box_ref, "l", []):
					if not event_value is Dictionary:
						continue
					var event_ref: Dictionary = event_value as Dictionary
					var event_data: Dictionary = _indexed_dictionary(color_events, event_ref, "i")
					if event_data.is_empty():
						continue
					(converted_box["e"] as Array).append({
						"b": Utils.get_float(event_ref, "b", 0.0),
						"i": int(Utils.get_float(event_data, "p", 0.0)),
						# Compatibility aliases preserve v4 easing for the existing parser.
						"p": int(Utils.get_float(event_data, "p", 0.0)),
						"e": int(Utils.get_float(event_data, "e", 0.0)),
						"c": int(Utils.get_float(event_data, "c", 0.0)),
						"s": Utils.get_float(event_data, "b", 1.0),
						"f": int(Utils.get_float(event_data, "f", 0.0)),
						"sb": Utils.get_float(event_data, "sb", 0.0),
						"sf": int(Utils.get_float(event_data, "sf", 0.0)),
					})
				(converted_group["e"] as Array).append(converted_box)
			(result["lightColorEventBoxGroups"] as Array).append(converted_group)
		elif group_type == 2:
			var converted_rotation_group: Dictionary = {
				"b": Utils.get_float(group, "b", 0.0),
				"g": int(Utils.get_float(group, "g", 0.0)),
				"e": [],
			}
			for box_value: Variant in Utils.get_array(group, "e", []):
				if not box_value is Dictionary:
					continue
				var box_ref: Dictionary = box_value as Dictionary
				var filter: Dictionary = _indexed_dictionary(index_filters, box_ref, "f")
				var box_data: Dictionary = _indexed_dictionary(rotation_boxes, box_ref, "e")
				if filter.is_empty() or box_data.is_empty():
					continue
				var converted_rotation_box: Dictionary = {
					"f": _convert_index_filter(filter),
					"w": Utils.get_float(box_data, "w", 0.0),
					"d": int(Utils.get_float(box_data, "d", 0.0)),
					"s": Utils.get_float(box_data, "s", 0.0),
					"t": int(Utils.get_float(box_data, "t", 0.0)),
					"b": int(Utils.get_float(box_data, "b", 0.0)),
					"i": int(Utils.get_float(box_data, "e", 0.0)),
					"a": int(Utils.get_float(box_data, "a", 0.0)),
					"r": int(Utils.get_float(box_data, "f", 0.0)),
					"l": [],
				}
				for event_value: Variant in Utils.get_array(box_ref, "l", []):
					if not event_value is Dictionary:
						continue
					var event_ref: Dictionary = event_value as Dictionary
					var event_data: Dictionary = _indexed_dictionary(
						rotation_events, event_ref, "i"
					)
					if event_data.is_empty():
						continue
					(converted_rotation_box["l"] as Array).append({
						"b": Utils.get_float(event_ref, "b", 0.0),
						"p": int(Utils.get_float(event_data, "p", 0.0)),
						"e": int(Utils.get_float(event_data, "e", 0.0)),
						"l": int(Utils.get_float(event_data, "l", 0.0)),
						"r": Utils.get_float(event_data, "r", 0.0),
						"o": int(Utils.get_float(event_data, "d", 0.0)),
					})
				(converted_rotation_group["e"] as Array).append(converted_rotation_box)
			(result["lightRotationEventBoxGroups"] as Array).append(
				converted_rotation_group
			)

	result["basicEventTypesWithKeywords"] = Utils.get_dict(
		lightshow, "basicEventTypesWithKeywords", {}
	).duplicate(true)
	result["useNormalEventsAsCompatibleEvents"] = Utils.get_bool(
		lightshow, "useNormalEventsAsCompatibleEvents", true
	)


static func _convert_bpm_events(
	result: Dictionary,
	beatmap: Dictionary,
	audio_data: Dictionary
) -> void:
	var existing_events: Array = Utils.get_array(beatmap, "bpmEvents", [])
	if not existing_events.is_empty():
		result["bpmEvents"] = existing_events.duplicate(true)
		return

	var frequency: float = Utils.get_float(audio_data, "songFrequency", 0.0)
	if frequency <= 0.0:
		return
	for value: Variant in Utils.get_array(audio_data, "bpmData", []):
		if not value is Dictionary:
			continue
		var region: Dictionary = value as Dictionary
		var start_sample: float = Utils.get_float(region, "si", 0.0)
		var end_sample: float = Utils.get_float(region, "ei", 0.0)
		var start_beat: float = Utils.get_float(region, "sb", 0.0)
		var end_beat: float = Utils.get_float(region, "eb", start_beat)
		var sample_count: float = end_sample - start_sample
		if sample_count <= 0.0:
			continue
		var bpm: float = (end_beat - start_beat) * frequency * 60.0 / sample_count
		(result["bpmEvents"] as Array).append({"b": start_beat, "m": bpm})


static func _indexed_dictionary(data: Array, reference: Dictionary, key: String) -> Dictionary:
	var index: int = int(Utils.get_float(reference, key, -1.0))
	if index < 0 or index >= data.size() or not data[index] is Dictionary:
		return {}
	return data[index] as Dictionary


static func _convert_index_filter(filter: Dictionary) -> Dictionary:
	return {
		"f": int(Utils.get_float(filter, "f", 0.0)),
		"p": int(Utils.get_float(filter, "p", 0.0)),
		"t": int(Utils.get_float(filter, "t", 0.0)),
		"r": int(Utils.get_float(filter, "r", 0.0)),
		"c": int(Utils.get_float(filter, "c", 0.0)),
		"n": int(Utils.get_float(filter, "n", 0.0)),
		"s": int(Utils.get_float(filter, "s", 0.0)),
		"l": Utils.get_float(filter, "l", 0.0),
		"d": int(Utils.get_float(filter, "d", 0.0)),
	}
