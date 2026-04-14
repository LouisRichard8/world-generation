class_name NoiseData

var temperature: float
var humidity: float
var continentalness: float
var erosion: float
var pv: float

func _init(world_data: WorldData, x: float, z: float) -> void:
	temperature = world_data.temperature.noise.get_noise_2d(x, z)
	humidity = world_data.humidity.noise.get_noise_2d(x, z)
	continentalness = world_data.curve_continentalness.sample(world_data.continentalness.noise.get_noise_2d(x, z))
	erosion = world_data.curve_erosion.sample(world_data.erosion.noise.get_noise_2d(x, z))
	pv = world_data.curve_pv.sample(world_data.pv.noise.get_noise_2d(x, z))
