extends Resource
class_name Biome

@export var color: Color

@export var temperature: float
@export var humidity: float
@export var continentalness: float
@export var erosion: float

@export var grass_type: Dictionary[ChunkGenerator.GrassType, float]

func evaluate(noise_data: NoiseData) -> float:
	var temperature_match: float = abs(temperature-(noise_data.temperature+1.0)/2.0)
	var humidity_match: float = abs(humidity-(noise_data.humidity+1.0)/2.0)
	var continentalness_match: float = abs(continentalness-noise_data.continentalness)
	var erosion_match: float = abs(erosion-noise_data.erosion)
	
	return temperature_match*2.0 + humidity_match*2.0 + continentalness_match + erosion_match
