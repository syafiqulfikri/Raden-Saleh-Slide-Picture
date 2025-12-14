extends Node2D

var level_data = {
	3: {
		"texture": preload("res://Assets/Images/level1.jpg"),
		"details": "\"View of Dieng Plateau\" by Raden Saleh, 1872"
	},
	4: {
		"texture": preload("res://Assets/Images/level2.jpg"),
		"details": "\"Portrait of Raden Saleh\" c. 1840"
	},
	5: {
		"texture": preload("res://Assets/Images/level3.jpg"),
		"details": "\"The Lion Hunt\" by Raden Saleh, 1841"
	},
	6: {
		"texture": preload("res://Assets/Images/level4.jpg"),
		"details": "\"The Arrest of Pangeran Diponegoro\" by Raden Saleh, 1857"
	}
}
var current_texture: Texture2D 
var grid_size: int = 4 

@onready var main_menu = $CanvasLayer/MainMenu
@onready var home_menu = $CanvasLayer/MainMenu/HomeMenu
@onready var level_select = $CanvasLayer/MainMenu/LevelSelect
@onready var settings_menu = $CanvasLayer/MainMenu/SettingsMenu
@onready var game_ui = $CanvasLayer/GameUI
@onready var puzzle_marker = $CanvasLayer/GameUI/LeftArea/PuzzleMarker
@onready var label_info = $CanvasLayer/GameUI/RightArea/LabelInfo
@onready var btn_shuffle = $CanvasLayer/GameUI/RightArea/BtnShuffle
@onready var target_image = $CanvasLayer/GameUI/RightArea/TargetImage
@onready var label_moves = $CanvasLayer/GameUI/RightArea/LabelMoves
@onready var label_timer = $CanvasLayer/GameUI/RightArea/LabelTimer
@onready var label_best = $CanvasLayer/GameUI/RightArea/LabelBest
@onready var label_art_details = $CanvasLayer/GameUI/RightArea/LabelArtDetails
@onready var sfx_geser = $SfxGeser
@onready var sfx_menang = $SfxMenang
@onready var bg_music = $BgMusic
@onready var slider_volume = $CanvasLayer/MainMenu/SettingsMenu/SliderVolume
@onready var check_mute = $CanvasLayer/MainMenu/SettingsMenu/CheckMute

var tile_size = Vector2.ZERO
var empty_pos = Vector2.ZERO 
var grid_array = [] 
var is_shuffling = false
var puzzle_scale = 1.0 
var is_game_active = false 
var moves_count = 0
var time_elapsed = 0.0

var game_data = {
	"level_unlocked": 1, 
	"scores": {}         
}
const SAVE_PATH = "user://slidepuzzle_save.json"

func _ready():
	load_data()
	game_ui.visible = false
	game_ui.modulate.a = 0 
	main_menu.visible = true
	await get_tree().process_frame
	setup_all_buttons_animation()
	show_menu_page("home")
	
	$CanvasLayer/MainMenu/HomeMenu/BtnPlay.pressed.connect(func(): show_menu_page("level"))
	$CanvasLayer/MainMenu/HomeMenu/BtnSettings.pressed.connect(func(): show_menu_page("settings"))
	$CanvasLayer/MainMenu/HomeMenu/BtnExit.pressed.connect(func(): get_tree().quit())
	$CanvasLayer/MainMenu/LevelSelect/BtnLevel1.pressed.connect(func(): start_game(3))
	$CanvasLayer/MainMenu/LevelSelect/BtnLevel2.pressed.connect(func(): start_game(4))
	$CanvasLayer/MainMenu/LevelSelect/BtnLevel3.pressed.connect(func(): start_game(5))
	$CanvasLayer/MainMenu/LevelSelect/BtnLevel4.pressed.connect(func(): start_game(6))
	$CanvasLayer/MainMenu/LevelSelect/BtnBackLevel.pressed.connect(func(): show_menu_page("home"))
	
	slider_volume.value_changed.connect(on_volume_changed)
	check_mute.toggled.connect(on_mute_toggled)
	
	$CanvasLayer/MainMenu/SettingsMenu/BtnBackSettings.pressed.connect(func(): show_menu_page("home"))
	$CanvasLayer/GameUI/RightArea/BtnBack.pressed.connect(back_to_level_select)
	btn_shuffle.pressed.connect(shuffle_board)

func update_level_buttons():
	var buttons = [
		$CanvasLayer/MainMenu/LevelSelect/BtnLevel1,
		$CanvasLayer/MainMenu/LevelSelect/BtnLevel2,
		$CanvasLayer/MainMenu/LevelSelect/BtnLevel3,
		$CanvasLayer/MainMenu/LevelSelect/BtnLevel4
	]
	
	for i in range(buttons.size()):
		var level_num = i + 1
		if level_num <= game_data["level_unlocked"]:
			buttons[i].disabled = false
			buttons[i].modulate = Color(1, 1, 1, 1) 
		else:
			buttons[i].disabled = true
			buttons[i].modulate = Color(0.5, 0.5, 0.5, 0.5)

