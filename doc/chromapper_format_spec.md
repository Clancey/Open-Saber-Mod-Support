# ChroMapper Save/Export Format Spec (from source, Assets/__Scripts/Beatmap)

Sources: `Info/V2/V2Info.cs`, `Info/V4/V4Info.cs`, `V2/V2Difficulty.cs`, `V3/V3Difficulty.cs`, `V4/V4Difficulty.cs`, `V4/V4CommonData.cs`, `Base/*.cs`, `Converters/V2ToV3.cs`, `Base/BaseDifficulty.cs:Save()`. Types: f=float, i=int, s=string, b=bool, o=object, a=array, c=color obj `{r,g,b,a}`.

## 1. Info.dat

### v2 Info (`V2Info.GetOutputJson`, `_version` = "2.1.0")
| Key | Type | Notes |
|---|---|---|
| `_version` | s | "2.1.0" |
| `_songName`,`_songSubName`,`_songAuthorName`,`_levelAuthorName` | s | |
| `_beatsPerMinute`,`_songTimeOffset`,`_shuffle`,`_shufflePeriod`,`_previewStartTime`,`_previewDuration` | f | |
| `_songFilename`,`_coverImageFilename`,`_environmentName`,`_allDirectionsEnvironmentName` | s | |
| `_environmentNames` | a[s] | |
| `_colorSchemes` | a[o] | `{useOverride:b, colorScheme:{colorSchemeId:s, saberAColor:c, saberBColor:c, obstaclesColor:c, environmentColor0:c, environmentColor1:c, environmentColor0Boost:c, environmentColor1Boost:c}}` |
| `_difficultyBeatmapSets[]` | a[o] | `_beatmapCharacteristicName:s`, `_difficultyBeatmaps:a`, opt `_customData:{_characteristicLabel:s,_characteristicIconImageFilename:s}` |
| `_difficultyBeatmaps[]` | o | `_difficulty:s, _difficultyRank:i, _beatmapFilename:s, _noteJumpMovementSpeed:f, _noteJumpStartBeatOffset:f, _beatmapColorSchemeIdx:i, _environmentNameIdx:i, _customData?` |
| diff `_customData` | o | `_oneSaber:b, _showRotationNoteSpawnLines:b, _difficultyLabel:s, _information:a[s], _warnings:a[s], _suggestions:a[s], _requirements:a[s], _colorLeft:c, _colorRight:c, _obstacleColor:c, _envColorLeft:c, _envColorRight:c, _envColorWhite:c, _envColorLeftBoost:c, _envColorRightBoost:c, _envColorWhiteBoost:c` (each only if set) |
| root `_customData` | o | `_contributors:a[{_name,_role,_iconPath}]`, `_customEnvironment:s`, `_customEnvironmentHash:s`, `_editors:{_lastEditedBy:"ChroMapper", ChroMapper:{version:s}}` |

### v4 Info (`V4Info.GetOutputJson`, `version` = "4.0.1")
| Key | Type | Notes |
|---|---|---|
| `version` | s | "4.0.1" |
| `song` | o | `{title:s, subTitle:s, author:s}` |
| `audio` | o | `{songFilename:s, songDuration:f, audioDataFilename:s, bpm:f, lufs:f, previewStartTime:f, previewDuration:f}` |
| `songPreviewFilename`,`coverImageFilename` | s | |
| `environmentNames` | a[s] | |
| `colorSchemes` | a[o] | `{colorSchemeName:s, overrideNotes:b, saberAColor:s(RGBA hex), saberBColor, obstaclesColor, overrideLights:b, environmentColor0, environmentColor1, environmentColor0Boost, environmentColor1Boost}` |
| `difficultyBeatmaps[]` | a[o] | `characteristic:s, difficulty:s, beatmapAuthors:{mappers:a[s], lighters:a[s]}, environmentNameIdx:i, beatmapColorSchemeIdx:i, noteJumpMovementSpeed:f, noteJumpStartBeatOffset:f, beatmapDataFilename:s, lightshowDataFilename:s, customData?` |
| diff `customData` | o | same as v2 diff customData with `_` stripped: `oneSaber, showRotationNoteSpawnLines, difficultyLabel, information, warnings, suggestions, requirements, colorLeft, colorRight, obstacleColor, envColorLeft, envColorRight, envColorWhite, envColorLeftBoost, envColorRightBoost, envColorWhiteBoost` |
| root `customData` | o | `contributors:a[{name,role,iconPath}]`, `characteristicData:a[{characteristic:s,label?:s,iconPath?:s}]`, `customEnvironment:s`, `customEnvironmentHash:s`, `editors:{lastEditedBy:"ChroMapper", ChroMapper:{version}}` |

