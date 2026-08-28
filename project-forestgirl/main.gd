extends Node2D

const VIEW_SIZE := Vector2(1280.0, 720.0)
const PLAYER_SIZE := Vector2(34.0, 58.0)
const FLOOR_Y := 520.0
const LEFT_END := 700.0
const RIGHT_START := 925.0
const WORLD_END := 1700.0
const GRAVITY := 1500.0
const MOVE_SPEED := 260.0
const JUMP_SPEED := -590.0

var player_pos := Vector2(120.0, FLOOR_Y - PLAYER_SIZE.y)
var player_velocity := Vector2.ZERO
var previous_pos := player_pos
var camera_x := 0.0
var mushroom_growth := 0.0
var activated := false
var finished := false
var elapsed := 0.0
var hint_timer := 0.0
var font: Font

func _ready() -> void:
	font = ThemeDB.fallback_font
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	hint_timer += delta
	if activated:
		mushroom_growth = move_toward(mushroom_growth, 1.0, delta * 0.75)
	update_camera()
	queue_redraw()

func _physics_process(delta: float) -> void:
	if Input.is_key_pressed(KEY_R):
		reset_game()
	if finished:
		return

	previous_pos = player_pos
	var direction := Input.get_axis("ui_left", "ui_right")
	if Input.is_key_pressed(KEY_A):
		direction -= 1.0
	if Input.is_key_pressed(KEY_D):
		direction += 1.0
	direction = clampf(direction, -1.0, 1.0)
	player_velocity.x = move_toward(player_velocity.x, direction * MOVE_SPEED, 1200.0 * delta)
	if is_on_surface() and Input.is_action_just_pressed("ui_accept"):
		player_velocity.y = JUMP_SPEED
	if in_observation_zone() and not activated and Input.is_key_pressed(KEY_E):
		activated = true
		hint_timer = 0.0

	player_velocity.y += GRAVITY * delta
	player_pos += player_velocity * delta
	resolve_surfaces()
	player_pos.x = clampf(player_pos.x, 20.0, WORLD_END - PLAYER_SIZE.x)

	if player_pos.y > 760.0:
		player_pos = Vector2(590.0 if activated else 120.0, FLOOR_Y - PLAYER_SIZE.y)
		player_velocity = Vector2.ZERO
	if player_pos.x > 1510.0:
		finished = true

func is_on_surface() -> bool:
	var feet := player_pos.y + PLAYER_SIZE.y
	if abs(feet - FLOOR_Y) < 2.5 and (player_pos.x + PLAYER_SIZE.x > 0.0 and player_pos.x < LEFT_END or player_pos.x + PLAYER_SIZE.x > RIGHT_START):
		return true
	if mushroom_growth > 0.75:
		var platform := mushroom_platform()
		if abs(feet - platform.position.y) < 3.0 and player_pos.x + PLAYER_SIZE.x > platform.position.x and player_pos.x < platform.end.x:
			return true
	return false

func resolve_surfaces() -> void:
	if player_velocity.y < 0.0:
		return
	var old_feet := previous_pos.y + PLAYER_SIZE.y
	var new_feet := player_pos.y + PLAYER_SIZE.y
	var on_land := player_pos.x + PLAYER_SIZE.x > 0.0 and player_pos.x < LEFT_END or player_pos.x + PLAYER_SIZE.x > RIGHT_START
	if on_land and old_feet <= FLOOR_Y and new_feet >= FLOOR_Y:
		player_pos.y = FLOOR_Y - PLAYER_SIZE.y
		player_velocity.y = 0.0
		return
	if mushroom_growth > 0.12:
		var platform := mushroom_platform()
		var overlaps := player_pos.x + PLAYER_SIZE.x > platform.position.x and player_pos.x < platform.end.x
		if overlaps and old_feet <= platform.position.y and new_feet >= platform.position.y:
			player_pos.y = platform.position.y - PLAYER_SIZE.y
			player_velocity.y = 0.0

func mushroom_platform() -> Rect2:
	var width: float = lerpf(44.0, 220.0, mushroom_growth)
	var top: float = lerpf(FLOOR_Y - 34.0, FLOOR_Y - 150.0, mushroom_growth)
	return Rect2(Vector2(805.0 - width * 0.5, top), Vector2(width, 18.0))

