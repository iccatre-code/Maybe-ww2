class_name NightMode
extends Node
# N = night/day, G = night vision, L = flashlight (NIGHT / NVG / LIGHT on touch).
# At night enemies see unlit targets at 45% range; a flashlight makes you visible at full range.

var env: Environment
var sun: DirectionalLight3D
var toggle_count := 0
var flash_count := 0
var nvg_count := 0


func setup(e: Environment, s: DirectionalLight3D) -> void:
    env = e
    sun = s
    apply()


func _unhandled_input(event: InputEvent) -> void:
    if Game.ended or not (event is InputEventKey) or not event.pressed or event.echo:
        return
    if event.keycode == KEY_N:
        toggle_night()
    elif event.keycode == KEY_G:
        toggle_nvg()
    elif event.keycode == KEY_L:
        toggle_flash()


func _process(_d: float) -> void:
    if Game.ended:
        return
    if Game.touch_take("night"):
        toggle_night()
    if Game.touch_take("nvg"):
        toggle_nvg()
    if Game.touch_take("light"):
        toggle_flash()


func toggle_night() -> void:
    Game.night = not Game.night
    toggle_count += 1
    apply()


func toggle_nvg() -> void:
    Game.nvg = not Game.nvg
    nvg_count += 1
    apply()


func toggle_flash() -> void:
    var p := get_parent() as Player
    p.flashlight.visible = not p.flashlight.visible
    p.lit = p.flashlight.visible
    flash_count += 1


func apply() -> void:
    if env == null:
        return
    if Game.night:
        sun.light_energy = 0.04
        env.ambient_light_color = Color(0.22, 0.5, 0.22) if Game.nvg else Color(0.04, 0.05, 0.1)
        env.background_color = Color(0.01, 0.01, 0.04)
        env.fog_enabled = true
        env.fog_light_color = Color(0.02, 0.02, 0.05)
        env.fog_density = 0.012
    else:
        sun.light_energy = 1.0
        env.ambient_light_color = Color(0.55, 0.55, 0.55)
        env.background_color = Color(0.55, 0.72, 0.9)
        env.fog_enabled = false
