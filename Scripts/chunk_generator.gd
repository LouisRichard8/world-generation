class_name ChunkGenerator

enum GrassType{
	NONE,
	GRASS,
	GRASS_RED_BUSH
}

enum TreeType{
	NONE,
	BIRCH,
	OAK,
	PINE
}

const chunk_scn: Resource = preload("res://Scenes/chunk.tscn")

var world_data: WorldData

func _init(data: WorldData) -> void:
	world_data = data

func new_chunk(pos: Vector3, size: int, level: int, res: int) -> Chunk:
	var chunk: Chunk = chunk_scn.instantiate()
	chunk.chunk_size = size
	chunk.chunk_pos = pos*size
	chunk.lod_level = level
	chunk.chunk_res = res
	chunk.chunk_data.set_data(pos*size, size, res)
	return chunk

func generate_chunk(chunk_data: ChunkData, lod_level: int, callback: Callable) -> void:
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	generate_data(surface_tool, chunk_data, lod_level)
	if chunk_data.generation_canceled:
		print("cancel chunk")
		return
	callback.call_deferred(surface_tool)

func generate_data(surface_tool: SurfaceTool, chunk_data: ChunkData, lod_level: int) -> void:
	var chunk_size := chunk_data.chunk_size
	var chunk_res := chunk_data.chunk_res
	var chunk_pos := chunk_data.chunk_pos
	var size: int = chunk_res+2
	
	if !chunk_data.vertexes_generated:
		chunk_data.vertexes.resize((chunk_res+5)**2)
		chunk_data.normals.resize((chunk_res+5)**2)
		chunk_data.colors.resize((chunk_res+5)**2)
		
		var stepBetweenPoint: float = (1.0/(float(chunk_res+2)/chunk_size))
		
		for x in range(chunk_res+5): 
			for z in range(chunk_res+5):
				if chunk_data.generation_canceled:
					print("cancel vert")
					return
				var real_x: float = x*stepBetweenPoint - stepBetweenPoint
				var real_z: float = z*stepBetweenPoint - stepBetweenPoint
				var index: int = x*(chunk_res+5)+z
				
				var noise_data: NoiseData = NoiseData.new(world_data, (real_x+chunk_pos.x)/5.0, (real_z+chunk_pos.z)/5.0)
				
				chunk_data.colors[index] = get_biome(noise_data)
				
				var height: float = get_height(noise_data)
					
				if height < world_data.water_level:
					chunk_data.contain_water = true
				
				chunk_data.vertexes[index] = Vector3(real_x, height, real_z)
				
				if x > 0 and z > 0:
					calculate_normal(chunk_data, x, z)
		
		chunk_data.vertexes_generated = true

	var quadNumber: int = max(chunk_res/pow(2,lod_level),4.0)
	var step: int = roundi(float(chunk_res)/quadNumber)
	
	for x in range(1, size+2):
		for z in range(1, size+2):
			if chunk_data.generation_canceled:
				print("cancel face")
				return
			if x > 1 and z > 1:				
				var xQuad: int = x-2
				var zQuad: int = z-2
				var isMainVertex: bool = (xQuad % step == 0 and zQuad % step == 0) and (x > 1 or x < size + 1 or z > 1 or z < size + 1)
				var isExternalVertex: bool = x < 3 or x > size or z < 3 or z > size
				
				var jump: int = step if (isMainVertex and x > 2 and z > 2) else 1
				
				if step != 1 and !isMainVertex and x < size + 1 and z < size +1:
					if x == 2 or x == size:
						var vertexA: float = chunk_data.vertexes[x*(size+3)+z-zQuad%step].y
						var vertexB: float = chunk_data.vertexes[x*(size+3)+z+step-zQuad%step].y
						var vertexAPercent := float(step-zQuad%step) / float(step)
						var vertexBPercent := float(zQuad%step) / float(step)
						
						chunk_data.vertexes[x*(size+3)+z].y = vertexA*vertexAPercent + vertexB*vertexBPercent
						
					elif z == 2 or z == size:
						var vertexA: float = chunk_data.vertexes[(x-xQuad%step)*(size+3)+z].y
						var vertexB: float = chunk_data.vertexes[(x+step-xQuad%step)*(size+3)+z].y
						var vertexAPercent := float(step-xQuad%step) / float(step)
						var vertexBPercent := float(xQuad%step) / float(step)
						
						chunk_data.vertexes[x*(size+3)+z].y = vertexA*vertexAPercent + vertexB*vertexBPercent
				
				if (isMainVertex or isExternalVertex):
					var indexA := (x-jump)*(size+3)+z-jump
					var indexB := (x-jump)*(size+3)+z
					var indexC := (x)*(size+3)+z-jump
					var indexD := (x)*(size+3)+z
					
					add_vertex(surface_tool, chunk_data, indexD)
					add_vertex(surface_tool, chunk_data, indexB)
					add_vertex(surface_tool, chunk_data, indexA)
					add_vertex(surface_tool, chunk_data, indexA)
					add_vertex(surface_tool, chunk_data, indexC)
					add_vertex(surface_tool, chunk_data, indexD)

