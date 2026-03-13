extends Resource
class_name WorldData

@export var temperature: NoiseTexture2D
@export var humidity: NoiseTexture2D
@export var biomes: Array[Biome] = []

@export var water_level: float = 50.0 

@export_group("Continentalness")
@export var continentalness: NoiseTexture2D
@export var curve_continentalness: Curve

@export_group("Erosion")
@export var erosion: NoiseTexture2D
@export var curve_erosion: Curve

@export_group("Peaks & Valleys")
@export var pv: NoiseTexture2D
@export var curve_pv: Curve

@export_group("Vegetation")
@export var generate_grass: bool = true
@export var grass_density: int = 5
@export var grass_noise: NoiseTexture2D