Side files: v2 Info → `BPMInfo.dat` (`_version,_songSampleCount,_songFrequency,_regions[{_startSampleIndex,_endSampleIndex,_startBeat,_endBeat}]`); v4 Info → `AudioData.dat` (`version,songChecksum:"",songSampleCount,songFrequency,bpmData[{si,ei,sb,eb}],lufsData[{si,ei,l}]`). No v3 Info exists; a v3 difficulty pairs with v2 Info.

## 2. Difficulty files

### v2 (`_version` = "2.6.0")
| Top key | Contents |
|---|---|
| `_events` | events + BPM events (`_type`=100) merged, sorted; BPM event at beat 0 auto-inserted |
| `_notes`, `_obstacles`, `_waypoints` | arrays below |
| `_sliders` | always `[]` (arcs are NOT written in v2) |
| `_specialEventsKeywordFilters` | `{_keywords:[{_keyword:s,_specialEvents:a[i]}]}` or `{}` |
| `_customData` | `_bookmarks[{_time,_name,_color}]`, `_bookmarksUseOfficialBpmEvents:true`, `_customEvents[{_time,_type,_data}]`, `_environment[...]`, `_pointDefinitions:a[{_name,_points}]`, `_materials:{name:{_color,_shader,_track,_shaderKeywords}}`, `_time:f`, `_BPMChanges`(legacy passthrough) |

| Object | Fields |
|---|---|
| note | `_time:f, _lineIndex:i, _lineLayer:i, _type:i(0/1/3), _cutDirection:i, _customData?` |
| obstacle | `_time:f, _lineIndex:i, _type:i, _duration:f, _width:i, _customData?` |
| event | `_time:f, _type:i, _value:i, _floatValue:f, _customData?` |
| bpm event | `_time:f, _type:100, _value:0, _floatValue:bpm` |
| waypoint | `_time, _lineIndex, _lineLayer, _offsetDirection` |
| environment | `_id/_lookupMethod` or `_geometry:{_type,_material}`, `_track, _duplicate, _active, _scale, _position, _rotation, _localPosition, _localRotation, _lightID` (each `[x,y,z]`) |

### v3 (`version` = "3.3.0")
| Top key | Contents |
|---|---|
| `bpmEvents` | `{b:f, m:f}` |
| `rotationEvents` | `{b:f, e:i(0 early/1 late), r:f}` |
| `colorNotes` | `{b:f, x:i, y:i, a:i, c:i, d:i, customData?}` |
| `bombNotes` | `{b, x, y, customData?}` |
| `obstacles` | `{b, x, y, d:f(duration), w:i, h:i, customData?}` |
| `sliders` (arcs) | `{b, c, x, y, d, mu:f, tb:f, tx, ty, tc, tmu:f, m:i, customData?}` |
| `burstSliders` (chains) | `{b, c, x, y, d, tb, tx, ty, sc:i, s:f, customData?}` |
| `waypoints` | `{b, x, y, d}` |
| `basicBeatmapEvents` | `{b, et:i, i:i, f:f, customData?}` |
| `colorBoostBeatmapEvents` | `{b, o:b}` |
| `lightColorEventBoxGroups` | `{b, g:i, e:[box], customData?}`; box `{f:filter, w:f, d:i, r:f, t:i, b:i, i:i, e:[{b,c,s,i,f,sb,sf}]}` |
| `lightRotationEventBoxGroups` | box `{f, w, d, s, t, b, a:i, r:i(flip), i, l:[{b,r,o,e,l,p}]}` |
| `lightTranslationEventBoxGroups` | box `{f, w, d, s, t, b, a, r, i, l:[{b,p,e,t}]}` |
| `vfxEventBoxGroups` | `{b, g, t:i, e:[{f, w, d, s, t, b, i, l:a[i idx into _fl]}]}` |
| `_fxEventsCollection` | `{_il:[{b,p,v}], _fl:[{b,p,v,i}]}` |
| `basicEventTypesWithKeywords` | `{d:[{k:s, e:a[i]}]}` |
| `useNormalEventsAsCompatibleEvents` | b |
| `customData` | `bookmarks[{b,n,c}]`, `bookmarksUseOfficialBpmEvents:true`, `customEvents[{b,t,d}]`, `environment[...]`(keys `id,lookupMethod,geometry{type,material},track,duplicate,active,scale,position,rotation,localPosition,localRotation,lightID,components`), `pointDefinitions:{name:points}`, `materials:{name:{color,shader,track,shaderKeywords}}`, `time:f`, `fakeColorNotes`, `fakeBombNotes`, `fakeObstacles`, `fakeBurstSliders` (fake objects moved here, same shape), `BPMChanges` passthrough |
| index filter (`f`) | `{f:i, p:i, t:i, r:i, c:i, n:i, s:i, l:f, d:i}` |

