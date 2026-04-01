@tool
extends Node3D

@export var shadows: bool = true
@export var time_flow: bool = true
@export_range(0.0, 1.0, 0.0001) var time: float = 0.0
@export var day_length: float = 20
var time_rate: float

@onready var world_environment: WorldEnvironment = $WorldEnvironment
@export var sky_top_color: Gradient
@export var sky_horizon_color: Gradient

@onready var sun: DirectionalLight3D = $WorldEnvironment/Sun
@export_range(0.1, 10.0, 0.1) var sun_radius: float = 2.0
@export var sun_color: Gradient
@export var sun_intensity: Curve

@onready var moon: DirectionalLight3D = $WorldEnvironment/Moon
@export_range(0.1, 10.0, 0.1) var moon_radius: float = 1.0
@export var moon_color: Gradient
@export var moon_intensity: Curve

func _ready() -> void:
	time_rate = 1.0/day_length

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if time_flow:
		time += delta*time_rate
		
		if time >= 1.0:
			time = 0.0
			
		world_environment.environment.sky.sky_material.set("shader_parameter/day_time", time >= 0.25 and time <= 0.75)
		
	# sun
	sun.shadow_enabled = shadows
	sun.rotation_degrees.x = time*360.0+90.0
	sun.light_color = sun_color.sample(time)
	sun.light_energy = sun_intensity.sample(time)
	sun.visible = sun.light_energy > 0
	world_environment.environment.sky.sky_material.set("shader_parameter/sun_radius", sun_radius)
	world_environment.environment.sky.sky_material.set("shader_parameter/sun_color", sun_color.sample(time))
	
	# moon
	moon.shadow_enabled = shadows
	moon.rotation_degrees.x = time*360.0-90.0
	moon.light_color = moon_color.sample(time)
	moon.light_energy = moon_intensity.sample(time)
	moon.visible = moon.light_energy > 0
	world_environment.environment.sky.sky_material.set("shader_parameter/moon_radius", moon_radius)
	world_environment.environment.sky.sky_material.set("shader_parameter/moon_color", Vector4(0.8,0.8,0.8,1.0))

	world_environment.environment.sky.sky_material.set("shader_parameter/sky_top_color", sky_top_color.sample(time))
	world_environment.environment.sky.sky_material.set("shader_parameter/sky_horizon_color", sky_horizon_color.sample(time))
	world_environment.environment.sky.sky_material.set("shader_parameter/ground_bottom_color", sky_top_color.sample(time))
	world_environment.environment.sky.sky_material.set("shader_parameter/ground_horizon_color", sky_horizon_color.sample(time))
