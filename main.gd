extends Node2D

@onready var cube: CharacterBody2D = $IceCube
@onready var timer_label: Label = $HUD/TimerLabel
@onready var window: Area2D = $Window
@onready var freezer: Area2D = $FreezerZone
@onready var start_screen: ColorRect = $HUD/StartScreen
@onready var win_screen: ColorRect = $HUD/WinScreen
@onready var bonus_popup: Label = $HUD/BonusPopup
@onready var win_label: Label = $HUD/WinScreen/Label 
var popup_tween: Tween
var timer_flash: Tween
var starting_position: Vector2
var initial_cube_time = 6.0
var time_left: float = initial_cube_time
var bonus_time: float = 0.0
var cube_number: int = 1
var in_freezer: bool = true
var respawning: bool = false
var won: bool = false
var game_started: bool = false
#snowflake respawn - every 3 cubes
var snowflake_returns: Dictionary = {}
const MAX_BONUS_TIME: float = 25.0

func _ready() -> void:
	starting_position = cube.position

	window.body_entered.connect(_on_window_reached)
	freezer.body_entered.connect(_on_freezer_entered)
	freezer.body_exited.connect(_on_freezer_exited)

	for child in get_children():
		if child is Area2D and child.name.begins_with("Snowflake"):
			child.body_entered.connect(
				_on_snowflake_collected.bind(child)
			)
		elif child is Area2D and child.name.begins_with("flame"):
			child.body_entered.connect(_on_flame_touched)
	cube.set_physics_process(false)
	start_screen.show()
	win_screen.hide()
	
func _process(delta: float) -> void:
	if not game_started or won or respawning:
		return

	if in_freezer:
		timer_label.text = "Cube %d  |  Safe in freezer  |  Next cube: %.0fs" % [
		cube_number, initial_cube_time + bonus_time
		]
		return
	time_left -= delta

	if time_left <= 0:
		_respawn_cube()
		return

	timer_label.text = "Cube %d  |  Melt: %.1fs  |  Next cube: %.0fs" % [cube_number, time_left, initial_cube_time + bonus_time
	]

func _respawn_cube() -> void:
	respawning = true
	timer_label.text = "Cube %d melted... forming the next cube" % cube_number
	cube.hide()
	cube.set_physics_process(false)

	await get_tree().create_timer(1.0).timeout

	cube_number += 1
	for snowflake in snowflake_returns.keys():
		if cube_number >= snowflake_returns[snowflake]:
			snowflake.show()
			snowflake.set_deferred("monitoring", true)
			snowflake_returns.erase(snowflake)
	cube.position = starting_position
	time_left = initial_cube_time + bonus_time
	in_freezer = true
	cube.show()
	cube.set_physics_process(true)
	respawning = false

func _on_freezer_entered(body: Node2D) -> void:
	if body == cube:
		in_freezer = true

func _on_freezer_exited(body: Node2D) -> void:
	if body == cube:
		in_freezer = false

func _on_snowflake_collected(body: Node2D, snowflake: Area2D) -> void:
	if body != cube or respawning or won:
		return
	if snowflake in snowflake_returns:
		return

	bonus_time = minf(bonus_time + 3.0, MAX_BONUS_TIME)
	show_bonus_popup(3)
	flash_timer()
	snowflake_returns[snowflake] = cube_number + 3
	snowflake.hide()
	snowflake.set_deferred("monitoring", false)

func _on_flame_touched(body: Node2D) -> void:
	if body == cube and not respawning and not won:
		time_left -= 3.0

func _on_window_reached(body: Node2D) -> void:
	if body != cube or respawning or won:
		return

	won = true
	var cube_word := "cube" if cube_number == 1 else "cubes"
	win_label.text += "\n\nIt took %d %s to reach the snow." % [
		cube_number, cube_word
	]
	win_screen.show()
	cube.set_physics_process(false)
	timer_label.text = "You made it to the snow!  Cubes sent: %d" % cube_number

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_accept"):
		return

	if not game_started:
		game_started = true
		start_screen.hide()
		cube.set_physics_process(true)
	elif won:
		get_tree().reload_current_scene()

func flash_timer() -> void:
	if timer_flash and timer_flash.is_running():
		timer_flash.kill()

	timer_label.modulate = Color.YELLOW
	timer_flash = create_tween()
	timer_flash.tween_property(timer_label, "modulate", Color.WHITE, 1.0)

func show_bonus_popup(seconds: int) -> void:
	if popup_tween and popup_tween.is_running():
		popup_tween.kill()

	bonus_popup.text = "+%d seconds for the next cube!" % seconds
	bonus_popup.position = cube.global_position + Vector2(-30, -50)
	bonus_popup.modulate = Color.WHITE
	bonus_popup.show()

	popup_tween = create_tween()
	popup_tween.tween_interval(1.0)
	popup_tween.tween_property(bonus_popup, "modulate:a", 0.0, 1.0)
