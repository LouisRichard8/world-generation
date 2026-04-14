extends Node3D
class_name VegetationManager

@onready var grass_node: Node3D = $Grass
@onready var trees_node: Node3D = $Trees

var chunk_data: ChunkData
var visibility_range: int = 1

var vegetation_data: VegetationData = VegetationData.new()

var thread_id: int = 0

func _exit_tree() -> void:
	if thread_id != 0 and !WorkerThreadPool.is_task_completed(thread_id):
		WorkerThreadPool.wait_for_task_completion(thread_id)

func generate_vegetation() -> void:
	if !vegetation_data.generated and thread_id == 0:
		var thread: Callable = World.chunck_generator.generate_grass
		thread = thread.bind(chunk_data, vegetation_data, add_vegetation)
		thread_id = WorkerThreadPool.add_task(thread)

func add_vegetation() -> void:
	for tree_m: MultiMeshInstance3D in vegetation_data.trees:
		trees_node.add_child(tree_m)
	
	for grass_m: MultiMeshInstance3D in vegetation_data.grass:
		grass_node.add_child(grass_m)
