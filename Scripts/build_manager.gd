extends Node3D
class_name BuildManager

@onready var mode: Label = $Control/Mode
@onready var save_structure_menu: VBoxContainer = $Control/SaveStructureMenu
@onready var save_structure_name: LineEdit = $Control/SaveStructureMenu/SaveStructureName
@onready var load_structure_menu: VBoxContainer = $Control/LoadStructureMenu
@onready var structure_list: ItemList = $Control/LoadStructureMenu/StructureList
@onready var build_blocks: TabContainer = $Control/BuildBlocks

var ray_cast_3d: RayCast3D = RayCast3D.new()

var build_mode: bool = false
var rotate_mode: bool = false

static var blocks: Dictionary[String, Mesh]
var selected_block: String
var selected_block_id: int = 0

var preview_manager: PreviewManager = PreviewManager.new()
var preview_visible: bool = false
var block_transform: Transform3D = Transform3D.IDENTITY

var placed_blocks: Dictionary[Vector3, ConstructionBlock]
var placing_block: bool = false
var breaking_block: bool = false
var structure_mode: bool = false
var delay_between_action: float = 0.2
var delay: float = 0.0

func _ready() -> void:
	var player: Player = get_tree().get_first_node_in_group("Player")
	ray_cast_3d.target_position = Vector3(0.0,0.0,-5.0)
	player.camera_3d.add_child(ray_cast_3d)
	
	var build_mesh_paths := DirAccess.get_files_at("res://Models/Build")
	for path in build_mesh_paths:
		if path.ends_with("obj"):
			var mesh := load("res://Models/Build/" + path)
			var id := path.substr(0, path.length()-4).to_lower()
			blocks[id] = mesh
	
	var data: Dictionary = load("res://Resources/build.json").data
	for tab_name: String in data:
		var tab: Dictionary = data[tab_name]
		var container := MarginContainer.new()
		container.add_theme_constant_override("margin_top", 10)
		container.add_theme_constant_override("margin_left", 10)
		container.add_theme_constant_override("margin_bottom", 10)
		container.add_theme_constant_override("margin_right", 10)
		var scroll_container = ScrollContainer.new()
		var tab_instance := VBoxContainer.new()
		tab_instance.size_flags_horizontal = VBoxContainer.SIZE_EXPAND_FILL 
		tab_instance.size_flags_vertical = VBoxContainer.SIZE_EXPAND_FILL 
		scroll_container.add_child(tab_instance)
		container.add_child(scroll_container)
		container.name = tab_name
		for category_name: String in tab:
			var block_ids: Array = tab[category_name]
			var category := VBoxContainer.new()
			tab_instance.add_child(category)
			var category_label := Label.new()
			category_label.text = category_name
			category.add_child(category_label)
			var block_container := HFlowContainer.new()
			category.add_child(block_container)
			for block_id: String in block_ids:
				var button := Button.new()
				button.icon = load("res://Resources/Icons/" + block_id + ".png")
				button.add_theme_constant_override("icon_max_width", 160)
				#button.text = block_id
				button.custom_minimum_size = Vector2(160.0, 160.0)
				var callable := _on_block_select_pressed
				callable = callable.bind(block_id)
				button.pressed.connect(callable)
				block_container.add_child(button)
		build_blocks.add_child(container)
		
	selected_block = blocks.keys()[selected_block_id]
	
	structure_list.auto_height = true
	
	if !DirAccess.dir_exists_absolute("user://structures"):
		DirAccess.make_dir_absolute("user://structures")
	
	default_preview()
	
	
func _process(delta: float) -> void:
	if delay > 0.0:
		delay = max(delay - delta, 0.0)
	if build_mode:
		preview()
	elif preview_manager != null:
		remove_preview()
	if delay == 0.0 and placing_block:
		place_block()
	if breaking_block:
		break_block()

func _unhandled_input(event) -> void:
	if event.is_action_pressed("build_mode"):
		build_mode = !build_mode
		mode.text = "Build" if build_mode else ""
	if event.is_action_pressed("place") and build_mode:
		placing_block = true
	if event.is_action_released("place"):
		placing_block = false
	if event.is_action_pressed("break") and build_mode:
		breaking_block = true
	if event.is_action_pressed("next_block") and build_mode:
		switch_block(true)
	if event.is_action_pressed("rotate") and build_mode:
		rotate_mode = true
	if event.is_action_released("rotate"):
		rotate_mode = false
	if event.is_action_pressed("mirror") and build_mode:
		mirror_block()
	if event.is_action_pressed("open_block_select") and build_mode:
		build_blocks.visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if rotate_mode:
				rotate_block(true)
			else:
				switch_block(false)

		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if rotate_mode:
				rotate_block(false)
			else:
				switch_block(true)

func default_preview():
	var transform3d = Transform3D(Basis.IDENTITY,Vector3(0.5,0.0,0.5))
	preview_manager.change_preview({transform3d.origin: ConstructionBlock.new(selected_block, transform3d, true)})

func preview():
	if ray_cast_3d.is_colliding():
		var collider = ray_cast_3d.get_collider()
		if collider is StaticBody3D:
			var pos: Vector3 = ray_cast_3d.get_collision_point() + Vector3(0.00001, 0.00001, 0.00001) / 1.0
			if !preview_visible:
				add_child(preview_manager)
				preview_visible = true
			var real_pos = (pos+ray_cast_3d.get_collision_normal()/2.0).floor()
			block_transform.origin = real_pos+Vector3(0.5, 0.0, 0.5)
			preview_manager.transform = block_transform
	else:
		remove_preview()