func in_observation_zone() -> bool:
	return player_pos.x > 390.0 and player_pos.x < 485.0 and is_on_surface()

func update_camera() -> void:
	var target: float = clampf(player_pos.x - 420.0, 0.0, WORLD_END - VIEW_SIZE.x)
	camera_x = lerpf(camera_x, target, 0.08)

func reset_game() -> void:
	player_pos = Vector2(120.0, FLOOR_Y - PLAYER_SIZE.y)
	player_velocity = Vector2.ZERO
	mushroom_growth = 0.0
	activated = false
	finished = false
	elapsed = 0.0
	camera_x = 0.0

func _draw() -> void:
	draw_background()
	draw_world()
	draw_reflection()
	draw_player()
	draw_interface()

func draw_background() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color("#102a25"))
	for i in range(16):
		var x := fmod(float(i * 137) - camera_x * (0.18 + (i % 3) * 0.05), 1500.0) - 80.0
		var h := 170.0 + float((i * 47) % 190)
		draw_rect(Rect2(x, FLOOR_Y - h, 18.0 + float(i % 4) * 6.0, h), Color("#173c32"))
		draw_circle(Vector2(x + 10.0, FLOOR_Y - h), 48.0 + float(i % 3) * 17.0, Color("#1d493a"))
	# Mist
	for i in range(5):
		draw_circle(Vector2(180.0 + i * 280.0, 360.0 + (i % 2) * 35.0), 150.0, Color(0.35, 0.58, 0.48, 0.035))

func draw_world() -> void:
	var ox := -camera_x
	# Ground and ravine
	draw_rect(Rect2(ox, FLOOR_Y, LEFT_END, 80.0), Color("#244b36"))
	draw_rect(Rect2(ox + RIGHT_START, FLOOR_Y, WORLD_END - RIGHT_START, 80.0), Color("#244b36"))
	draw_line(Vector2(ox, FLOOR_Y), Vector2(ox + LEFT_END, FLOOR_Y), Color("#79a865"), 5.0)
	draw_line(Vector2(ox + RIGHT_START, FLOOR_Y), Vector2(ox + WORLD_END, FLOOR_Y), Color("#79a865"), 5.0)
	# Observation stone
	var zone_color := Color("#bce28b") if in_observation_zone() and not activated else Color("#587659")
	draw_circle(Vector2(ox + 438.0, FLOOR_Y - 5.0), 26.0, zone_color)
	draw_circle(Vector2(ox + 438.0, FLOOR_Y - 8.0), 12.0, Color("#2b4b3b"))
	# Exit light
	draw_circle(Vector2(ox + 1570.0, FLOOR_Y - 90.0), 70.0, Color(0.75, 0.95, 0.66, 0.14))
	draw_line(Vector2(ox + 1570.0, FLOOR_Y), Vector2(ox + 1570.0, FLOOR_Y - 125.0), Color("#d9f2b4"), 5.0)
	# Mushroom in reality
	var p := mushroom_platform()
	var cap := Rect2(p.position + Vector2(ox, -8.0), p.size)
	var stem_h: float = lerpf(24.0, 130.0, mushroom_growth)
	draw_rect(Rect2(Vector2(ox + 795.0, p.position.y + 8.0), Vector2(20.0, stem_h)), Color("#d8d1ad"))
	draw_rounded_rect(cap, Color("#d57a64"), 12.0)
	for i in range(4):
		var spot_x := cap.position.x + cap.size.x * (0.18 + i * 0.21)
		draw_circle(Vector2(spot_x, cap.position.y + 8.0), 4.0 + mushroom_growth * 3.0, Color("#f4dfb4"))