func save_data():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(game_data))

func load_data():
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		var text = file.get_as_text()
		var json = JSON.new()
		var error = json.parse(text)
		
		if error == OK:
			var loaded = json.data
			if loaded.has("level_unlocked"):
				game_data = loaded
			else:
				game_data["scores"] = loaded
				game_data["level_unlocked"] = 1

func update_best_score_ui():
	var level_key = str(grid_size)
	if game_data["scores"].has(level_key):
		label_best.text = "Best Moves: " + str(game_data["scores"][level_key])
	else:
		label_best.text = "Best Moves: -"

func check_win():
	if is_shuffling: return 
	for x in range(grid_size):
		for y in range(grid_size):
			if x == grid_size - 1 and y == grid_size - 1: continue
			var tile = grid_array[x][y]
			if tile == null: return 
			if tile.get_meta("posisi_asli") != Vector2(x, y): return
	
	print("MENANG!")
	is_game_active = false
	btn_shuffle.text = "Ulangi Level"
	sfx_menang.play()
	
	var current_level_num = grid_size - 2
	var msg = "LEVEL SELESAI!"
	
	if current_level_num == game_data["level_unlocked"]:
		if game_data["level_unlocked"] < 4:
			game_data["level_unlocked"] += 1
			msg += "\nLEVEL " + str(current_level_num + 1) + " TERBUKA!"
		else:
			msg = "SELAMAT! SEMUA LEVEL SELESAI!"
	
	var level_key = str(grid_size)
	if not game_data["scores"].has(level_key) or moves_count < game_data["scores"][level_key]:
		game_data["scores"][level_key] = moves_count
		msg += "\nREKOR BARU!"
	
	label_info.text = msg
	save_data()
	update_best_score_ui()

func start_game(level_size):
	grid_size = level_size 
	if level_data.has(level_size):
		current_texture = level_data[level_size]["texture"]
		label_art_details.text = level_data[level_size]["details"]
	else:
		current_texture = level_data[3]["texture"]
		label_art_details.text = level_data[3]["details"]

	var tween_out = create_tween()
	tween_out.tween_property(main_menu, "modulate:a", 0.0, 0.2)
	await tween_out.finished
	main_menu.visible = false
	main_menu.modulate.a = 1.0 
	
	game_ui.visible = true
	game_ui.modulate.a = 0.0
	var tween_in = create_tween()
	tween_in.tween_property(game_ui, "modulate:a", 1.0, 0.5)
	
	setup_puzzle()
	if target_image and current_texture:
		target_image.texture = current_texture
	
	update_best_score_ui()
	await get_tree().create_timer(0.5).timeout
	shuffle_board()

func show_menu_page(page_name):
	home_menu.visible = false
	level_select.visible = false
	settings_menu.visible = false
	
	var target_menu = null
	if page_name == "home": target_menu = home_menu
	elif page_name == "level": 
		target_menu = level_select
		update_level_buttons()
	elif page_name == "settings": target_menu = settings_menu
	
	if target_menu:
		target_menu.visible = true
		target_menu.modulate.a = 0.0 
		target_menu.scale = Vector2(0.9, 0.9) 
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(target_menu, "modulate:a", 1.0, 0.3)
		tween.parallel().tween_property(target_menu, "scale", Vector2(1.0, 1.0), 0.3)

func setup_all_buttons_animation():
	var all_buttons = find_children("*", "Button", true, false)
	for btn in all_buttons:
		btn.pivot_offset = btn.size / 2
		btn.mouse_entered.connect(func(): animate_hover(btn, true))
		btn.mouse_exited.connect(func(): animate_hover(btn, false))

func animate_hover(btn: Button, is_hovering: bool):
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if is_hovering:
		tween.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.1)
		tween.parallel().tween_property(btn, "modulate", Color(1.2, 1.2, 1.2), 0.1)
	else:
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)
		tween.parallel().tween_property(btn, "modulate", Color(1, 1, 1), 0.1)

func on_volume_changed(value): bg_music.volume_db = value
func on_mute_toggled(is_on): bg_music.stream_paused = not is_on

func back_to_level_select():
	var tween_out = create_tween()
	tween_out.tween_property(game_ui, "modulate:a", 0.0, 0.2)
	await tween_out.finished
	game_ui.visible = false
	is_game_active = false 
	clear_puzzle()
	main_menu.visible = true
	show_menu_page("level")

func _process(delta):
	if is_game_active and not is_shuffling:
		time_elapsed += delta
		var minutes = int(time_elapsed / 60)
		var seconds = int(time_elapsed) % 60
		label_timer.text = "Time: %02d:%02d" % [minutes, seconds]