func add_vertex(surface_tool: SurfaceTool, chunk_data: ChunkData, index: int) -> void:
	surface_tool.set_normal(chunk_data.normals[index])
	surface_tool.set_color(chunk_data.colors[index])
	surface_tool.add_vertex(chunk_data.vertexes[index])

func calculate_normal(chunk_data: ChunkData, x: int, z: int) -> void:
	var chunk_res := chunk_data.chunk_res
	var indexA := (x-1)*(chunk_res+5)+z-1
	var indexB := (x-1)*(chunk_res+5)+z
	var indexC := (x)*(chunk_res+5)+z-1
	var indexD := (x)*(chunk_res+5)+z
	
	var normalA := calculate_triangle_normal(chunk_data.vertexes[indexA], chunk_data.vertexes[indexB], chunk_data.vertexes[indexD])
	var normalB := calculate_triangle_normal(chunk_data.vertexes[indexD], chunk_data.vertexes[indexC], chunk_data.vertexes[indexA])
	
	chunk_data.normals[indexA] += normalA + normalB
	chunk_data.normals[indexB] += normalA
	chunk_data.normals[indexC] += normalB
	chunk_data.normals[indexD] += normalA + normalB
	chunk_data.normals[indexA] = chunk_data.normals[indexA].normalized()

func calculate_triangle_normal(A: Vector3, B: Vector3, C: Vector3) -> Vector3:
	var AB := B - A
	var AC := C - A
	return AB.cross(AC).normalized()

func get_height(noise_data: NoiseData) -> float:
	var height := 0.0
	#return 60.0
	height += noise_data.continentalness
	height += noise_data.erosion
	height += noise_data.pv
	height/=3.0
	
	height*=200.0
	
	return height

func get_biome(noise_data: NoiseData) -> Color:
	var color: Vector3 = Vector3.ZERO
	
	var biomesMatch: Dictionary[Biome, float] = {}
	var minMatch := pow(3, 10.0)
	var maxMatch := 0.0
	
	for biome in world_data.biomes:
		var biomeMatch := biome.evaluate(noise_data)
		biomeMatch = 1 / (biomeMatch + 0.001)
		biomeMatch = pow(biomeMatch+1, 10.0)
		minMatch = min(minMatch, biomeMatch)
		maxMatch = max(maxMatch, biomeMatch)
		biomesMatch[biome] = biomeMatch
	
	for biome in biomesMatch:
		var biomeMatch := (biomesMatch[biome]-minMatch)/maxMatch
		color += Vector3(biome.color.r, biome.color.g, biome.color.b)*biomeMatch
	
	color = color.normalized()
	
	return Color(color.x, color.y, color.z, 1.0)

