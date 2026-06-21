extends Node

@onready var sub_viewport: SubViewport = $SubViewport
@onready var mesh_instance_3d: MeshInstance3D = $SubViewport/MeshInstance3D

func _ready() -> void:
	var build_mesh_paths := DirAccess.get_files_at("res://Models/Build")
	for path in build_mesh_paths:
		if path.ends_with("obj"):
			var mesh := load("res://Models/Build/" + path)
			mesh_instance_3d.mesh = mesh
			await RenderingServer.frame_post_draw
			var img = sub_viewport.get_texture().get_image()
			img.save_png("res://Resources/Icons/" + path.substr(0, path.length()-4).to_lower() +".png")
