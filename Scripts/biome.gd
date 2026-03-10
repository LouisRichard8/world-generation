extends Resource
class_name Biome

@export var color: Color

@export var temperature: float
@export var humidity: float

func evaluate(temp: float, hum: float) -> float:
	var temperatureMatch = abs(temperature-temp)
	var humidityMatch = abs(humidity-hum)
	
	return temperatureMatch + humidityMatch
