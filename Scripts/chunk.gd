extends Node3D
class_name Chunk

const chunk_scn = preload("res://Scenes/chunk.tscn")
const tree_scn = preload("res://Scenes/tree.tscn")

@onready var label_3d: Label3D = $Label3D
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var water: MeshInstance3D = $Water
@onready var vegetation: Node3D = $Vegetation
@onready var grass: MultiMeshInstance3D = $Grass

var lod_level: int = 1 
var chunk_pos: Vector3
var chunk_size: float = 0
var chunk_res: int

var chunk_data: ChunkData = ChunkData.new()

var contain_water: bool = false
var loaded: bool = false

var meshes: Dictionary[int, Mesh] = {}
var shapes: Dictionary[int, Shape3D] = {}

var heightmap: Array[float] = []
var vertexes: Array[Vector3] = []
var normals: Array[Vector3] = []
var colors: Array[Color] = []

var elevation: Noise
var temperature: Noise
var humidity: Noise

var thread_canceled: bool = false
var thread_id: int = 0

static func new_chunk(pos: Vector3, size: int, level: int, res: int) -> Chunk:
	var chunk = chunk_scn.instantiate()
	chunk.chunk_size = size
	chunk.chunk_pos = pos*size
	chunk.lod_level = level
	chunk.chunk_res = res
	chunk.chunk_data.set_data(pos*size, size, res)
	return chunk

func _ready() -> void:
	label_3d.global_position = chunk_pos+Vector3(8,0,8)
	label_3d.text = str(chunk_pos/chunk_size)
	
	vertexes.resize((chunk_res+5)**2)
	normals.resize((chunk_res+5)**2)
	
	position = chunk_pos + Vector3(chunk_size/2.0, 0.0, chunk_size/2.0)
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = preload("res://Resources/test.tres")
	
	grass.multimesh = multimesh
	chunk_data.grass = grass.multimesh
	
	var thread: Callable = World.chunck_generator.generate_chunk
	thread = thread.bind(chunk_data, lod_level, self.generate_mesh)
	thread_id = WorkerThreadPool.add_task(thread)
	
func _process(_delta: float) -> void:
	if(thread_id == 0 and !heightmap.is_empty()):
		thread_id = WorkerThreadPool.add_task(generate_chunk)

func _exit_tree() -> void:
	wait_for_thread()

func update_lod(lod: int):
	wait_for_thread()
	lod_level = lod
	
	grass.visible = lod_level == 0
		
	if meshes.has(lod_level):
		mesh.mesh = meshes[lod_level]
		collision_shape.shape = shapes[lod_level]
	else:
		var thread: Callable = World.chunck_generator.generate_chunk
		thread = thread.bind(chunk_data, lod_level, self.generate_mesh)
		thread_id = WorkerThreadPool.add_task(thread)
		#thread_id = WorkerThreadPool.add_task(generate_chunk)

func wait_for_thread():
	if thread_id != 0:
		WorkerThreadPool.wait_for_task_completion(thread_id)
		thread_id = 0

func set_data(datas: ChunkData):
	heightmap = datas.heightmap
	colors = datas.colors

func generate_chunk():
	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	if thread_canceled:
		return
	generate_points(surface_tool)
	call_deferred("generate_mesh", surface_tool)
	
func generate_mesh(surface_tool: SurfaceTool):
	if chunk_data.contain_water:
		generate_water()
	var newmesh = ArrayMesh.new()
	newmesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_tool.commit_to_arrays())
	meshes[lod_level] = newmesh
	
	var shape = ConcavePolygonShape3D.new()
	shape.set_faces(surface_tool.commit_to_arrays()[Mesh.ARRAY_VERTEX])
	shapes[lod_level] = shape
	
	update_lod(lod_level)
	loaded = true

