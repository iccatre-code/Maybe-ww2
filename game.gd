extends Node
# Autoload "Game": settings, round state, helpers, pooled bullet-impact markers.

enum Diff { EASY, NORMAL, HARD, EXTREME }
enum Order { NONE, FOLLOW, DEFEND, ATTACK, HOLD, REGROUP }

var difficulty: int = 1
var enemy_count := 6
var ally_count := 3
var map_seed := 12345

var kills := 0
var ended := false
var end_text := ""
var battle_mode := false
var night := false
var nvg := false

var world: Node3D = null      # parent for spawned soldiers / stations
var touch_ui = null           # TouchUI instance on phones

var cfg := ConfigFile.new()
var _pool: Array[MeshInstance3D] = []
var _pool_exp: Array[float] = []
var _pool_idx := 0


func _ready() -> void:
    cfg.load("user://if.cfg")
    apply_quality()
    for i in 32:
        var m := MeshInstance3D.new()
        var s := SphereMesh.new()
        s.radius = 0.07
        s.height = 0.14
        m.mesh = s
        m.material_override = mat(Color(0.12, 0.12, 0.12))
        m.visible = false
        add_child(m)
        _pool.append(m)
        _pool_exp.append(0.0)


func _process(_delta: float) -> void:
    var t := now()
    for i in _pool.size():
        if _pool[i].visible and t > _pool_exp[i]:
            _pool[i].visible = false


func now() -> float:
    return Time.get_ticks_msec() / 1000.0


func is_touch() -> bool:
    return OS.has_feature("mobile")


func cget(key: String, default_value):
    return cfg.get_value("main", key, default_value)


func cset(key: String, value) -> void:
    cfg.set_value("main", key, value)
    cfg.save("user://if.cfg")


func get_quality() -> int:
    return int(cget("quality", 1))


func set_quality(q: int) -> void:
    cset("quality", q)
    apply_quality()


func max_ai() -> int:
    var caps := [8, 16, 32]
    return int(caps[get_quality()])


func apply_quality() -> void:
    var q := get_quality()
    Engine.max_fps = 30 if q == 0 else 60
    get_viewport().msaa_3d = Viewport.MSAA_4X if q == 2 else Viewport.MSAA_DISABLED


func reset_round() -> void:
    kills = 0
    ended = false
    end_text = ""
    night = false
    nvg = false
    PracticeTarget.down_count = 0


func touch_take(n: String) -> bool:
    return touch_ui != null and touch_ui.take(n)


func alive_count(team: int) -> int:
    var c := 0
    for n in get_tree().get_nodes_in_group("units"):
        var u := n as Unit
        if u != null and u.team == team and not u.is_dead():
            c += 1
    return c


func mat(c: Color) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    return m


func impact(pos: Vector3, normal: Vector3) -> void:
    if _pool.is_empty():
        return
    var m := _pool[_pool_idx]
    m.visible = true
    m.global_position = pos + normal * 0.02
    _pool_exp[_pool_idx] = now() + 2.0
    _pool_idx = (_pool_idx + 1) % _pool.size()
