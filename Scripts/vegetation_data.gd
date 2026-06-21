class_name VegetationData

var generated: bool = false

var grass_transforms: Dictionary[ChunkGenerator.GrassType, Array] = {}
var trees_transforms: Dictionary[ChunkGenerator.TreeType, Array] = {}

var trees: Array[MultiMeshInstance3D] = []
var grass: Array[MultiMeshInstance3D] = []
