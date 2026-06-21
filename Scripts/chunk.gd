extends Node3D
class_name Chunk

@onready var label_3d: Label3D = $Label3D
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var water: MeshInstance3D = $Water
@onready var vegetation: VegetationManager = $Vegetation

@export var lod_level: int = 0 
@export var chunk_pos: Vector3
@export var chunk_size: int
@export var chunk_res: int

var chunk_data: ChunkData = ChunkData.new()

var contain_water: bool = false
var loaded: bool = false

var pendding_task: Array[Callable] = []

var meshes: Dictionary[int, Mesh] = {}
var shapes: Dictionary[int, Shape3D] = {}

var thread_canceled: bool = false
var thread_id: int = 0
var grass_thread_id: int = 0

func _ready() -> void:
	label_3d.global_position += Vector3(chunk_size/2.0, 0.0, chunk_size/2.0)
	label_3d.text = str(chunk_pos/chunk_size)
	
	position = chunk_pos - Vector3(chunk_size/2.0, 0.0, chunk_size/2.0)
	
	vegetation.chunk_data = chunk_data
	
	var thread: Callable = World.chunck_generator.generate_chunk
	thread = thread.bind(chunk_data, lod_level, self.generate_mesh)
	thread_id = WorkerThreadPool.add_task(thread)

func _exit_tree() -> void:
	if !chunk_data.generation_canceled:
		wait_for_thread()
		if grass_thread_id != 0 and !WorkerThreadPool.is_task_completed(grass_thread_id):
			WorkerThreadPool.wait_for_task_completion(grass_thread_id)

func update_lod(lod: int) -> void:
	if meshes.has(lod):
		mesh.mesh = meshes[lod]
		collision_shape.shape = shapes[lod]
	else:
		var thread: Callable = World.chunck_generator.generate_chunk
		thread = thread.bind(chunk_data, lod, self.generate_mesh)
		pendding_task.append(thread)
		
	lod_level = lod
	
	if thread_id == 0 and !pendding_task.is_empty():
		thread_id = WorkerThreadPool.add_task(pendding_task.pop_front())

func wait_for_thread() -> void:
	if thread_id != 0:
		WorkerThreadPool.wait_for_task_completion(thread_id)
		thread_id = 0

func wait_for_vegetation_thread() -> void:
	if grass_thread_id != 0 and !WorkerThreadPool.is_task_completed(grass_thread_id):
		WorkerThreadPool.wait_for_task_completion(grass_thread_id)
#	
func remove_chunk() -> void:
	chunk_data.generation_canceled = true
	chunk_unloader.unload_chunk(self)

func generate_mesh(surface_tool: SurfaceTool) -> void:
	if chunk_data.contain_water:
		generate_water()
	var newmesh: ArrayMesh = surface_tool.commit()
	meshes[lod_level] = newmesh
	
	var shape: Shape3D = ConcavePolygonShape3D.new()
	shape.set_faces(surface_tool.commit_to_arrays()[Mesh.ARRAY_VERTEX])
	shapes[lod_level] = shape
	
	update_lod(lod_level)
	
	if lod_level < 2 and World.chunck_generator.world_data.generate_vegetation:
		vegetation.generate_vegetation()
	
	thread_id = 0
	loaded = true

func generate_water() -> void:
	water.scale = Vector3.ONE*chunk_size
	water.position = Vector3(float(chunk_size)/2.0, 50.0, float(chunk_size)/2.0)
	water.visible = true
	water.process_mode = Node.PROCESS_MODE_INHERIT