func generate_points(surface_tool: SurfaceTool):
	if vertexes[0] == Vector3.ZERO:
		var stepBetweenPoint: float = (1.0/(float(chunk_res+2)/chunk_size))
		for x in range(chunk_res+5): 
			for z in range(chunk_res+5):
				if thread_canceled:
					return
				var real_x = x*stepBetweenPoint - stepBetweenPoint
				var real_z = z*stepBetweenPoint - stepBetweenPoint
				
				var height = heightmap[x*(chunk_res+5)+z]
					
				if height < 50.0:
					contain_water = true
				
				vertexes[x*(chunk_res+5)+z] = Vector3(real_x, height, real_z)
				
				if x > 0 and z > 0:
					calculate_normal(x, z)

	var size: int = chunk_res+2
	var quadNumber: int = max(chunk_res/pow(2,lod_level),4.0)
	var step = roundi(float(chunk_res)/quadNumber)
	
	for x in range(1, size+2):
		for z in range(1, size+2):
			if thread_canceled:
				return
			
			if x > 1 and z > 1:
				#if Vector3.UP.dot(normals[x*(size+3)+z].normalized()) > 0.98 and x%2 == 0 and z%2 == 0 and vertexes[x*(size+3)+z].y > 70.0:
					#var tree = tree_scn.instantiate()
					#tree.position = vertexes[x*(size+3)+z] + Vector3(randf_range(0.0,0.7), 0.0, randf_range(0.0,0.7))
					#vegetation.call_deferred("add_child", tree)
				
				var xQuad = x-2
				var zQuad = z-2
				var isMainVertex: bool = (xQuad % step == 0 and zQuad % step == 0) and (x > 1 or x < size + 1 or z > 1 or z < size + 1)
				var isExternalVertex: bool = x < 3 or x > size or z < 3 or z > size
				
				var jump: int = step if (isMainVertex and x > 2 and z > 2) else 1
				
				if step != 1 and !isMainVertex and x < size + 1 and z < size +1:
					if x == 2 or x == size:
						var vertexA: float = vertexes[x*(size+3)+z-zQuad%step].y
						var vertexB: float = vertexes[x*(size+3)+z+step-zQuad%step].y
						var vertexAPercent := float(step-zQuad%step) / float(step)
						var vertexBPercent := float(zQuad%step) / float(step)
						
						vertexes[x*(size+3)+z].y = vertexA*vertexAPercent + vertexB*vertexBPercent
						
					elif z == 2 or z == size:
						var vertexA:float = vertexes[(x-xQuad%step)*(size+3)+z].y
						var vertexB:float = vertexes[(x+step-xQuad%step)*(size+3)+z].y
						var vertexAPercent := float(step-xQuad%step) / float(step)
						var vertexBPercent := float(xQuad%step) / float(step)
						
						vertexes[x*(size+3)+z].y = vertexA*vertexAPercent + vertexB*vertexBPercent
				
				if (isMainVertex or isExternalVertex):
					var indexA = (x-jump)*(size+3)+z-jump
					var indexB = (x-jump)*(size+3)+z
					var indexC = (x)*(size+3)+z-jump
					var indexD = (x)*(size+3)+z
					
					add_vertex(surface_tool, indexD)
					add_vertex(surface_tool, indexB)
					add_vertex(surface_tool, indexA)
					add_vertex(surface_tool, indexA)
					add_vertex(surface_tool, indexC)
					add_vertex(surface_tool, indexD)

func add_vertex(surface_tool: SurfaceTool, index: int):
	surface_tool.set_normal(normals[index].normalized())
	surface_tool.set_color(colors[index])
	surface_tool.add_vertex(vertexes[index])

func calculate_normal(x: float, z: float):
	var indexA = (x-1)*(chunk_res+5)+z-1
	var indexB = (x-1)*(chunk_res+5)+z
	var indexC = (x)*(chunk_res+5)+z-1
	var indexD = (x)*(chunk_res+5)+z
	
	var normalA = calculate_triangle_normal(vertexes[indexA], vertexes[indexB], vertexes[indexD])
	var normalB = calculate_triangle_normal(vertexes[indexD], vertexes[indexC], vertexes[indexA])
	
	normals[indexA] += normalA + normalB
	normals[indexB] += normalA
	normals[indexC] += normalB
	normals[indexD] += normalA + normalB
	
func get_normal(size: float, x: float, z: float) -> Vector3:
	var vertex = vertexes[x*(size+3)+z]
		
	var adj_vertexes: Array[Vector3] = []
	adj_vertexes.append(vertexes[(x-1)*(size+3)+(z-1)])
	adj_vertexes.append(vertexes[(x-1)*(size+3)+(z)])
	adj_vertexes.append(vertexes[(x-1)*(size+3)+(z+1)])
	adj_vertexes.append(vertexes[(x)*(size+3)+(z-1)])
	adj_vertexes.append(vertexes[(x)*(size+3)+(z+1)])
	adj_vertexes.append(vertexes[(x+1)*(size+3)+(z-1)])
	adj_vertexes.append(vertexes[(x+1)*(size+3)+(z)])
	adj_vertexes.append(vertexes[(x+1)*(size+3)+(z+1)])
	
	return calculate_vertex_normal(adj_vertexes, vertex)
	
func calculate_vertex_normal(adj_vertex: Array[Vector3], vertex: Vector3) -> Vector3:
	var normal: Vector3 = Vector3.ZERO
				
	normal+=calculate_triangle_normal(vertex, adj_vertex[0], adj_vertex[1])
	normal+=calculate_triangle_normal(vertex, adj_vertex[1], adj_vertex[2])
	normal+=calculate_triangle_normal(vertex, adj_vertex[2], adj_vertex[4])
	normal+=calculate_triangle_normal(vertex, adj_vertex[4], adj_vertex[7])
	normal+=calculate_triangle_normal(vertex, adj_vertex[7], adj_vertex[6])
	normal+=calculate_triangle_normal(vertex, adj_vertex[6], adj_vertex[5])
	normal+=calculate_triangle_normal(vertex, adj_vertex[5], adj_vertex[3])
	normal+=calculate_triangle_normal(vertex, adj_vertex[3], adj_vertex[0])
	
	return normal.normalized()

func calculate_triangle_normal(A: Vector3, B: Vector3, C: Vector3) -> Vector3:
	var AB = B - A
	var AC = C - A
	return AB.cross(AC).normalized()
	
func get_height(index: int) -> float:
	return heightmap[index]

func generate_water():
	water.scale=Vector3.ONE*chunk_size
	water.position = Vector3(chunk_size/2, 50.0, chunk_size/2)
	water.visible = true
	water.process_mode = Node.PROCESS_MODE_INHERIT
