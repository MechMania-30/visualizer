extends Node

# This variable will hold your game log data.
var game_log = {}
var current_turn = 0
var is_playing = false
var plane_instances = {}
var time_since_last_turn = 0.0
var turn_delay = 0.5

var screen_width = 1000
var screen_height = 1000

# Preload the plane scene
var PlaneScene = preload("res://plane_scene.tscn") # Adjust the path as necessary

# Called when the node enters the scene tree for the first time.
func _ready():
	print("Loading game log.")
	load_game_log("res://2_4_24_test_log.json") # Adjust the path as necessary
	set_process(false) # Disable _process until we hit 'play'
	print("Main game controller ready.")
	update_game_state_for_current_turn()
	update_turn_display()
	
func interpolate_arc(start_pos, end_pos, start_angle, end_angle, n_steps):
	var interpolated_positions = []
	var interpolated_angles = []
	for step in range(1, n_steps + 1):
		var fraction = float(step) / n_steps
		var interpolated_pos_x = start_pos.x + (end_pos.x - start_pos.x) * fraction
		var interpolated_pos_y = start_pos.y + (end_pos.y - start_pos.y) * fraction
		var interpolated_pos = Vector2(interpolated_pos_x, interpolated_pos_y)
		
		var interpolated_angle = start_angle + (end_angle - start_angle) * fraction
		
		interpolated_positions.append(interpolated_pos)
		interpolated_angles.append(interpolated_angle)
	return {"positions": interpolated_positions, "angles": interpolated_angles}
	
func interpolate_game_log(n_steps):
	var new_turns = []
	for i in range(game_log["turns"].size() - 1):
		var start_turn = game_log["turns"][i]
		new_turns.append(start_turn)  # Add the original turn for continuity
		
		var end_turn = game_log["turns"][i + 1]
		for step in range(1, n_steps):
			var interpolated_turn = {"planes": []}
			for j in range(start_turn["planes"].size()):
				var start_plane = start_turn["planes"][j]
				var end_plane = end_turn["planes"][j]
				var start_pos = Vector2(start_plane["position"]["x"], start_plane["position"]["y"])
				var end_pos = Vector2(end_plane["position"]["x"], end_plane["position"]["y"])
				
				var result = interpolate_arc(start_pos, end_pos, start_plane["angle"], end_plane["angle"], n_steps)
				var step_positions = result["positions"]
				var step_angles = result["angles"]
				
				var interpolated_plane = {
					"position": {"x": step_positions[step - 1].x, "y": step_positions[step - 1].y},
					"angle": step_angles[step - 1],
					"type": start_plane["type"],
					"health": start_plane["health"],
					"team": start_plane["team"]
				}
				interpolated_turn["planes"].append(interpolated_plane)
			new_turns.append(interpolated_turn)
	new_turns.append(game_log["turns"][-1])  # Ensure the final turn is added
	game_log["turns"] = new_turns


# This function could be called to load and parse the game log.
func load_game_log(path):
	var file = FileAccess.open(path, FileAccess.READ)
	var json_text = file.get_as_text()
	var json = JSON.new()
	game_log = json.parse_string(json_text)
	file.close()
	interpolate_game_log(30)
	print("Game log loaded: ", game_log)

# Updates the display of the current turn.
func update_turn_display():
	var turn_label = get_node("Control/HBoxContainer/Label") # Adjust the path as necessary
	if turn_label:
		turn_label.text = "Turn: %d" % (current_turn / 30 + 1)
	else:
		print("TurnLabel node not found")

# Function to handle the play button press.
func _on_play_button_pressed():
	print("Playing.")
	is_playing = true
	set_process(true) # Enable _process to start game logic updates

# Function to handle the pause button press.
func _on_pause_button_pressed():
	print("Paused.")
	is_playing = false
	set_process(false) # Stop game logic updates

# Function to handle the step button press.
func _on_step_button_pressed():
	print("Stepped.")
	if current_turn >= game_log.turns.size():
		current_turn = 0 # Loop back to the start
	for i in range(30):
		await get_tree().create_timer(0.001).timeout
		current_turn += 1
		update_game_state_for_current_turn()
	update_turn_display()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if is_playing:
		time_since_last_turn += delta
		if time_since_last_turn >= turn_delay:
			time_since_last_turn = 0.0 # Reset the timer
			_on_step_button_pressed() # Go to the next turn

# Updates the game state for the current turn.
#func update_game_state_for_current_turn():
#	for plane_id in plane_instances:
#		plane_instances[plane_id].queue_free()
#	plane_instances.clear()
#
#	var turn_data = game_log["turns"][current_turn]["planes"]
#	for plane_id in turn_data:
#		var plane_data = turn_data[plane_id]
#		var new_plane = PlaneScene.instantiate()
#		add_child(new_plane)
#		new_plane.position = Vector2(plane_data["position"]["x"], plane_data["position"]["y"])
#		new_plane.rotation_degrees = plane_data["angle"]
#		new_plane.scale = Vector2(0.2, 0.2) # Adjust this scale factor as needed
#		plane_instances[plane_id] = new_plane
#
#	print("Turn updated to: ", current_turn)
	
func update_game_state_for_current_turn():
	for plane_instance in plane_instances.values():
		plane_instance.queue_free()
	plane_instances.clear()

	if current_turn >= game_log.turns.size():
		current_turn = 0
	var planes = game_log.turns[current_turn].planes
	for i in range(planes.size()):
		var plane_data = planes[i]
		var new_plane = PlaneScene.instantiate()
		add_child(new_plane)
		
		var screen_pos_x = screen_width * (plane_data["position"]["x"] / 100.0)
		var screen_pos_y = screen_height * (plane_data["position"]["y"] / 100.0)
		screen_pos_y = screen_height - screen_pos_y
		
		new_plane.position = Vector2(screen_pos_x, screen_pos_y)
		new_plane.rotation_degrees = plane_data["angle"]
		new_plane.scale = Vector2(0.1, 0.1)  # Adjust this scale factor as needed
#
#		new_plane.position = Vector2(plane_data.position.x, plane_data.position.y)
#		new_plane.rotation_degrees = plane_data.angle
		# Assuming you have a scale property or similar to adjust the visual representation
#		new_plane.scale = Vector2(0.2, 0.2)  # Adjust this scale factor as needed
		plane_instances[i] = new_plane  # Use index or a unique identifier as needed

	print("Turn updated to: ", current_turn)