func update_moves_ui(): label_moves.text = "Moves: " + str(moves_count)

func clear_puzzle():
	for child in puzzle_marker.get_children(): child.queue_free()
	grid_array = []

func setup_puzzle():
	clear_puzzle() 
	await get_tree().process_frame 
	var target_size = puzzle_marker.custom_minimum_size
	if target_size == Vector2.ZERO: target_size = Vector2(500, 500)
	var img_width = current_texture.get_width()
	var img_height = current_texture.get_height()
	puzzle_scale = min(target_size.x / img_width, target_size.y / img_height)
	var final_width = img_width * puzzle_scale
	var final_height = img_height * puzzle_scale
	tile_size = Vector2(final_width / grid_size, final_height / grid_size)
	grid_array = []
	grid_array.resize(grid_size)
	for x in range(grid_size):
		grid_array[x] = []
		grid_array[x].resize(grid_size)
	for y in range(grid_size):
		for x in range(grid_size):
			var grid_pos = Vector2(x, y)
			if grid_pos == Vector2(grid_size - 1, grid_size - 1):
				empty_pos = grid_pos
				grid_array[x][y] = null 
				continue 
			spawn_tile(grid_pos)

func spawn_tile(grid_pos):
	var tile = Sprite2D.new()
	puzzle_marker.add_child(tile)
	tile.texture = current_texture
	tile.centered = false
	tile.region_enabled = true 
	tile.set_meta("posisi_asli", grid_pos) 
	
	var raw_tile_w = current_texture.get_width() / grid_size
	var raw_tile_h = current_texture.get_height() / grid_size
	tile.region_rect = Rect2(grid_pos.x * raw_tile_w, grid_pos.y * raw_tile_h, raw_tile_w, raw_tile_h)
	
	tile.scale = Vector2(puzzle_scale, puzzle_scale)
	tile.position = grid_pos * tile_size
	grid_array[grid_pos.x][grid_pos.y] = tile
	
	var label_number = Label.new()
	tile.add_child(label_number)
	
	var number = int((grid_pos.y * grid_size) + grid_pos.x + 1)
	label_number.text = str(number)
	
	label_number.position = Vector2(5, 5) 
	label_number.scale = Vector2(1.0 / puzzle_scale, 1.0 / puzzle_scale)
	
	var settings = LabelSettings.new()
	settings.font_size = 32
	settings.font_color = Color.WHITE
	settings.outline_size = 4
	settings.outline_color = Color.BLACK
	label_number.label_settings = settings

func _input(event):
	if is_shuffling or not is_game_active: return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = puzzle_marker.get_local_mouse_position()
		var clicked_x = int(mouse_pos.x / tile_size.x)
		var clicked_y = int(mouse_pos.y / tile_size.y)
		var clicked_grid = Vector2(clicked_x, clicked_y)
		if clicked_x >= 0 and clicked_x < grid_size and clicked_y >= 0 and clicked_y < grid_size: try_slide(clicked_grid)

func try_slide(clicked_grid):
	if clicked_grid.distance_to(empty_pos) == 1.0: slide_tile(clicked_grid, empty_pos)

func slide_tile(from_pos, to_pos, speed=0.2):
	var tile = grid_array[from_pos.x][from_pos.y]
	grid_array[to_pos.x][to_pos.y] = tile
	grid_array[from_pos.x][from_pos.y] = null
	if not is_shuffling:
		sfx_geser.play()
		moves_count += 1
		update_moves_ui()
	if speed == 0:
		tile.position = to_pos * tile_size
	else:
		var tween = create_tween()
		tween.tween_property(tile, "position", to_pos * tile_size, speed)
		tween.finished.connect(check_win)
	empty_pos = from_pos

func shuffle_board():
	is_shuffling = true
	is_game_active = true 
	moves_count = 0
	time_elapsed = 0.0
	update_moves_ui()
	update_best_score_ui() 
	
	var label_level = "Level " + str(grid_size - 2) 
	label_info.text = label_level + " - Susun Gambar!"
	btn_shuffle.text = "Acak Ulang"
	
	var shuffle_moves = grid_size * 20 
	for i in range(shuffle_moves):
		var neighbors = []
		var directions = [Vector2(1,0), Vector2(-1,0), Vector2(0,1), Vector2(0,-1)]
		for dir in directions:
			var check_pos = empty_pos + dir
			if check_pos.x >= 0 and check_pos.x < grid_size and check_pos.y >= 0 and check_pos.y < grid_size: neighbors.append(check_pos)
		if neighbors.size() > 0:
			var random_neighbor = neighbors.pick_random()
			slide_tile(random_neighbor, empty_pos, 0)
			if i % 20 == 0: await get_tree().process_frame 
	is_shuffling = false
