extends Node3D
class_name World

@onready var player := get_tree().get_first_node_in_group("Player")

@export var chunk_size: int = 16
@export var view_distance: int = 10
@export var lod_level_chunk: int = 1
@export_range(2.0, 64.0, 2.0) var chunk_res: int = 16

@export var world_data: WorldData
static var chunck_generator: ChunkGenerator

var chunks: Dictionary[Vector3, Chunk] = {}
var last_player_pos: Vector3 = Vector3(1,1,1)

var thread_ids: Dictionary[Vector3, int] = {}

@onready var label: Label = $CharacterBody3D/Label

func _ready() -> void:
	chunck_generator = ChunkGenerator.new(world_data)

func _process(_delta: float) -> void:
	label.text = "FPS: %s" % [Engine.get_frames_per_second()]
	var player_chunk: Vector3 = (player.global_transform.origin / chunk_size).floor()
	player_chunk.y = 0.0
	last_player_pos = player_chunk
	$CharacterBody3D/Label3D.text = str(player_chunk)

	unload_chunks(player_chunk)
	load_chunks(player_chunk)

func _exit_tree() -> void:
	for id in thread_ids.values():
		WorkerThreadPool.wait_for_task_completion(id)

func load_chunks(player_chunk: Vector3) -> void:
	for x in range(int(player_chunk.x) - view_distance, int(player_chunk.x) + view_distance+1):
		for z in range(int(player_chunk.z) - view_distance, int(player_chunk.z) + view_distance+1):
			var chunk_pos = Vector3(x,0,z)
			var chunk_dist = chunk_pos.distance_to(player_chunk)
			var lod = int(chunk_dist/lod_level_chunk)
			if chunk_dist > view_distance:
				continue
			if chunks.has(chunk_pos):
				if lod != chunks[chunk_pos].lod_level:
					chunks[chunk_pos].update_lod(lod)
				elif !check_out_view(chunk_pos):
					toggle_load_chunk(chunks[chunk_pos], true)
			else:
				var chunk = Chunk.new_chunk(chunk_pos, chunk_size, lod, chunk_res)
				self.add_child(chunk)
				chunks[chunk_pos] = chunk
				#var callable = Callable(self, "generate_chunk").bind(chunk)
				#thread_ids[chunk_pos] = WorkerThreadPool.add_task(callable)

func unload_chunks(player_chunk: Vector3) -> void:
	for chunk in chunks.keys():
		var chunk_distance = chunk.distance_to(player_chunk)
		if chunk_distance > view_distance:
			erase_chunk(chunk)
		elif check_out_view(chunk):
			toggle_load_chunk(chunks[chunk], false)

func check_out_view(chunk_pos:Vector3) -> bool:
	return chunk_pos.distance_to(last_player_pos) > 1.5 and player.player_dir.dot((chunk_pos-last_player_pos).normalized()) <= -0.5

func toggle_load_chunk(chunk: Chunk, loaded: bool):
	chunk.visible = loaded
	#chunk.process_mode = Node.PROCESS_MODE_INHERIT if loaded else Node.PROCESS_MODE_DISABLED

func erase_chunk(chunk_pos: Vector3) -> void:
	var chunk_inst = chunks[chunk_pos]
	chunk_inst.thread_canceled = true
	if thread_ids.has(chunk_pos):
		WorkerThreadPool.wait_for_task_completion(thread_ids[chunk_pos])
		thread_ids.erase(chunk_pos)
	remove_child(chunk_inst)
	chunk_inst.queue_free()
	chunks.erase(chunk_pos)
	
func generate_chunk(chunk: Chunk):
	var chunk_pos = chunk.chunk_pos
	var heightmap: Array[float] = []
	var vertexes: Array[Vector3] = []
	var colors: Array[Color] = []
	
	heightmap.resize((chunk_res+5)**2) 
	vertexes.resize((chunk_res+5)**2) 
	colors.resize((chunk_res+5)**2)
	
	var size = chunk_res+2
	var total_vertex = size+3
	var step = 1.0/(float(size)/float(chunk_size))
	for x in range(total_vertex):
		for z in range(total_vertex):
			if chunk.thread_canceled:
				return
			var real_x = x*step + chunk_pos.x-step
			var real_z = z*step + chunk_pos.z-step
			
			colors[x*total_vertex+z] = get_biome(real_x, real_z)
			
			var height = get_height(real_x,real_z)
			heightmap[x*total_vertex+z] = height
			vertexes[x*total_vertex+z] = Vector3(real_x, height, real_z)
	
	var chunk_data = ChunkData.new()
	chunk_data.heightmap = heightmap
	chunk_data.vertexes = vertexes
	chunk_data.colors = colors
	chunk.set_data(chunk_data)

func get_height(x: float, z: float) -> float:
	var height = 0.0
	
	height += world_data.curve_continentalness.sample(world_data.continentalness.noise.get_noise_2d(x, z))
	height += world_data.curve_erosion.sample(world_data.erosion.noise.get_noise_2d(x, z))
	height += world_data.curve_pv.sample(world_data.pv.noise.get_noise_2d(x, z))
	height/=3.0
	
	height*=200.0
	
	return height

func get_biome(x: float, z: float) -> Color:
	var color: Vector3 = Vector3.ZERO
	var temp = (world_data.temperature.noise.get_noise_2d(x, z)+1.0)/2.0
	var hum = (world_data.humidity.noise.get_noise_2d(x, z)+1.0)/2.0
	
	var biomesMatch: Dictionary[Biome, float] = {}
	var minMatch = pow(3, 10.0)
	var maxMatch = 0.0
	
	for biome in world_data.biomes:
		var biomeMatch = biome.evaluate(temp, hum)
		biomeMatch = 1 / (biomeMatch + 0.001)
		biomeMatch = pow(biomeMatch+1, 10.0)
		minMatch = min(minMatch, biomeMatch)
		maxMatch = max(maxMatch, biomeMatch)
		biomesMatch[biome] = biomeMatch
	
	for biome in biomesMatch:
		var biomeMatch = (biomesMatch[biome]-minMatch)/maxMatch
		color += Vector3(biome.color.r, biome.color.g, biome.color.b)*biomeMatch
	
	color = color.normalized()
	
	return Color(color.x, color.y, color.z, 1.0)
