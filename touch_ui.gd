class_name TouchUI
extends Control
# Phone controls: left side = virtual stick, right side = look, plus on-screen buttons.

const NAMES := ["fire", "aim", "reload", "jump", "crouch", "prone", "cmd", "call", "drop", "night", "nvg", "light"]
const LABELS := ["FIRE", "AIM", "RELOAD", "JUMP", "CROUCH", "PRONE", "CMD", "CALL", "DROP", "NIGHT", "NVG", "LIGHT"]

var enabled := false
var move := Vector2.ZERO     # x right, y forward
var look := Vector2.ZERO     # pixel deltas, consumed by Player
var pressed := {}
var held := {}
var rects: Array[Rect2] = []
var finger_btn := {}
var move_id := -1
var look_id := -1
var move_origin := Vector2.ZERO
var move_cur := Vector2.ZERO


func _ready() -> void:
    set_anchors_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    enabled = Game.is_touch()
    Game.touch_ui = self
    for n in NAMES:
        held[n] = false
        pressed[n] = false
    rects.resize(NAMES.size())


func _exit_tree() -> void:
    if Game.touch_ui == self:
        Game.touch_ui = null


func take(n: String) -> bool:
    var r: bool = pressed.get(n, false)
    pressed[n] = false
    return r


func is_held(n: String) -> bool:
    return held.get(n, false)


func _r(x: float, yb: float, w: float, h: float, H: float) -> Rect2:
    return Rect2(x, H - yb - h, w, h)


func _layout() -> void:
    var vs := get_viewport_rect().size
    var W := vs.x
    var H := vs.y
    var s := H * 0.14
    rects[0] = _r(W - 1.7 * s, 1.0 * s, 1.5 * s, 1.5 * s, H)   # fire
    rects[1] = _r(W - 3.1 * s, 0.9 * s, 1.3 * s, 1.0 * s, H)   # aim
    rects[2] = _r(W - 3.1 * s, 2.0 * s, 1.3 * s, 0.9 * s, H)   # reload
    rects[3] = _r(W - 1.3 * s, 0.1 * s, 1.1 * s, 0.8 * s, H)   # jump
    rects[4] = _r(W - 4.5 * s, 0.9 * s, 1.3 * s, 0.9 * s, H)   # crouch
    rects[5] = _r(W - 4.5 * s, 2.0 * s, 1.3 * s, 0.9 * s, H)   # prone
    var ty := H - 2.0 * s
    for i in 6:
        rects[6 + i] = Rect2(W - (1.5 + 1.5 * i) * s, H - ty - 0.8 * s, 1.4 * s, 0.8 * s)
    # top-right row sits below the HUD text


func _hit(p: Vector2) -> int:
    for i in rects.size():
        if rects[i].has_point(p):
            return i
    return -1


func _input(e: InputEvent) -> void:
    if not enabled:
        return
    _layout()
    var vs := get_viewport_rect().size
    if e is InputEventScreenTouch:
        if e.pressed:
            var h := _hit(e.position)
            if h >= 0:
                held[NAMES[h]] = true
                pressed[NAMES[h]] = true
                finger_btn[e.index] = h
            elif e.position.x < vs.x * 0.4 and move_id < 0:
                move_id = e.index
                move_origin = e.position
                move_cur = e.position
            elif look_id < 0:
                look_id = e.index
        else:
            if finger_btn.has(e.index):
                held[NAMES[finger_btn[e.index]]] = false
                finger_btn.erase(e.index)
            if e.index == move_id:
                move_id = -1
                move = Vector2.ZERO
            if e.index == look_id:
                look_id = -1
    elif e is InputEventScreenDrag:
        if e.index == move_id:
            move_cur = e.position
            var d := (move_cur - move_origin) / (vs.y * 0.12)
            move = Vector2(d.x, -d.y).limit_length(1.0)
        elif e.index == look_id:
            look += e.relative


func _process(_d: float) -> void:
    if enabled:
        queue_redraw()


func _draw() -> void:
    if not enabled:
        return
    _layout()
    var f := ThemeDB.fallback_font
    var fs := int(get_viewport_rect().size.y * 0.032)
    for i in rects.size():
        var r := rects[i]
        var on: bool = held[NAMES[i]]
        draw_rect(r, Color(1, 1, 1, 0.5 if on else 0.2))
        draw_rect(r, Color(1, 1, 1, 0.6), false, 2.0)
        draw_string(f, Vector2(r.position.x, r.position.y + r.size.y * 0.5 + fs * 0.35), LABELS[i],
            HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, Color.WHITE)
    if move_id >= 0:
        var rad := get_viewport_rect().size.y * 0.12
        draw_arc(move_origin, rad, 0.0, TAU, 32, Color(1, 1, 1, 0.4), 3.0)
        var k := move_origin + (move_cur - move_origin).limit_length(rad)
        draw_circle(k, rad * 0.4, Color(1, 1, 1, 0.5))
