class_name HUD
extends Control

var player: Player
var hit_until := 0.0
var hit_kill := false
var t0 := 0.0
var buttons_added := false


func _ready() -> void:
    set_anchors_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    t0 = Game.now()
    player.weapon.hit_marker.connect(_on_hit)


func _on_hit(kill) -> void:
    hit_until = Game.now() + 0.2
    hit_kill = kill


func _end(text: String) -> void:
    Game.ended = true
    Game.end_text = text
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    if buttons_added:
        return
    buttons_added = true
    var vs := get_viewport_rect().size
    var b1 := Button.new()
    b1.text = "RESTART"
    b1.add_theme_font_size_override("font_size", 24)
    b1.position = Vector2(vs.x / 2 - 170, vs.y / 2 - 20)
    b1.size = Vector2(340, 60)
    b1.pressed.connect(func(): get_tree().reload_current_scene())
    add_child(b1)
    var b2 := Button.new()
    b2.text = "MAIN MENU"
    b2.add_theme_font_size_override("font_size", 24)
    b2.position = Vector2(vs.x / 2 - 170, vs.y / 2 + 50)
    b2.size = Vector2(340, 60)
    b2.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
    add_child(b2)


func _process(_d: float) -> void:
    queue_redraw()
    if Game.ended or player == null:
        return
    if player.is_dead():
        _end("YOU DIED")
    elif Game.battle_mode and Game.now() - t0 > 3.0 and Game.alive_count(1) == 0:
        _end("VICTORY")


func _bar(x: float, y: float, w: float, h: float, frac: float, c: Color, text: String) -> void:
    draw_rect(Rect2(x, y, w, h), Color(0, 0, 0, 0.55))
    draw_rect(Rect2(x, y, w * clampf(frac, 0.0, 1.0), h), c)
    draw_string(ThemeDB.fallback_font, Vector2(x + 6, y + h - 3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)


func _draw() -> void:
    if player == null:
        return
    var vs := get_viewport_rect().size
    var W := vs.x
    var H := vs.y
    var f := ThemeDB.fallback_font
    var wp = player.weapon

    if Game.nvg:
        draw_rect(Rect2(0, 0, W, H), Color(0, 0.9, 0.2, 0.16))

    # crosshair + hit marker
    draw_rect(Rect2(W / 2 - 1, H / 2 - 9, 2, 18), Color(1, 1, 1, 0.8))
    draw_rect(Rect2(W / 2 - 9, H / 2 - 1, 18, 2), Color(1, 1, 1, 0.8))
    if Game.now() < hit_until:
        draw_string(f, Vector2(W / 2 - 12, H / 2 + 14), "X", HORIZONTAL_ALIGNMENT_LEFT, -1, 36,
            Color.RED if hit_kill else Color.WHITE)

    _bar(20, 16, 260, 18, player.health / player.max_health, Color(0.8, 0.2, 0.2), "HP %d" % ceili(player.health))
    var af := player.armor / player.max_armor if player.max_armor > 0.0 else 0.0
    _bar(20, 40, 260, 14, af, Color(0.25, 0.45, 0.9), "ARMOR %d" % ceili(player.armor))

    var ammo := "RELOADING..." if wp.reloading else "%d / %d" % [wp.ammo, wp.reserve]
    draw_string(f, Vector2(W - 420, 30), wp.data.weapon_name + "   " + ammo, HORIZONTAL_ALIGNMENT_RIGHT, 400, 20, Color.WHITE)
    var info := "KILLS: %d" % Game.kills
    for c in player.get_children():
        if c is SquadCommander:
            info = "ORDER: %s   " % ["NONE", "FOLLOW", "DEFEND", "ATTACK", "HOLD", "REGROUP"][c.current] + info
    if Game.battle_mode:
        info += "   ENEMIES: %d" % Game.alive_count(1)
    draw_string(f, Vector2(W - 520, 56), info, HORIZONTAL_ALIGNMENT_RIGHT, 500, 18, Color.WHITE)
    for c in player.get_children():
        if c is ReinforcementCaller and c.status != "":
            draw_string(f, Vector2(W / 2 - 250, H - 60), c.status, HORIZONTAL_ALIGNMENT_CENTER, 500, 20, Color.WHITE)
    if Game.night:
        draw_string(f, Vector2(20, 76), "NIGHT", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
    if not Game.is_touch():
        draw_string(f, Vector2(20, H - 14),
            "F1-F5 squad | T cycle | B reinforce | V supply | N night | G NVG | L light | C crouch | Z prone | ESC mouse",
            HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.8))

    if Game.ended and Game.end_text != "":
        draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.7))
        draw_string(f, Vector2(0, H / 2 - 70), Game.end_text, HORIZONTAL_ALIGNMENT_CENTER, W, 48, Color.WHITE)
