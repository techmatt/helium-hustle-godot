class_name ResourceRateTracker
extends RefCounted

const BUFFER_SIZE: int = 20

# Key: "source_key:resource_id" → Array[float] of length BUFFER_SIZE
var _buffers: Dictionary = {}
var _write_idx: int = 0


func begin_tick() -> void:
	_write_idx = (_write_idx + 1) % BUFFER_SIZE
	for key: String in _buffers:
		var buf: Array = _buffers[key]
		buf[_write_idx] = 0.0


func record(source_key: String, resource_id: String, amount: float) -> void:
	var key: String = source_key + ":" + resource_id
	if not _buffers.has(key):
		var new_buf: Array = []
		new_buf.resize(BUFFER_SIZE)
		new_buf.fill(0.0)
		_buffers[key] = new_buf
	var buf: Array = _buffers[key]
	buf[_write_idx] += amount


func get_average(source_key: String, resource_id: String) -> float:
	var key: String = source_key + ":" + resource_id
	if not _buffers.has(key):
		return 0.0
	var buf: Array = _buffers[key]
	var sum: float = 0.0
	for i: int in range(BUFFER_SIZE):
		sum += float(buf[i])
	return sum / float(BUFFER_SIZE)


func get_instant(source_key: String, resource_id: String) -> float:
	var key: String = source_key + ":" + resource_id
	if not _buffers.has(key):
		return 0.0
	return float(_buffers[key][_write_idx])


func get_net_instant(resource_id: String) -> float:
	var total: float = 0.0
	var suffix: String = ":" + resource_id
	for key: String in _buffers:
		if key.ends_with(suffix):
			total += float(_buffers[key][_write_idx])
	return total


func get_sources_for_resource(resource_id: String) -> Array[String]:
	var result: Array[String] = []
	var suffix: String = ":" + resource_id
	for key: String in _buffers:
		if key.ends_with(suffix):
			result.append(key.left(key.length() - suffix.length()))
	return result


func get_net_average(resource_id: String) -> float:
	var total: float = 0.0
	var suffix: String = ":" + resource_id
	for key: String in _buffers:
		if key.ends_with(suffix):
			var buf: Array = _buffers[key]
			var buf_sum: float = 0.0
			for i: int in range(BUFFER_SIZE):
				buf_sum += float(buf[i])
			total += buf_sum / float(BUFFER_SIZE)
	return total


func reset() -> void:
	_buffers.clear()
	_write_idx = 0
