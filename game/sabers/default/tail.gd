extends Node3D

@onready var mesh : MeshInstance3D = $Mesh
@onready var imm_geo : ImmediateMesh = $Mesh.mesh

@export var size = 1.0
# Called when the node enters the scene tree for the first time.
func _ready():
	mesh.material_override = mesh.material_override.duplicate()
	imm_geo = imm_geo.duplicate()
	mesh.mesh = imm_geo
	remove_child(mesh)
	get_tree().get_root().add_child(mesh)

func set_color(color):
	#mesh.material_override.set_shader_parameter("color", color);
	mesh.material_override.albedo_color = color
	mesh.material_override.emission = color

func _exit_tree():
	mesh.queue_free()

var last_pos = []
var time = 0.15
func _process(delta):
	if visible and size > 0:
		var pos = [global_position,to_global(position + Vector3(0,size,0))]
		imm_geo.clear_surfaces()
		if last_pos.size() > 0:
			imm_geo.surface_begin(Mesh.PRIMITIVE_TRIANGLES)

			for i in range(last_pos.size()):
				var posA = pos
				if i > 0:
					posA = last_pos[i-1][0]
				var posB = last_pos[i][0]
				
				var t = clamp(last_pos[i][1] / time, 0.02, 0.98)
				var offsetted = clamp(t + (1.0/last_pos.size()), 0.02, 0.98)

				imm_geo.surface_set_uv(Vector2(t,0.98))
				imm_geo.surface_add_vertex(posA[0])
				imm_geo.surface_set_uv(Vector2(t,0.02))
				imm_geo.surface_add_vertex(posA[1])
				imm_geo.surface_set_uv(Vector2(offsetted,0.02))
				imm_geo.surface_add_vertex(posB[1])

				imm_geo.surface_set_uv(Vector2(t,0.98))
				imm_geo.surface_add_vertex(posA[0])
				imm_geo.surface_set_uv(Vector2(offsetted,0.98))
				imm_geo.surface_add_vertex(posB[0])
				imm_geo.surface_set_uv(Vector2(offsetted,0.02))
				imm_geo.surface_add_vertex(posB[1])
				
				last_pos[i][1] += delta
				if last_pos[i][1] > time:
					last_pos[i][1] = -1

			imm_geo.surface_end()

		last_pos.push_front([pos,0.0])
		for i in range(last_pos.size()):
			if last_pos[i][1] < 0:
				last_pos.resize(i-1)
				break
	elif last_pos.size() > 0:
		imm_geo.clear_surfaces()
		last_pos = []
