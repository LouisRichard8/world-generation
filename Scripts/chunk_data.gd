class_name ChunkData

var chunk_pos: Vector3
var chunk_size: int
var chunk_res: int

var heightmap: Array[float]
var vertexes: Array[Vector3] = []
var normals: Array[Vector3] = []
var colors: Array[Color] = []

var grass: MultiMesh

var contain_water: bool = false
var vertexes_generated: bool = false

func set_data(pos: Vector3, size: int, res: int) -> void:
	chunk_pos = pos
	chunk_size = size
	chunk_res = res
	vertexes.resize((chunk_res+5)**2)
	normals.resize((chunk_res+5)**2)
	colors.resize((chunk_res+5)**2)
