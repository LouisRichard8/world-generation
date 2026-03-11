class_name ChunkGenerator

var world_data: WorldData

func _init(data: WorldData) -> void:
	world_data = data

func generate_chunk(chunk_data: ChunkData, lod_level: int, callback: Callable) -> void:
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	generate_data(surface_tool, chunk_data, lod_level)
	
	callback.call_deferred(surface_tool)

func generate_data(surface_tool: SurfaceTool, chunk_data: ChunkData, lod_level: int) -> void:
	var chunk_size := chunk_data.chunk_size
	var chunk_res := chunk_data.chunk_res
	var chunk_pos := chunk_data.chunk_pos
	var size: int = chunk_res+2
	
	if !chunk_data.vertexes_generated:
		var stepBetweenPoint: float = (1.0/(float(chunk_res+2)/chunk_size))
		for x in range(chunk_res+5): 
			for z in range(chunk_res+5):
				var real_x: float = x*stepBetweenPoint - stepBetweenPoint
				var real_z: float = z*stepBetweenPoint - stepBetweenPoint
				var index: int = x*(chunk_res+5)+z
				
				chunk_data.colors[index] = get_biome(real_x+chunk_pos.x, real_z+chunk_pos.z)
				
				var height: float = get_height(real_x+chunk_pos.x, real_z+chunk_pos.z)
					
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
			
			if x > 1 and z > 1:
				#if Vector3.UP.dot(chunk_data.normals[x*(size+3)+z]) > 0.8 and x%2 == 0 and z%2 == 0 and chunk_data.vertexes[x*(size+3)+z].y > world_data.water_level+5.0:
					#var tree = tree_scn.instantiate()
					#tree.position = vertexes[x*(size+3)+z] + Vector3(randf_range(0.0,0.7), 0.0, randf_range(0.0,0.7))
					#vegetation.call_deferred("add_child", tree)
				
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

func get_height(x: float, z: float) -> float:
	var height := 0.0
	
	height += world_data.curve_continentalness.sample(world_data.continentalness.noise.get_noise_2d(x, z))
	height += world_data.curve_erosion.sample(world_data.erosion.noise.get_noise_2d(x, z))
	height += world_data.curve_pv.sample(world_data.pv.noise.get_noise_2d(x, z))
	height/=3.0
	
	height*=200.0
	
	return height
	
func get_biome(x: float, z: float) -> Color:
	var color: Vector3 = Vector3.ZERO
	var temp := (world_data.temperature.noise.get_noise_2d(x, z)+1.0)/2.0
	var hum := (world_data.humidity.noise.get_noise_2d(x, z)+1.0)/2.0
	
	var biomesMatch: Dictionary[Biome, float] = {}
	var minMatch := pow(3, 10.0)
	var maxMatch := 0.0
	
	for biome in world_data.biomes:
		var biomeMatch := biome.evaluate(temp, hum)
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

func generate_grass(chunk_data: ChunkData) -> void:
	var chunk_size := chunk_data.chunk_size
	var chunk_res := chunk_data.chunk_res
	var size: int = chunk_res+2
	
	var stepBetweenPoint: float = (1.0/(float(chunk_res+2)/chunk_size))
	var stepGrass: float = stepBetweenPoint/world_data.grass_density
	
	chunk_data.grass.instance_count = (world_data.grass_density**2)*(size**2)
	var grass_index = 0
	
	for x in range(3, chunk_res+5): 
		for z in range(3, chunk_res+5):
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
			for i in range(world_data.grass_density):
				for j in range(world_data.grass_density):
					var pos: Vector3 = chunk_data.vertexes[indexA]
					var normal: Vector3 = chunk_data.normals[indexA]
					
					var x_percent := float(i+stepGrass/2.0)/float(world_data.grass_density)
					var z_percent := float(j+stepGrass/2.0)/float(world_data.grass_density)
					
					if j >= i:
						pos += AB_vert*x_percent + BD_vert*z_percent
						normal += AB_norm*x_percent + BD_norm*z_percent
					else:
						pos += CD_vert*x_percent + AC_vert*z_percent
						normal += CD_norm*x_percent + AC_norm*z_percent
					
					if Vector3.UP.dot(normal.normalized()) > 0.8 and pos.y > world_data.water_level+5.0:
						var transform: Transform3D = Transform3D(Basis() * Basis(Vector3.UP, randf_range(0, 2*PI)), pos)
						chunk_data.grass.set_instance_transform(grass_index, transform)
						grass_index+=1
						
	chunk_data.grass.visible_instance_count = grass_index
