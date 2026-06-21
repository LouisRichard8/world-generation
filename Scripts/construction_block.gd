class_name ConstructionBlock

var block_id: String
var block_transform: Transform3D
var block: Node3D

var is_mirrored: bool = false

func _init(id: String, transform: Transform3D, preview: bool = false) -> void:
	block_id = id
	block_transform = transform
	if !preview:
		create_block()
	else:
		block = MeshInstance3D.new()
		block.transform = block_transform
		block.position -= Vector3(0.5, 0.0, 0.5)
		block.mesh = BuildManager.blocks[block_id]

func create_block():
	block = StaticBody3D.new()
	var instance = MeshInstance3D.new()
	instance.mesh = BuildManager.blocks[block_id]
	var collision = CollisionShape3D.new()
	collision.shape = ConcavePolygonShape3D.new()
	collision.shape.set_faces(instance.mesh.get_faces())
	block.transform = block_transform
	block.add_child(collision)
	block.add_child(instance)
	
func update_block():
	var mesh: MeshInstance3D = block.get_child(1)
	mesh.mesh = BuildManager.blocks[block_id]
	block.transform = block_transform

func rotate(clockwise: bool) -> void:
	block_transform = block_transform.rotated_local(Vector3.UP, PI/2.0 * (-1 if clockwise else 1))

func mirror(direction: Vector3) -> void:
	direction.y = 0.0
	block_transform = block_transform.scaled_local(Vector3(-1.0,1.0,-1.0)+direction*2)
	is_mirrored = !is_mirrored

func save():
	return {"block_id": block_id, "block_transform": JSON.from_native(block_transform, true)}

func delete() -> void:
	block.queue_free()
