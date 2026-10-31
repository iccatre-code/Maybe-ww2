class_name Weapon
extends Node3D
# Used by the player and every AI soldier.

signal hit_marker(kill)

var data: WeaponData
var ammo := 30
var reserve := 120
var reloading := false
var reload_count := 0
var pending_recoil := Vector2.ZERO   # x = yaw deg, y = pitch deg (consumed by Player)
var next_fire := 0.0
var _audio: AudioStreamPlayer3D
static var _clip: AudioStreamWAV = null


func _ready() -> void:
    if _clip == null:
        _clip = _make_clip()
    _audio = AudioStreamPlayer3D.new()
    _audio.stream = _clip
    _audio.max_distance = 80.0
    _audio.unit_size = 10.0
    add_child(_audio)
    if data == null:
        equip(load("res://data/rifle.tres") as WeaponData)


func equip(d: WeaponData) -> void:
    data = d
    ammo = d.mag_size
    reserve = d.reserve_ammo
    reloading = false


static func _make_clip() -> AudioStreamWAV:
    var rate := 22050
    var n := 3675
    var bytes := PackedByteArray()
    bytes.resize(n * 2)
    for i in n:
        var t := float(i) / float(n)
        var v := (randf() * 2.0 - 1.0) * pow(1.0 - t, 3.0) * 0.8
        bytes.encode_s16(i * 2, int(v * 32767.0))
    var w := AudioStreamWAV.new()
    w.format = AudioStreamWAV.FORMAT_16_BITS
    w.mix_rate = rate
    w.stereo = false
    w.data = bytes
    return w


func start_reload() -> void:
    if reloading or ammo >= data.mag_size or reserve <= 0:
        return
    reloading = true
    await get_tree().create_timer(data.reload_time).timeout
    if not is_inside_tree():
        return
    var take := mini(data.mag_size - ammo, reserve)
    ammo += take
    reserve -= take
    reload_count += 1
    reloading = false


func try_fire(origin: Vector3, dir: Vector3, spread_mul: float, dmg_mul: float, body: Unit) -> bool:
    var t := Game.now()
    if reloading or t < next_fire:
        return false
    if ammo <= 0:
        start_reload()
        return false
    next_fire = t + 60.0 / data.fire_rate
    ammo -= 1
    body.last_noise = t
    _audio.play()

    var space := body.get_world_3d().direct_space_state
    for p in data.pellets:
        var s := tan(deg_to_rad(data.spread_deg * spread_mul))
        var rnd := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))
        var d := (dir + rnd * s).normalized()
        var q := PhysicsRayQueryParameters3D.create(origin, origin + d * data.max_range)
        q.exclude = [body.get_rid()]
        var hit := space.intersect_ray(q)
        if hit.is_empty():
            continue
        var col: Object = hit.collider
        Game.impact(hit.position, hit.normal)
        var dmg := data.damage * dmg_mul
        if col is Unit:
            var u := col as Unit
            if u.team != body.team and not u.is_dead():
                var head: bool = hit.position.y > u.global_position.y + u.head_height() - 0.25
                u.take_damage(dmg, body, head)
                if body.is_player:
                    if u.is_dead():
                        Game.kills += 1
                    hit_marker.emit(u.is_dead())
        elif col.has_method("take_damage") and not col.is_dead():
            col.take_damage(dmg, body, false)
            if body.is_player:
                hit_marker.emit(false)

    pending_recoil += Vector2(randf_range(-1.0, 1.0) * data.recoil * 0.3, data.recoil)
    return true
