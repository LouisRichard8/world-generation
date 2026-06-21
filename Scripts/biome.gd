extends Resource
class_name Biome

@export var color: Color

@export var temperature: float
@export var humidity: float
@export var continentalness: float
@export var erosion: float

@export var grass_type: Dictionary[ChunkGenerator.GrassType, float]
@export var trees_type: Dictionary[ChunkGenerator.TreeType, float]

func evaluate(noise_data: NoiseData) -> float:
	var temperature_match: float = abs(temperature-(noise_data.temperature+1.0)/2.0)
	var humidity_match: float = abs(humidity-(noise_data.humidity+1.0)/2.0)
	var continentalness_match: float = abs(continentalness-(noise_data.continentalness+1.0)/2.0)
	var erosion_match: float = abs(erosion-(noise_data.erosion+1.0)/2.0)
	
	return temperature_match + humidity_match + continentalness_match*5.0 + erosion_match
