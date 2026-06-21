extends Node3D
class_name PreviewManager

var blocks: Dictionary[Vector3, ConstructionBlock] = {}

func change_preview(blocks_list:  Dictionary[Vector3, ConstructionBlock]) -> void:
	reset()
	blocks = blocks_list
	for block: ConstructionBlock in blocks.values():
		block.block.transparency = 0.5
		block.block.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(block.block)

func reset() -> void:
	for block: ConstructionBlock in blocks.values():
		remove_child(block.block)
		block.delete()
	blocks.clear()
