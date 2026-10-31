class_name Tutorial
extends Control
# Step-by-step training with live objective detection. Progress saved in user://if.cfg.

var player: Player
var station_pos := Vector3.ZERO
var steps: Array[Dictionary] = []
var index := 0
var finished := false
var done_at := -1.0
var base_a := 0
var base_b := 0
var enemy: Soldier = null


static func _c(pc: String, touch: String) -> String:
    return touch if Game.is_touch() else pc


func _add(lesson: String, text: String, done: Callable, enter: Callable = Callable()) -> void:
    steps.append({"lesson": lesson, "text": text, "done": done, "enter": enter})


func _find(cls) -> Node:
    for c in player.get_children():
        if is_instance_of(c, cls):
            return c
    return null


func _ready() -> void:
    set_anchors_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    var squad := _find(SquadCommander) as SquadCommander
    var night := _find(NightMode) as NightMode
    var reinf := _find(ReinforcementCaller) as ReinforcementCaller

    var L1 := "LESSON 1: MOVEMENT"
    var L2 := "LESSON 2: WEAPONS"
    var L3 := "LESSON 3: SQUAD"
    var L4 := "LESSON 4: SUPPLY"
    var L5 := "LESSON 5: NIGHT WARFARE"
    var L6 := "LESSON 6: COMBAT"

    _add(L1, _c("Move with W A S D", "Drag on the left side of the screen to move"), func(): return player.has_moved)
    _add(L1, _c("Sprint: hold SHIFT and move forward", "Sprint: push the stick fully forward"), func(): return player.has_sprinted)
    _add(L1, _c("Jump: press SPACE", "Jump: tap JUMP"), func(): return player.has_jumped)
    _add(L1, _c("Crouch: press C", "Crouch: tap CROUCH"), func(): return player.has_crouched)
    _add(L1, _c("Go prone: press Z", "Go prone: tap PRONE"), func(): return player.stance == 2)
    _add(L1, _c("Stand up: press Z again", "Stand up: tap PRONE again"), func(): return player.stance == 0)

    _add(L2, _c("Aim down sights: hold RIGHT MOUSE", "Aim: hold AIM"), func(): return player.has_aimed)
    _add(L2, _c("Shoot 3 orange targets: LEFT MOUSE", "Shoot 3 orange targets: hold FIRE"),
        func(): return PracticeTarget.down_count - base_a >= 3,
        func(): base_a = PracticeTarget.down_count)
    _add(L2, _c("Fire a few rounds, then reload: R", "Fire a few rounds, then tap RELOAD"),
        func(): return player.weapon.reload_count > base_b,
        func(): base_b = player.weapon.reload_count)

    _add(L3, _c("Order your squad: F1-F5 or T (look at a spot for Attack/Defend)", "Order your squad: tap CMD (cycles orders)"),
        func(): return squad.issued_count > 0)

    _add(L4, "Walk into the green supply station to heal and resupply",
        func(): return player.global_position.distance_to(station_pos) < 3.5)
    _add(L4, _c("Call a supply drop: V", "Call a supply drop: tap DROP"), func(): return reinf.supply_calls > 0)
    _add(L4, _c("Call reinforcements: B", "Call reinforcements: tap CALL"), func(): return reinf.reinf_calls > 0)

    _add(L5, _c("Switch to night: N", "Switch to night: tap NIGHT"), func(): return night.toggle_count > 0)
    _add(L5, _c("Flashlight: L", "Flashlight: tap LIGHT"), func(): return night.flash_count > 0)
    _add(L5, _c("Night vision: G", "Night vision: tap NVG"), func(): return night.nvg_count > 0)

    _add(L6, "Defeat the enemy soldier ahead (N switches back to day)",
        func(): return enemy == null or not is_instance_valid(enemy) or enemy.is_dead(),
        func():
            var p := player.global_position + (-player.global_transform.basis.z) * 22.0
            enemy = SoldierFactory.spawn(p, 1, Game.Diff.EASY, null))

    var skip := Button.new()
    skip.text = "SKIP (ESC frees mouse)"
    skip.add_theme_font_size_override("font_size", 16)
    skip.position = Vector2(20, 80)
    skip.size = Vector2(220, 40)
    skip.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
    add_child(skip)

    _enter(steps[0])


func _enter(s: Dictionary) -> void:
    var e: Callable = s["enter"]
    if e.is_valid():
        e.call()


func _process(_d: float) -> void:
    queue_redraw()
    if finished or (Game.ended and Game.end_text != ""):
        return
    if done_at < 0.0:
        var d: Callable = steps[index]["done"]
        if d.call():
            done_at = Game.now() + 0.9
    elif Game.now() >= done_at:
        index += 1
        done_at = -1.0
        Game.cset("tutorial_step", index)
        if index >= steps.size():
            _finish()
        else:
            _enter(steps[index])


func _finish() -> void:
    finished = true
    Game.ended = true
    Game.end_text = ""
    Game.cset("tutorial_done", true)
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    var vs := get_viewport_rect().size
    var b1 := Button.new()
    b1.text = "REPLAY TRAINING"
    b1.add_theme_font_size_override("font_size", 24)
    b1.position = Vector2(vs.x / 2 - 170, vs.y / 2 - 20)
    b1.size = Vector2(340, 60)
    b1.pressed.connect(func():
        Game.cset("tutorial_step", 0)
        get_tree().reload_current_scene())
    add_child(b1)
    var b2 := Button.new()
    b2.text = "MAIN MENU"
    b2.add_theme_font_size_override("font_size", 24)
    b2.position = Vector2(vs.x / 2 - 170, vs.y / 2 + 50)
    b2.size = Vector2(340, 60)
    b2.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
    add_child(b2)


func _draw() -> void:
    var vs := get_viewport_rect().size
    var f := ThemeDB.fallback_font
    if finished:
        draw_rect(Rect2(0, 0, vs.x, vs.y), Color(0, 0, 0, 0.7))
        draw_string(f, Vector2(0, vs.y / 2 - 70), "TRAINING COMPLETE", HORIZONTAL_ALIGNMENT_CENTER, vs.x, 44, Color.WHITE)
        return
    var pw := 640.0
    var px := vs.x / 2.0 - pw / 2.0
    draw_rect(Rect2(px, 70, pw, 92), Color(0, 0, 0, 0.6))
    var s := steps[mini(index, steps.size() - 1)]
    var head := "%s   (%d/%d)%s" % [s["lesson"], index + 1, steps.size(), "   DONE" if done_at >= 0.0 else ""]
    draw_string(f, Vector2(px + 10, 92), head, HORIZONTAL_ALIGNMENT_LEFT, pw - 20, 16, Color(0.8, 0.9, 0.6))
    draw_multiline_string(f, Vector2(px + 10, 120), s["text"], HORIZONTAL_ALIGNMENT_LEFT, pw - 20, 22, 2, Color.WHITE)