### v4 beatmap (`version` = "4.1.0") — objects reference shared data via index `i`
| Top key | Object fields | Data (`*Data`) fields |
|---|---|---|
| `colorNotes` / `colorNotesData` | `{b:f, r:i(rotation), i:idx}` | `{x, y, c, d, a}` |
| `bombNotes` / `bombNotesData` | `{b, r, i}` | `{x, y}` |
| `obstacles` / `obstaclesData` | `{b, r, i}` | `{x, y, d:f, w, h}` |
| `arcs` / `arcsData` | `{hb:f, tb:f, hr:i, tr:i, hi:idx→colorNotesData, ti:idx→colorNotesData, ai:idx→arcsData}` | `{m:f, tm:f, a:i(midAnchor)}` |
| `chains` / `chainsData` | `{hb, tb, hr, tr, i:idx→colorNotesData, ci:idx→chainsData}` | `{tx, ty, c:i(sliceCount), s:f(squish)}` |
| `njsEvents` / `njsEventData` (sic, no s) | `{b, i}` | `{p:i, e:i, d:f}` |
| `spawnRotations`/`spawnRotationsData` | read only (`{t,r}`); NOT written | |
| no `customData` | v4 difficulty/lightshow writes no customData; per-object customData dropped | |

### v4 lightshow file (`version` = "4.0.0", path = Info `lightshowDataFilename`; if empty/same as beatmap, CM writes `LightsFor-<name>`)
| Top key | Fields |
|---|---|
| `basicEvents` / `basicEventsData` | `{b, i}` / `{t:i, i:i, f:f}` |
| `colorBoostEvents` / `colorBoostEventsData` | `{b, i}` / `{b:bool}` |
| `waypoints` / `waypointsData` | `{b, i}` / `{x, y, d}` |
| `indexFilters` | `{f, p, t, r, c, n, s, l, d}` |
| `eventBoxGroups` | `{b, g:i, t:i(1 color,2 rot,3 trans,4 fx), e:[{f:idx→indexFilters, e:idx→*EventBoxes, l:[{b, i:idx→*Events}]}]}` |
| `lightColorEventBoxes` / `lightColorEvents` | `{w, d, s, t, b, e}` / `{p, e, c, b, f, sb, sf}` |
| `lightRotationEventBoxes` / `lightRotationEvents` | `{w, d, s, t, b, e, a, f}` / `{p, e, r, d, l}` |
| `lightTranslationEventBoxes` / `lightTranslationEvents` | `{w, d, s, t, b, e, a, f}` / `{p, e, t}` |
| `fxEventBoxes` / `floatFxEvents` | `{w, d, s, t, b, e}` / `{p, e?, v}` |
| `basicEventTypesWithKeywords` | `{d:[{k, e}]}` |
| `useNormalEventsAsCompatibleEvents` | b |

v4 bookmarks: written to `<mapdir>/Bookmarks/<file>` as `{name:"ChroMapper", characteristic, difficulty, color:"00FFFF", bookmarks:[{beat, label, text}]}`.

## 3. customData keys written (v2 `_`-prefixed; v3 and v4 unprefixed; v4 drops object customData on save)

### Objects (note / bomb / obstacle / arc / chain) — `BaseGrid.SaveCustom`, `BaseObject.SaveCustom`
| Meaning | v2 key | v3/v4 key | Type |
|---|---|---|---|
| Chroma color | `_color` | `color` | `[r,g,b(,a)]` |
| NE track | `_track` | `track` | s or a[s] |
| NE coordinates | `_position` | `coordinates` | `[x,y]` |
| NE world rotation | `_rotation` | `worldRotation` | f or `[x,y,z]` |
| NE local rotation | `_localRotation` | `localRotation` | `[x,y,z]` |
| Chroma spawn effect | `_disableSpawnEffect` (b) | `spawnEffect` (b, inverted) | b |
| NE NJS | `_noteJumpMovementSpeed` | `noteJumpMovementSpeed` | f |
| NE offset | `_noteJumpStartBeatOffset` | `noteJumpStartBeatOffset` | f |
| NE animation | `_animation` | `animation` | o (v3 subkeys: `color, definitePosition, dissolve, dissolveArrow, interactable, localRotation, offsetPosition, offsetRotation, scale, time`; v2 uses `_`-prefixed `_position`/`_rotation` for offsets) |
| NE obstacle size | `_scale` | `size` | `[w,h,d]` |
| arc/chain tail coord | `_tailPosition` | `tailCoordinates` | `[x,y]` |
| ME/NE note cut dir | `_cutDirection` | (v2 only, written only when MapVersion==2) | i/f |
| NE fake | `_fake:true` (v2 only) | (v3: object moved to `customData.fakeColorNotes` etc.) | b |
| NE passthrough (read/preserved, not authored by CM) | `_interactable`,`_disableNoteGravity`,`_disableNoteLook`,`_flip` | `uninteractable`,`disableNoteGravity`,`disableNoteLook`,`flip` | b / `[x,y]` |

