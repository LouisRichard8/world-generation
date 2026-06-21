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
@export var generate_vegetation: bool = true
@export_subgroup("Grass")
@export var generate_grass: bool = true
@export var grass_visibility_distance: int = 3
@export var grass_density: int = 5
@export var grass_repartition: NoiseTexture2D
@export var grass: Dictionary[ChunkGenerator.GrassType, Mesh]

@export_subgroup("Tree")
@export var generate_tree: bool = true
@export var tree_visibility_distance: int = 5
@export var tree_repartition: NoiseTexture2D
@export var tree: Dictionary[ChunkGenerator.TreeType, Mesh]
