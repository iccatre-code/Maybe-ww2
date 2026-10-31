class_name Player
extends Unit

const GRAVITY := 20.0

var cam: Camera3D
var flashlight: SpotLight3D
var shape: CapsuleShape3D
var col: CollisionShape3D
var pitch := 0.0
var stance := 0          # 0 stand, 1 crouch, 2 prone
var height := 1.8
var aiming := false
var prev_fire := false
var pending := {}

# flags read by the tutorial
var has_moved := false
var has_sprinted := false
var has_jumped := false
var has_crouched := false
var has_proned := false
var has_aimed := false


func head_height() -> float:
    return height


func _ready() -> void:
    is_player = true
    add_to_group("units")
    shape = CapsuleShape3D.new()
    shape.radius = 0.35
    shape.height = 1.8
    col = CollisionShape3D.new()
    col.shape = shape
    col.position = Vector3(0, 0.9, 0)
    add_child(col)

    cam = Camera3D.new()
    cam.position = Vector3(0, 1.6, 0)
    cam.fov = 70.0
    cam.near = 0.05
    cam.far = 250.0
    add_child(cam)
    cam.make_current()

    var gun := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = Vector3(0.08, 0.12, 0.6)
    gun.mesh = bm
    gun.material_override = Game.mat(Color(0.1, 0.1, 0.1))
    gun.position = Vector3(0.2, -0.2, -0.45)
    cam.add_child(gun)

    flashlight = SpotLight3D.new()
    flashlight.spot_range = 40.0
    flashlight.spot_angle = 30.0
    flashlight.light_energy = 3.0
    flashlight.visible = false
    cam.add_child(flashlight)

    var w := Weapon.new()
    add_child(w)
    w.equip(load("res://data/rifle.tres") as WeaponData)
    weapon = w

    if not Game.is_touch():
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _take(n: String) -> bool:
    var r: bool = pending.get(n, false)
    pending[n] = false
    if Game.touch_take(n):
        r = true
    return r


func _unhandled_input(event: InputEvent) -> void:
    if Game.is_touch() or is_dead() or Game.ended:
        return
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        rotate_y(-event.relative.x * 0.0025)
        pitch = clampf(pitch - event.relative.y * 0.0025, -1.48, 1.48)
        cam.rotation.x = pitch
    elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    elif event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_ESCAPE:
                Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
            KEY_C:
                pending["crouch"] = true
            KEY_Z:
                pending["prone"] = true
            KEY_R:
                pending["reload"] = true
            KEY_SPACE:
                pending["jump"] = true


func _set_stance(s: int) -> void:
    stance = s
    if s == 1:
        has_crouched = true
    if s == 2:
        has_proned = true


func _physics_process(delta: float) -> void:
    if is_dead() or Game.ended:
        return
    var tu = Game.touch_ui
    var use_touch: bool = Game.is_touch() and tu != null
    var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
    var active: bool = use_touch or captured

    # recoil + touch look
    rotate_y(deg_to_rad(weapon.pending_recoil.x))
    pitch = clampf(pitch + deg_to_rad(weapon.pending_recoil.y), -1.48, 1.48)
    weapon.pending_recoil = Vector2.ZERO
    if use_touch:
        var l: Vector2 = tu.look
        tu.look = Vector2.ZERO
        rotate_y(-l.x * 0.004)
        pitch = clampf(pitch - l.y * 0.004, -1.48, 1.48)
    cam.rotation.x = pitch

    # stance
    if active:
        if _take("crouch"):
            _set_stance(0 if stance == 1 else 1)
        if _take("prone"):
            _set_stance(0 if stance == 2 else 2)

    # movement
    var mv := Vector2.ZERO
    if use_touch:
        mv = tu.move
    elif captured:
        mv.x = float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
        mv.y = float(Input.is_key_pressed(KEY_W)) - float(Input.is_key_pressed(KEY_S))
    mv = mv.limit_length(1.0)
    var want_sprint: bool = (use_touch and mv.y > 0.95) or (not use_touch and Input.is_key_pressed(KEY_SHIFT))
    var sprint: bool = want_sprint and stance == 0 and mv.y > 0.1 and not aiming
    var speed := 4.2
    if stance == 1:
        speed = 2.2
    elif stance == 2:
        speed = 1.0
    elif sprint:
        speed = 7.0
    if weapon.reloading:
        speed *= 0.85
    var moving := mv.length_squared() > 0.01
    if moving:
        has_moved = true
    if sprint and moving:
        has_sprinted = true
    var dir := transform.basis.x * mv.x + (-transform.basis.z) * mv.y
    velocity.x = dir.x * speed
    velocity.z = dir.z * speed
    if is_on_floor():
        if active and _take("jump") and stance == 0:
            velocity.y = sqrt(2.0 * GRAVITY * 1.1)
            has_jumped = true
        else:
            velocity.y = 0.0
    else:
        velocity.y -= GRAVITY * delta
        pending["jump"] = false
    move_and_slide()

    # body height
    var th := 1.8
    if stance == 1:
        th = 1.2
    elif stance == 2:
        th = 0.8
    height = move_toward(height, th, 6.0 * delta)
    shape.height = height
    col.position.y = height / 2.0
    cam.position.y = height - 0.2

    # aim, fire, reload
    if use_touch:
        aiming = tu.is_held("aim")
    else:
        aiming = captured and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
    if aiming:
        has_aimed = true
    cam.fov = lerpf(cam.fov, 48.0 if aiming else 70.0, minf(1.0, 12.0 * delta))
    var fire := false
    if use_touch:
        fire = tu.is_held("fire")
    elif captured:
        fire = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
    if fire and (weapon.data.automatic or not prev_fire):
        var sm := (0.4 if aiming else 1.0) * (1.6 if moving else 1.0)
        if stance == 1:
            sm *= 0.8
        elif stance == 2:
            sm *= 0.6
        weapon.try_fire(cam.global_position, -cam.global_transform.basis.z, sm, 1.0, self)
    prev_fire = fire
    if active and _take("reload"):
        weapon.start_reload()
