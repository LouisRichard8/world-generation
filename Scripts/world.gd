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

func load_chunks(player_chunk: Vector3) -> void:
	for x in range(int(player_chunk.x) - view_distance, int(player_chunk.x) + view_distance+1):
		for z in range(int(player_chunk.z) - view_distance, int(player_chunk.z) + view_distance+1):
			var chunk_pos := Vector3(x,0,z)
			var chunk_dist := chunk_pos.distance_to(player_chunk)
			var lod := int(chunk_dist/lod_level_chunk)
			if chunk_dist > view_distance:
				continue
			if chunks.has(chunk_pos):
				var chunk := chunks[chunk_pos]
				if lod != chunk.lod_level:
					chunk.update_lod(lod)
				elif !check_out_view(chunk_pos):
					toggle_load_chunk(chunk, true)
			else:
				var chunk := chunck_generator.new_chunk(chunk_pos, chunk_size, lod, chunk_res)
				self.add_child(chunk)
				chunks[chunk_pos] = chunk

func unload_chunks(player_chunk: Vector3) -> void:
	for chunk: Vector3 in chunks.keys():
		var chunk_distance := chunk.distance_to(player_chunk)
		if chunk_distance > view_distance:
			erase_chunk(chunk)
		elif check_out_view(chunk):
			toggle_load_chunk(chunks[chunk], false)

func check_out_view(chunk_pos: Vector3) -> bool:
	return chunk_pos.distance_to(last_player_pos) > 1.5 and player.player_dir.dot((chunk_pos-last_player_pos).normalized()) <= -0.5

func toggle_load_chunk(chunk: Chunk, loaded: bool) -> void:
	chunk.visible = loaded
	#chunk.process_mode = Node.PROCESS_MODE_INHERIT if loaded else Node.PROCESS_MODE_DISABLED

func erase_chunk(chunk_pos: Vector3) -> void:
	var chunk_inst := chunks[chunk_pos]
	chunk_inst.thread_canceled = true

	remove_child(chunk_inst)
	chunk_inst.queue_free()
	chunks.erase(chunk_pos)
