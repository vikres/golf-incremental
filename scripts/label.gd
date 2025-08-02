extends Label
# Enhanced performance monitor - replaces your simple FPS counter
# Shows FPS, frame time, memory usage with color coding

var fps_history = []
var frame_time_history = []
var memory_history = []
var history_size = 30

# Performance thresholds
var good_fps = 50
var ok_fps = 30
var good_frame_time = 16.67  # ms for 60fps
var ok_frame_time = 33.33    # ms for 30fps

# Memory check timer
var memory_check_timer = 0.0
var memory_check_interval = 1.0  # Check memory every second

# Worst performance tracking
var worst_frame_time = 0.0
var frame_spike_count = 0

func _ready():
	# Position and styling
	add_theme_color_override("font_color", Color.WHITE)
	add_theme_color_override("font_shadow_color", Color.BLACK)
	add_theme_constant_override("shadow_offset_x", 2)
	add_theme_constant_override("shadow_offset_y", 2)
	
	# Make it monospace for better number alignment
	var font = ThemeDB.fallback_font
	add_theme_font_override("font", font)

func _process(delta):
	# Track frame time (in milliseconds)
	var frame_time_ms = delta * 1000.0
	frame_time_history.append(frame_time_ms)
	
	# Track worst frame time
	if frame_time_ms > worst_frame_time:
		worst_frame_time = frame_time_ms
	
	# Count frame spikes (frames slower than 30fps)
	if frame_time_ms > 33.33:
		frame_spike_count += 1
	
	# Track FPS
	fps_history.append(Engine.get_frames_per_second())
	
	# Trim histories
	if fps_history.size() > history_size:
		fps_history.pop_front()
	if frame_time_history.size() > history_size:
		frame_time_history.pop_front()
	
	# Memory check (less frequent)
	memory_check_timer += delta
	if memory_check_timer >= memory_check_interval:
		memory_check_timer = 0.0
		# Use Performance monitor for memory in Godot 4.4.1
		var memory_bytes = Performance.get_monitor(Performance.MEMORY_STATIC)
		var memory_mb = memory_bytes / 1024.0 / 1024.0
		memory_history.append(memory_mb)
		
		if memory_history.size() > 10:  # Keep 10 seconds of memory data
			memory_history.pop_front()
	
	_update_display()

func _update_display():
	if fps_history.is_empty() or frame_time_history.is_empty():
		return
	
	# Calculate averages
	var avg_fps = _calculate_average(fps_history)
	var avg_frame_time = _calculate_average(frame_time_history)
	var current_memory = 0.0
	
	if not memory_history.is_empty():
		current_memory = memory_history.back()
	
	# Build display text
	var display_text = "FPS: %d\n" % avg_fps
	display_text += "Frame: %.1fms\n" % avg_frame_time
	display_text += "Memory: %.1fMB\n" % current_memory
	display_text += "Worst: %.1fms\n" % worst_frame_time
	display_text += "Spikes: %d" % frame_spike_count
	
	text = display_text
	
	# Color coding based on worst performance metric
	var performance_color = _get_performance_color(avg_fps, avg_frame_time, current_memory)
	add_theme_color_override("font_color", performance_color)

func _calculate_average(array: Array) -> float:
	if array.is_empty():
		return 0.0
	
	var sum = 0.0
	for value in array:
		sum += value
	return sum / array.size()

func _get_performance_color(fps: float, frame_time: float, memory: float) -> Color:
	# Determine overall performance status
	var fps_status = ""
	var frame_status = ""
	var memory_status = ""
	
	# FPS evaluation
	if fps >= good_fps:
		fps_status = "good"
	elif fps >= ok_fps:
		fps_status = "ok"
	else:
		fps_status = "bad"
	
	# Frame time evaluation
	if frame_time <= good_frame_time:
		frame_status = "good"
	elif frame_time <= ok_frame_time:
		frame_status = "ok"
	else:
		frame_status = "bad"
	
	# Memory evaluation (basic - you might want to adjust thresholds)
	if memory < 50.0:
		memory_status = "good"
	elif memory < 100.0:
		memory_status = "ok"
	else:
		memory_status = "bad"
	
	# Return worst status color
	if fps_status == "bad" or frame_status == "bad" or memory_status == "bad":
		return Color.RED
	elif fps_status == "ok" or frame_status == "ok" or memory_status == "ok":
		return Color.YELLOW
	else:
		return Color.GREEN

# Call this to reset worst performance tracking
func reset_performance_tracking():
	worst_frame_time = 0.0
	frame_spike_count = 0
	print("Performance tracking reset")

# Call this to get a performance report
func get_performance_report() -> String:
	var avg_fps = _calculate_average(fps_history)
	var avg_frame_time = _calculate_average(frame_time_history)
	var memory = 0.0
	if not memory_history.is_empty():
		memory = memory_history.back()
	
	var report = "=== PERFORMANCE REPORT ===\n"
	report += "Average FPS: %.1f\n" % avg_fps
	report += "Average Frame Time: %.2fms\n" % avg_frame_time
	report += "Worst Frame Time: %.2fms\n" % worst_frame_time
	report += "Frame Spikes (>33ms): %d\n" % frame_spike_count
	report += "Current Memory: %.1fMB\n" % memory
	report += "Status: "
	
	if worst_frame_time > ok_frame_time:
		report += "⚠️ CONCERNING - Frame spikes detected"
	elif avg_frame_time > good_frame_time:
		report += "⚠️ MARGINAL - Close to performance limits"
	else:
		report += "✅ GOOD - Should run well on itch.io"
	
	return report