func draw_reflection() -> void:
	var water_y := 600.0
	draw_rect(Rect2(0.0, water_y, VIEW_SIZE.x, 120.0), Color("#123f47"))
	for i in range(8):
		var wave_y := water_y + 12.0 + i * 14.0
		draw_line(Vector2(0.0, wave_y), Vector2(VIEW_SIZE.x, wave_y), Color(0.36, 0.73, 0.72, 0.08), 2.0)
	# The reflected mushroom changes apparent size as the player approaches the observation stone.
	var alignment: float = clampf(1.0 - absf(player_pos.x - 438.0) / 260.0, 0.0, 1.0)
	var reflected_scale: float = 0.35 + alignment * 1.25
	var mx := 805.0 - camera_x
	draw_line(Vector2(mx, water_y + 8.0), Vector2(mx, water_y + 72.0 * reflected_scale), Color(0.78, 0.83, 0.67, 0.52), 14.0 * reflected_scale)
	draw_rounded_rect(Rect2(mx - 70.0 * reflected_scale, water_y + 65.0 * reflected_scale, 140.0 * reflected_scale, 18.0 * reflected_scale), Color(0.82, 0.38, 0.32, 0.65), 10.0)
	# Target silhouette showing the useful alignment.
	if not activated:
		draw_dashed_line(Vector2(mx - 78.0, water_y + 92.0), Vector2(mx + 78.0, water_y + 92.0), Color(0.8, 0.95, 0.75, 0.5), 5.0, 9.0)
	# Player reflection
	var px := player_pos.x - camera_x
	draw_circle(Vector2(px + 17.0, water_y + 30.0), 12.0, Color(0.62, 0.78, 0.7, 0.35))
	draw_rect(Rect2(px + 5.0, water_y + 40.0, 24.0, 40.0), Color(0.48, 0.67, 0.61, 0.3))

func draw_player() -> void:
	var p := player_pos - Vector2(camera_x, 0.0)
	draw_circle(p + Vector2(PLAYER_SIZE.x * 0.5, 13.0), 13.0, Color("#f1c8a6"))
	draw_circle(p + Vector2(PLAYER_SIZE.x * 0.5, 8.0), 15.0, Color("#263f36"))
	draw_rect(Rect2(p + Vector2(5.0, 23.0), Vector2(24.0, 34.0)), Color("#d4a86e"))
	draw_line(p + Vector2(10.0, 55.0), p + Vector2(7.0, 62.0), Color("#d7c6a2"), 5.0)
	draw_line(p + Vector2(24.0, 55.0), p + Vector2(27.0, 62.0), Color("#d7c6a2"), 5.0)

func draw_interface() -> void:
	draw_rect(Rect2(24.0, 20.0, 520.0, 74.0), Color(0.02, 0.08, 0.07, 0.78))
	draw_string(font, Vector2(44.0, 50.0), "← → / A D  Move     Space  Jump     E  Fix reflection", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#e6f0d8"))
	var objective := "Follow the pale light beyond the ravine."
	if in_observation_zone() and not activated:
		objective = "The reflection aligns... Press E to hold it."
	elif activated and mushroom_growth < 0.95:
		objective = "The reflected size is becoming real."
	elif activated:
		objective = "Use the mushroom to cross the ravine."
	draw_string(font, Vector2(44.0, 78.0), objective, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#bce28b"))
	if finished:
		draw_rect(Rect2(255.0, 205.0, 770.0, 245.0), Color(0.02, 0.06, 0.055, 0.94))
		draw_string(font, Vector2(300.0, 270.0), "THE LAKE REMEMBERS ANOTHER FOREST", HORIZONTAL_ALIGNMENT_CENTER, 680.0, 30, Color("#d9f2b4"))
		draw_string(font, Vector2(315.0, 330.0), "Was the forest changing — or was she only watching its reflection?", HORIZONTAL_ALIGNMENT_CENTER, 650.0, 20, Color("#b8d8cb"))
		draw_string(font, Vector2(300.0, 402.0), "Press R to play again", HORIZONTAL_ALIGNMENT_CENTER, 680.0, 19, Color("#e8d3a5"))

func draw_rounded_rect(rect: Rect2, color: Color, radius: float) -> void:
	draw_rect(Rect2(rect.position + Vector2(radius, 0.0), Vector2(max(0.0, rect.size.x - radius * 2.0), rect.size.y)), color)
	draw_rect(Rect2(rect.position + Vector2(0.0, radius), Vector2(rect.size.x, max(0.0, rect.size.y - radius * 2.0))), color)
	draw_circle(rect.position + Vector2(radius, radius), radius, color)
	draw_circle(rect.position + Vector2(rect.size.x - radius, radius), radius, color)
	draw_circle(rect.position + Vector2(radius, rect.size.y - radius), radius, color)
	draw_circle(rect.position + Vector2(rect.size.x - radius, rect.size.y - radius), radius, color)

