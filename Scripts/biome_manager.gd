extends Resource
class_name BiomeManager

@export var biomes: Array[Biome] = []

func get_biome(noise_data: NoiseData) -> int:
	var biome_id: int = -1
	var maxMatch := 0.0
	
	for i in range(biomes.size()):
		var biome = biomes[i]
		var biomeMatch := biome.evaluate(noise_data)
		biomeMatch = 1 / (biomeMatch + 0.001)
		if biomeMatch > maxMatch:
			maxMatch = biomeMatch
			biome_id = i
	
	return biome_id
