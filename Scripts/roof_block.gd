extends ConstructionBlock
class_name RoofBlock

var cases: Array[String] = ["roof_straight_corner_inner",
							"roof_straight_corner_outer",
							"roof_straight_corner_outer_eave",
							"roof_straight_side",
							"roof_straight_side_eave",
							"roof_straight_side_eave_edge",
							"roof_straight_side_edge"]

var top: RoofBlock
var bottom: RoofBlock
var front: RoofBlock
var back: RoofBlock
var right: RoofBlock
var left: RoofBlock

func _init(id: String, transform: Transform3D, blocks: Dictionary) -> void:
	super(id, transform)
	update_neighbors(blocks, true)

func update_neighbors(blocks: Dictionary, update_other: bool = false) -> void:
	check_neighbor(blocks, "top", Vector3(-1.0, 1.0, 0.0), update_other)
	check_neighbor(blocks, "bottom", Vector3(1.0, -1.0, 0.0), update_other)
	check_neighbor(blocks, "front", Vector3(1.0, 0.0, 0.0), update_other)
	check_neighbor(blocks, "back", Vector3(-1.0, 0.0, 0.0), update_other)
	check_neighbor(blocks, "right", Vector3(0.0, 0.0, -1.0), update_other)
	check_neighbor(blocks, "left", Vector3(0.0, 0.0, 1.0), update_other)
	
	#prints(blocks, top, bottom, front, back, right, left, update_other)
	update_roof()

func check_neighbor(blocks: Dictionary, name: String, neighbor_pos: Vector3, update_other: bool) -> void:
	var rotation := block_transform.basis.get_euler(EULER_ORDER_XYZ).y
	var pos := block_transform.origin + neighbor_pos.rotated(Vector3.UP, rotation)
	prints(name, pos, blocks.has(pos), blocks.has(pos) and blocks[pos] is RoofBlock)
	if blocks.has(pos) and blocks[pos] is RoofBlock:
		self[name] = blocks[pos]
		if update_other:  
			self[name].update_neighbors({block_transform.origin: self})

func update_roof() -> void:
	var is_bottom := bottom == null
	var do_mirror := false
	var is_middle := false
	var is_inner := false
	var is_outer := false
	
	if (front == null or (front.back == self and back != null)) and (back == null or back.back == self):
		if right != null && left != null:
			is_middle = true
		elif right != null:
			do_mirror = true
	elif front != null:
		if front.right == self and right != null:
			is_inner = true
		if front.left == self and left != null:
			is_inner = true
			do_mirror = true
	else:
		if back.right == self and right != null:
			is_outer = true
			do_mirror = true
		if back.left == self and left != null:
			is_outer = true
	
	if !is_inner and !is_outer: 
		if is_middle:
			block_id = cases[4 if is_bottom else 3]
		else:
			block_id = cases[5 if is_bottom else 6]
	elif is_inner:
		block_id = cases[0]
	else:
		block_id = cases[2 if is_bottom else 1]
		
	if (do_mirror and !is_mirrored) or (!do_mirror and is_mirrored):
		mirror(Vector3(1.0, 0.0, 0.0))
		
	prints(block_transform.origin, is_bottom, do_mirror, is_middle, is_inner, is_outer, block_id)
	update_block()

func remove_neighbor(neighbor: RoofBlock) -> void:
	if top == neighbor:
		top = null
	if bottom == neighbor:
		bottom = null
	if front == neighbor:
		front = null
	if back == neighbor:
		back = null
	if right == neighbor:
		right = null
	if left == neighbor:
		left = null
	update_roof()

func delete() -> void:
	if top != null:
		top.remove_neighbor(self)
	if bottom != null:
		bottom.remove_neighbor(self)
	if front != null:
		front.remove_neighbor(self)
	if back != null:
		back.remove_neighbor(self)
	if right != null:
		right.remove_neighbor(self)
	if left != null:
		left.remove_neighbor(self)
	super()
	