func switch_block(next: bool):
	if !structure_mode:
		selected_block_id = (selected_block_id + (1 if next else -1))%blocks.size()
		selected_block = blocks.keys()[selected_block_id]
		default_preview()

func select_block(block_id: String) -> void:
	if !structure_mode:
		selected_block = block_id
		default_preview()

func remove_preview():
	if preview_visible:
		remove_child(preview_manager)
		preview_visible = false
		
func rotate_block(clockwise: bool):
	#prints("rotate clockwise :", clockwise)
	block_transform = block_transform.rotated_local(Vector3.UP, PI/2.0 * (-1 if clockwise else 1))
	#preview_instance.transform = block_transform

func mirror_block():
	var dir = (ray_cast_3d.get_collision_point()-ray_cast_3d.global_position).normalized().round().abs()
	dir.y = 0.0
	block_transform = block_transform.scaled(Vector3(-1.0,1.0,-1.0)+dir*2)
	#preview_instance.transform = block_transform

func place_block():
	if ray_cast_3d.is_colliding():
		for coord in preview_manager.blocks:
			var block: ConstructionBlock = preview_manager.blocks[coord]
			var transform3d: Transform3D = block_transform*(Transform3D(Basis.IDENTITY,Vector3(-0.5,0.0,-0.5))*block.block_transform)
			if selected_block.contains("roof"):
				placed_blocks[transform3d.origin] = RoofBlock.new(selected_block, transform3d, get_block_between(transform3d.origin-Vector3(1.0,1.0,1.0), transform3d.origin+Vector3(1.0,1.0,1.0)))
			else:
				placed_blocks[transform3d.origin] = ConstructionBlock.new(block.block_id, transform3d)
			add_child(placed_blocks[transform3d.origin].block)
		delay = delay_between_action
		placing_block = false
		if structure_mode:
			structure_mode = false
			default_preview()

func break_block():
	if ray_cast_3d.is_colliding():
		var block: Node3D = ray_cast_3d.get_collider()
		#var pos = (ray_cast_3d.get_collision_point()-ray_cast_3d.get_collision_normal()/2.0).floor()+Vector3(0.5,0.0,0.5)
		var pos = block.position
		if placed_blocks.has(pos):
			#var block: Node3D = placed_blocks[pos].block
			remove_child(block)
			placed_blocks[pos].delete()
			placed_blocks.erase(pos) 
		breaking_block = false

func create_block(block_id: String, block_transform3d: Transform3D) -> Node3D:
	var body = StaticBody3D.new()
	var instance = MeshInstance3D.new()
	instance.mesh = blocks[block_id]
	var collision = CollisionShape3D.new()
	collision.shape = ConcavePolygonShape3D.new()
	collision.shape.set_faces(instance.mesh.get_faces())
	body.transform = block_transform3d
	body.add_child(collision)
	body.add_child(instance)
	return body

func save_structure(structure_name: String):
	var file_path: String = "user://structures/" + structure_name + ".txt"
	var saveHandler := FileAccess.open(file_path, FileAccess.WRITE)
	var save_dict: Dictionary = {}
	for coord in placed_blocks:
		save_dict[coord] = placed_blocks[coord].save()
	saveHandler.store_string(JSON.stringify(save_dict, "\t"))
	saveHandler.close()

func get_block_between(min_pos: Vector3, max_pos: Vector3) -> Dictionary[Vector3, ConstructionBlock]:
	var contained_blocks: Dictionary[Vector3, ConstructionBlock] = {}
	for coord: Vector3 in placed_blocks:
		if coord <= max_pos and coord >= min_pos:
			contained_blocks[coord] = placed_blocks[coord]
	return contained_blocks

func load_structure(structure_name: String):
	for pos in placed_blocks.keys():
		var block: ConstructionBlock = placed_blocks[pos]
		placed_blocks.erase(pos) 
		remove_child(block.block)
		block.delete()
	var saveHandler := FileAccess.open("user://structures/"+structure_name, FileAccess.READ)
	if saveHandler == null:
		return
	var load_string := saveHandler.get_as_text()
	var load_dict: Dictionary = JSON.parse_string(load_string)
	var loaded_blocks: Dictionary[Vector3, ConstructionBlock] = {}
	for coord: String in load_dict:
		var block_dict: Dictionary = load_dict[coord]
		var block_id: String = block_dict["block_id"]
		var block_transform3d: Transform3D = JSON.to_native(block_dict["block_transform"])
		loaded_blocks[block_transform3d.origin] = ConstructionBlock.new(block_id, block_transform3d, true)
	saveHandler.close()
	preview_manager.change_preview(loaded_blocks)
	structure_mode = true

func close_menus():
	save_structure_menu.visible = false
	load_structure_menu.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_block_select_pressed(block_id: String):
	build_blocks.visible = false
	select_block(block_id)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_save_button_pressed() -> void:
	save_structure_menu.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_save_structure_button_pressed() -> void:
	var structure_name: String = save_structure_name.text
	if !structure_name.is_empty():
		save_structure(structure_name)
		close_menus()

func _on_cancel_save_button_pressed() -> void:
	close_menus()

func _on_load_button_pressed() -> void:
	var structure_names := DirAccess.get_files_at("user://structures")
	structure_list.clear()
	for structure_name in structure_names:
		structure_list.add_item(structure_name)
	load_structure_menu.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_load_structure_button_pressed() -> void:
	var structure_selected := structure_list.get_selected_items()[0]
	if structure_selected != null:
		load_structure(structure_list.get_item_text(structure_selected))
		close_menus()

func _on_cancel_pressed() -> void:
	close_menus()
