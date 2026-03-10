extends CharacterBody3D

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var speed = 64.0
var defaultSpeed = 4.0
var sprintSpeed = 25.0
var jump_speed = 11.0
var mouse_sensitivity = 0.002
var actionPressed = false

var fly_mode: bool = true
var player_dir: Vector3 = Vector3(1.0,0.0,0.0)

@onready var camera_3d: Camera3D = $Camera3D

func _ready():
	player_dir = Vector3(-sin(rotation.y), 0.0, -cos(rotation.y)).normalized()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func get_input():
	var input = Input.get_vector("left", "right", "forward", "back")
	var movement_dir = transform.basis * Vector3(input.x, 0, input.y)
	velocity.x = movement_dir.x * speed
	velocity.z = movement_dir.z * speed

func _physics_process(delta):
	if !fly_mode:
		velocity.y += -gravity * delta
	get_input()
	move_and_slide()

func _unhandled_input(event):
	#if event.is_action_pressed("sprint"):
	#	speed = sprintSpeed
	#if event.is_action_released("sprint"):
	#	speed = defaultSpeed
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera_3d.rotate_x(-event.relative.y * mouse_sensitivity)
		camera_3d.rotation.x = clampf(camera_3d.rotation.x, -deg_to_rad(70), deg_to_rad(70))
		player_dir = Vector3(-sin(rotation.y), 0.0, -cos(rotation.y)).normalized()
	if event.is_action_pressed("up") and is_on_floor() and fly_mode == false:
		velocity.y = jump_speed
	if event.is_action_pressed("up") and fly_mode == true:
		velocity.y = speed
	if event.is_action_pressed("fly"):
		fly_mode=!fly_mode
	if event.is_action_released("up"):
		velocity.y = 0
	if event.is_action_pressed("down"):
		velocity.y = -speed
	if event.is_action_released("down"):
		velocity.y = 0
	if event.is_action_pressed("exit"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