### Events — `BaseEvent.SaveCustom`
| Meaning | v2 key | v3/v4 key | Type |
|---|---|---|---|
| Chroma color | `_color` | `color` | a[f] |
| Chroma lightID | `_lightID` | `lightID` | a[i] (always array) |
| Chroma gradient | `_lightGradient` | `lightGradient` | `{_duration,_startColor,_endColor,_easing}` (v2-style keys even in v3) |
| Chroma lerp/easing | `_lerpType`,`_easing` | `lerpType`,`easing` | s |
| Chroma ring | `_step`,`_prop`,`_speed`,`_rotation`,`_direction`,`_nameFilter` | `step`,`prop`,`speed`,`rotation`,`direction`,`nameFilter` | f/i/s |
| Chroma laser | `_lockPosition` | `lockRotation` | b |
| Chroma legacy (v2 read only) | `_propID`,`_stepMult`,`_propMult`,`_speedMult`,`_preciseSpeed`,`_reset`,`_counterSpin` | `propID` | |
| NE lane rotation | `_rotation` | `rotation` | f (rotation events) |
| track | `_track` | `track` | s |

### Custom events (`customData._customEvents` / `customEvents`)
v2 `{_time,_type,_data{_duration,_easing,_repeat,_childrenTracks,_parentTrack,_worldPositionStays,_track,_color}}`; v3 `{b,t,d{duration,easing,repeat,childrenTracks,parentTrack,worldPositionStays,track,color}}`.

### Mapping Extensions encodings (read/decoded; CM preserves values but does not author them — no placement code emits 1000-based ints)
| Field | Encoding | Decode |
|---|---|---|
| note/obstacle `x` (`_lineIndex`) | `>=1000` or `<=-1000` | notes: `x/1000 - 2.5` (pos) / `x/1000 - 0.5` (neg); obstacles: `(x-1000)/1000 - 2` / `(x-1000)/1000` |
| note `y` | `>=1000`/`<=-1000` | `y/1000 - 1` |
| note `_cutDirection` | `1000..1360` | angle = `dir - 1000` degrees |
| obstacle `_width` | `>=1000` | `(w-1000)/1000` |
| obstacle `_type` (v2) | `2..999` start-height; `1000..4000` height only; `>4000` `(type-4001)`: `%1000` start, `/1000` height | units `1000/3.5` per full wall |
| lane rotation event `_value` | `1000..1720` | degrees = `value - 1360` |
| requirement | MappingExtensionsReq adds `"Mapping Extensions"` to `_requirements` when any of the above present | |

## 4. Version selection on save
| Rule | Source |
|---|---|
| `Settings.Instance.MapVersion` (int, default 3) drives everything: `Save()` switches 2→`V2Difficulty`, 3→`V3Difficulty`, 4→`V4Difficulty`(+lightshow+Bookmarks/) | `BaseDifficulty.cs:375` |
| MapVersion is set from the loaded difficulty's `version`/`_version` first char on load (`BeatmapFactory.GetDifficultyFromJson`) and from `map.MajorVersion` in DifficultySelect / SongInfoEditUI | `Helper/BeatmapFactory.cs:25-41` |
| User can switch v2/v3/v4 in-editor (`BeatmapVersionSwitchInputController`); v4 option only offered when Info is v4; switching 2↔3/4 runs `ConvertCustomDataVersion` (V2ToV3/V3ToV2 key renames) | `MapEditor/Input/BeatmapVersionSwitchInputController.cs` |
| Info.dat version chosen at song creation (`CreateNewSong`: `isV4 ? "4.0.1" : "2.1.0"`) and saved by `BaseInfo.Save()` by first char of `Version` (2→V2Info, 4→V4Info); no v3 Info | `Info/Base/BaseInfo.cs:174-182` |
| Object customData key names resolve via `Settings.Instance.MapVersion switch {2=>V2*, 3 or 4=>V3*}` at save time | `Base/BaseNote.cs:115+`, `Base/BaseEvent.cs:187+` |
| JSON formatting: `Settings.FormatJson` (indent 2) else compact; `TimeValueDecimalPrecision`=3 (default), BPM event times use `BpmTimeValueDecimalPrecision`=6 | `Settings/Settings.cs:41,193,194` |
| AutoSave warns when saving v2 with v3-only data (angle offset, obstacle y/height, chains, arcs) | `MapEditor/AutoSaveController.cs:301` |

Capabilities: CM can read and write v2 (2.6.0), v3 (3.3.0), v4 (4.1.0 beatmap + 4.0.0 lightshow). v2 export drops arcs (`_sliders:[]`) and chains; v4 export drops all object/difficulty customData (Chroma/NE/ME on objects lost) and does not write spawnRotations.
