extends Node

const BEAT_DISTANCE := 4.0
const CUBE_DISTANCE := 0.5
const CUBE_HEIGHT_OFFSET := 0.4
const MISS_Z := 2.5
var CUBE_ROTATIONS := PackedFloat64Array([PI, 0.0, TAU*0.75, TAU*0.25, -TAU*0.375, TAU*0.375, -TAU*0.125, TAU*0.125, 0.0])
const APPDATA_PATH := "user://OpenSaber/"