func generate_grass(chunk_data: ChunkData, vegetation_data: VegetationData, callback: Callable) -> void:
	var chunk_size := chunk_data.chunk_size
	
	if !vegetation_data.generated:
		var chunk_res := chunk_data.chunk_res
		
		var stepBetweenPoint: float = (1.0/(float(chunk_res+2)/chunk_size))
		var stepGrass: float = stepBetweenPoint/world_data.grass_density
		
		for x in range(3, chunk_res+5): 
			for z in range(3, chunk_res+5):
				if chunk_data.generation_canceled:
					return
				var indexA := (x-2)*(chunk_res+5)+z-2
				var indexB := (x-2)*(chunk_res+5)+z-1
				var indexC := (x-1)*(chunk_res+5)+z-2
				var indexD := (x-1)*(chunk_res+5)+z-1
				var AB_vert := chunk_data.vertexes[indexB]-chunk_data.vertexes[indexA]
				var BD_vert := chunk_data.vertexes[indexD]-chunk_data.vertexes[indexB]
				var CD_vert := chunk_data.vertexes[indexD]-chunk_data.vertexes[indexC]
				var AC_vert := chunk_data.vertexes[indexC]-chunk_data.vertexes[indexA]
				var AB_norm := chunk_data.normals[indexB]-chunk_data.normals[indexA]
				var BD_norm := chunk_data.normals[indexD]-chunk_data.normals[indexB]
				var CD_norm := chunk_data.normals[indexD]-chunk_data.normals[indexC]
				var AC_norm := chunk_data.normals[indexC]-chunk_data.normals[indexA]
				
				var biomeA := world_data.biome_manager.biomes[chunk_data.biomes[indexA]]
				var biomeB := world_data.biome_manager.biomes[chunk_data.biomes[indexB]]
				var biomeC := world_data.biome_manager.biomes[chunk_data.biomes[indexC]]
				var biomeD := world_data.biome_manager.biomes[chunk_data.biomes[indexD]]
				
				if world_data.generate_tree and x%2==0 and z%2==0:
					var vertex: Vector3 = chunk_data.vertexes[indexD]
					var normal: Vector3 = chunk_data.normals[indexD]
					var tree_type: TreeType = get_tree_type(biomeD, vertex.x+chunk_data.chunk_pos.x, vertex.z+chunk_data.chunk_pos.z)
					if tree_type != TreeType.NONE:
						if Vector3.UP.dot(normal.normalized()) > 0.8 and vertex.y > world_data.water_level+5.0:
							if !vegetation_data.trees_transforms.has(tree_type):
								vegetation_data.trees_transforms[tree_type] = []
							vegetation_data.trees_transforms[tree_type].append(get_transform(vertex, 5.0, 0.7, 1.0))
				
				if world_data.generate_grass:
					for i in range(world_data.grass_density):
						for j in range(world_data.grass_density):
							if chunk_data.generation_canceled:
								return
							var pos: Vector3 = chunk_data.vertexes[indexA]
							var normal: Vector3 = chunk_data.normals[indexA]
							
							var x_percent := float(i+stepGrass/2.0)/float(world_data.grass_density)
							var z_percent := float(j+stepGrass/2.0)/float(world_data.grass_density)
							
							var biome: Biome
							if x_percent < 0.5:
								if z_percent < 0.5:
									biome = biomeA
								else:
									biome = biomeC
							else:
								if z_percent < 0.5:
									biome = biomeB
								else:
									biome = biomeD
									
							if j >= i:
								pos += AB_vert*x_percent + BD_vert*z_percent
								normal += AB_norm*x_percent + BD_norm*z_percent
							else:
								pos += CD_vert*x_percent + AC_vert*z_percent
								normal += CD_norm*x_percent + AC_norm*z_percent
							
							var grass_type: GrassType = get_grass_type(biome, pos.x+chunk_data.chunk_pos.x, pos.z+chunk_data.chunk_pos.z)
							if grass_type != GrassType.NONE:
								if !vegetation_data.grass_transforms.has(grass_type):
									vegetation_data.grass_transforms[grass_type] = []
								if Vector3.UP.dot(normal.normalized()) > 0.8 and pos.y > world_data.water_level+5.0:
									vegetation_data.grass_transforms[grass_type].append(get_transform(pos, stepGrass, 0.3, 0.5)) 
		
		vegetation_data.generated = true

	for type: GrassType in vegetation_data.grass_transforms:
		var multimesh = create_multimesh(world_data.grass[type])
		var grass_array: Array = vegetation_data.grass_transforms[type]
		var size: int = grass_array.size()
		multimesh.instance_count = size
		for i in range(size):
			multimesh.set_instance_transform(i, grass_array[i])
		var multimesh_instance = MultiMeshInstance3D.new()
		multimesh_instance.multimesh = multimesh
		multimesh_instance.visibility_range_end = world_data.grass_visibility_distance*chunk_size
		vegetation_data.grass.append(multimesh_instance)
	
	for type: TreeType in vegetation_data.trees_transforms:
		var multimesh = create_multimesh(world_data.tree[type])
		var trees_array: Array = vegetation_data.trees_transforms[type]
		var size: int = trees_array.size()
		multimesh.instance_count = size
		for i in range(size):
			multimesh.set_instance_transform(i, trees_array[i])
		var multimesh_instance = MultiMeshInstance3D.new()
		multimesh_instance.multimesh = multimesh
		multimesh_instance.visibility_range_end = world_data.tree_visibility_distance*chunk_size
		vegetation_data.trees.append(multimesh_instance)
	
	
	callback.call_deferred()

func get_grass_type(biome:Biome, x: float, z: float) -> GrassType:
	var grass_type: GrassType = GrassType.NONE
	var grass_repartition: float = world_data.grass_repartition.noise.get_noise_2d(x,z)
	
	if grass_repartition > -0.5 and randf_range(-0.5, -0.3) < grass_repartition:
		var weirdness: float = randf_range(0.0, 1.0)
		for type in biome.grass_type:
			if 1.0 - biome.grass_type[type] < weirdness:
				grass_type = type
		
	return grass_type

func get_tree_type(biome: Biome, x: float, z: float) -> TreeType:
	var tree_type: TreeType = TreeType.NONE
	var tree_repartition: float = world_data.tree_repartition.noise.get_noise_2d(x,z)
	
	if tree_repartition > 0.0 and randf_range(0.0, 0.3) < tree_repartition:
		var weirdness: float = randf_range(0.0, 1.0)
		for type in biome.trees_type:
			if 1.0 - biome.trees_type[type] < weirdness:
				tree_type = type
		
	return tree_type

func get_transform(pos: Vector3, step: float, min_scale: float, max_scale: float) -> Transform3D:
	var scale: float = randf_range(min_scale, max_scale)
	var rotation: float = randf_range(0, 2*PI)
	pos += Vector3(randf_range(0.0, step)/2.0, 0.0, randf_range(0.0, step)/2.0)
	var transform: Transform3D = Transform3D(Basis(Vector3.UP, rotation).scaled(Vector3(scale,scale,scale)), pos)
	return transform	

func create_multimesh(mesh: Mesh) -> MultiMesh:
	var multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	
	return multimesh
