extends Control

var enemies_label: Label
var allies_label: Label
var seed_label: Label


func _lab(text: String, size := 20) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", size)
    return l


func _btn(text: String, cb: Callable, disabled := false) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(360, 64)
    b.add_theme_font_size_override("font_size", 24)
    b.disabled = disabled
    if not disabled:
        b.pressed.connect(cb)
    return b


func _ready() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    Game.apply_quality()
    set_anchors_preset(Control.PRESET_FULL_RECT)

    var bg := ColorRect.new()
    bg.color = Color(0.07, 0.09, 0.07)
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(bg)

    var center := CenterContainer.new()
    center.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(center)
    var outer := VBoxContainer.new()
    outer.add_theme_constant_override("separation", 24)
    center.add_child(outer)

    var title := _lab("OPERATION: IRON FRONT", 44)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    outer.add_child(title)

    var cols := HBoxContainer.new()
    cols.add_theme_constant_override("separation", 60)
    outer.add_child(cols)

    var left := VBoxContainer.new()
    left.add_theme_constant_override("separation", 10)
    cols.add_child(left)
    left.add_child(_btn("PLAY", func(): get_tree().change_scene_to_file("res://scenes/battlefield.tscn")))
    var tt := "TRAINING (REPLAY)" if Game.cget("tutorial_done", false) else "TRAINING"
    left.add_child(_btn(tt, func(): get_tree().change_scene_to_file("res://scenes/training.tscn")))
    left.add_child(_btn("MULTIPLAYER (PHASE 6)", Callable(), true))
    left.add_child(_btn("LOADOUT (LATER)", Callable(), true))
    left.add_child(_btn("QUIT", func(): get_tree().quit()))

    var right := VBoxContainer.new()
    right.add_theme_constant_override("separation", 8)
    right.custom_minimum_size = Vector2(420, 0)
    cols.add_child(right)

    right.add_child(_lab("ENEMY DIFFICULTY"))
    var diff := OptionButton.new()
    for n in ["EASY", "NORMAL", "HARD", "EXTREME"]:
        diff.add_item(n)
    diff.selected = Game.difficulty
    diff.add_theme_font_size_override("font_size", 20)
    diff.item_selected.connect(func(i): Game.difficulty = i)
    right.add_child(diff)

    right.add_child(_lab("GRAPHICS"))
    var q := OptionButton.new()
    for n in ["LOW", "MEDIUM", "HIGH"]:
        q.add_item(n)
    q.selected = Game.get_quality()
    q.add_theme_font_size_override("font_size", 20)
    q.item_selected.connect(func(i): Game.set_quality(i))
    right.add_child(q)

    enemies_label = _lab("ENEMIES: %d" % Game.enemy_count)
    right.add_child(enemies_label)
    var es := HSlider.new()
    es.min_value = 1
    es.max_value = 32
    es.step = 1
    es.value = Game.enemy_count
    es.custom_minimum_size = Vector2(0, 28)
    es.value_changed.connect(func(v):
        Game.enemy_count = int(v)
        enemies_label.text = "ENEMIES: %d" % Game.enemy_count)
    right.add_child(es)

    allies_label = _lab("ALLIES: %d" % Game.ally_count)
    right.add_child(allies_label)
    var als := HSlider.new()
    als.min_value = 0
    als.max_value = 8
    als.step = 1
    als.value = Game.ally_count
    als.custom_minimum_size = Vector2(0, 28)
    als.value_changed.connect(func(v):
        Game.ally_count = int(v)
        allies_label.text = "ALLIES: %d" % Game.ally_count)
    right.add_child(als)

    seed_label = _lab("MAP SEED: %d" % Game.map_seed)
    right.add_child(seed_label)
    var sb := Button.new()
    sb.text = "NEW SEED"
    sb.add_theme_font_size_override("font_size", 18)
    sb.pressed.connect(func():
        Game.map_seed = randi_range(1, 99999)
        seed_label.text = "MAP SEED: %d" % Game.map_seed)
    right.add_child(sb)
