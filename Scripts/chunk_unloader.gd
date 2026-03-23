extends Node
class_name ChunkUnloader

var mutex: Mutex
var thread_ids: Dictionary[Vector3, int] = {}

func _ready() -> void:
	mutex = Mutex.new()

func _exit_tree() -> void:
	for id : int in thread_ids.values():
		WorkerThreadPool.wait_for_task_completion(id)

func unload_chunk(chunk: Chunk) -> void:
	var thread: Callable = unload
	thread.bind(chunk)
	thread_ids[chunk.chunk_pos] = WorkerThreadPool.add_task(thread)
	
func unload(chunk: Chunk) -> void:
	chunk.wait_for_thread()
	
	chunk.chunk_data.clearData()
	
	mutex.lock()
	thread_ids.erase(chunk.chunk_pos)
	mutex.unlock()
	
	chunk.call_deferred("free")
