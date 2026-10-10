extends RefCounted

# FLOOR 1-9 enemy AI authority.
# Shared shape / line-of-sight logic is centralized in enemy_geometry.gd and exposed through main.gd wrappers.

const SFX_ENEMY_WARN := &"enemy_warn"
const SFX_ENEMY_MELEE := &"enemy_melee"
const SFX_TURRET_WARN := &"turret_warn"
const SFX_TURRET_FIRE := &"turret_fire"
const SFX_CHARGER_WARN := &"charger_warn"
const SFX_CHARGER_CHARGE := &"charger_charge"
const SFX_ARTILLERY_WARN := &"artillery_warn"
const SFX_ARTILLERY_FIRE := &"artillery_fire"
const SFX_CROSS_WARN := &"cross_warn"
const SFX_CROSS_FIRE := &"cross_fire"
const SFX_TANK_WARN := &"tank_warn"
const SFX_TANK_COUNT := &"tank_count"
const SFX_TANK_FIRE := &"tank_fire"

func take_turn(host) -> void:
    var occupied: Dictionary = {}
    for e in host.enemies:
        for cell in host._enemy_cells(e):
            occupied[cell] = true

    for i in range(host.enemies.size()):
        if i >= host.enemies.size():
            break
        var ep: Vector2i = host.enemies[i]["pos"]
        var enemy_type: String = str(host.enemies[i].get("type", "chaser"))

        if enemy_type == "serpent":
            _serpent_take_turn(host, i, ep, occupied)
            if host.hp <= 0:
                return
            continue

        if enemy_type == "long_serpent":
            _long_serpent_take_turn(host, i, occupied)
            if host.hp <= 0:
                return
            continue

        if enemy_type == "heavy":
            _heavy_take_turn(host, i, ep, occupied)
            if host.hp <= 0:
                return
            continue

        if enemy_type == "artillery":
            _artillery_take_turn(host, i, ep)
            for cell in host._enemy_cells(host.enemies[i]):
                occupied[cell] = true
            if host.hp <= 0:
                return
            continue

        if enemy_type == "tank":
            _tank_take_turn(host, i, ep, occupied)
            if host.hp <= 0:
                return
            continue

        if enemy_type == "cross_discharge":
            _cross_discharge_take_turn(host, i, ep, occupied)
            if host.hp <= 0:
                return
            continue

        if enemy_type == "turret":
            _turret_take_turn(host, i, ep)
            occupied[ep] = true
            if host.hp <= 0:
                return
            continue

        if enemy_type == "charger":
            _charger_take_turn(host, i, ep, occupied)
            if host.hp <= 0:
                return
            continue

        if enemy_type == "runner":
            _runner_take_turn(host, i, ep, occupied)
            continue

        # 前の敵ターンに予告した1マスを攻撃する。
        # プレイヤーが移動しても攻撃先は追尾しない。
        if bool(host.enemies[i]["telegraph_active"]):
            var telegraph_target: Vector2i = host.enemies[i]["telegraph_target"]
            _enemy_attack(host, ep, telegraph_target, enemy_type)
            host.enemies[i]["telegraph_active"] = false
            occupied[ep] = true
            if host.hp <= 0:
                return
            continue

        occupied.erase(ep)

        # 隣接していたら、このターンは攻撃せず前方1マスを予告する。
        if host._manhattan(ep, host.player_pos) == 1:
            var attack_dir: Vector2i = host.player_pos - ep
            host.enemies[i]["facing"] = attack_dir
            host.enemies[i]["telegraph_target"] = ep + attack_dir
            host.enemies[i]["telegraph_active"] = true
            host._play_sfx(SFX_ENEMY_WARN)
            occupied[ep] = true
            continue

        # 予告中でなければ1マス接近する。移動と予告は同じターンには行わない。
        var next: Vector2i = host._next_step_toward(ep, host.player_pos, occupied)
        if next != ep and next != host.player_pos:
            host.enemies[i]["facing"] = next - ep
            host.enemies[i]["pos"] = next
            ep = next
        occupied[ep] = true



func _serpent_take_turn(host, index: int, head_pos: Vector2i, occupied: Dictionary) -> void:
    var tail_pos: Vector2i = host.enemies[index]["tail"]

    # 予告済みなら頭の前1マスを攻撃する。胴体は攻撃しない。
    if bool(host.enemies[index]["telegraph_active"]):
        var target: Vector2i = host.enemies[index]["telegraph_target"]
        _enemy_attack(host, head_pos, target, "serpent")
        host.enemies[index]["telegraph_active"] = false
        occupied[head_pos] = true
        occupied[tail_pos] = true
        return

    occupied.erase(head_pos)
    occupied.erase(tail_pos)

    # 頭が隣接していたら通常敵と同じ1マス攻撃を予告。
    if host._manhattan(head_pos, host.player_pos) == 1:
        var attack_dir: Vector2i = host.player_pos - head_pos
        host.enemies[index]["facing"] = attack_dir
        host.enemies[index]["telegraph_target"] = head_pos + attack_dir
        host.enemies[index]["telegraph_active"] = true
        host._play_sfx(SFX_ENEMY_WARN)
        occupied[head_pos] = true
        occupied[tail_pos] = true
        return

    # 2マス敵なので、頭は直前の胴体位置へ即座に反転しない。
    # 頭が1マス進むと、胴体は必ず直前の頭位置へ追従する。
    var path_occupied: Dictionary = occupied.duplicate()
    path_occupied[tail_pos] = true
    var next_head: Vector2i = host._next_step_toward(head_pos, host.player_pos, path_occupied)
    if next_head != head_pos and next_head != host.player_pos:
        host.enemies[index]["facing"] = next_head - head_pos
        host.enemies[index]["tail"] = head_pos
        host.enemies[index]["pos"] = next_head
        tail_pos = head_pos
        head_pos = next_head

    occupied[head_pos] = true
    occupied[tail_pos] = true


func _long_serpent_take_turn(host, index: int, occupied: Dictionary) -> void:
    var raw_segments: Array = host.enemies[index].get("segments", [])
    if raw_segments.size() < 5:
        return
    var segments: Array[Vector2i] = []
    for item in raw_segments:
        segments.append(Vector2i(item))
    var head_pos: Vector2i = segments[0]

    # 予告済みなら頭の前1マスを攻撃する。胴体4マスは攻撃しない。
    if bool(host.enemies[index]["telegraph_active"]):
        var target: Vector2i = host.enemies[index]["telegraph_target"]
        _enemy_attack(host, head_pos, target, "long_serpent")
        host.enemies[index]["telegraph_active"] = false
        for cell in segments:
            occupied[cell] = true
        return

    for cell in segments:
        occupied.erase(cell)

    # 頭が隣接していれば通常敵と同じ前1マス攻撃を予告する。
    if host._manhattan(head_pos, host.player_pos) == 1:
        var attack_dir: Vector2i = host.player_pos - head_pos
        host.enemies[index]["facing"] = attack_dir
        host.enemies[index]["telegraph_target"] = head_pos + attack_dir
        host.enemies[index]["telegraph_active"] = true
        host._play_sfx(SFX_ENEMY_WARN)
        for cell in segments:
            occupied[cell] = true
        return

    # 頭だけが経路探索し、胴体4マスは直前の各節位置へ順番に追従する。
    # 自分の胴体へ頭が入り込む動きは許可しない。
    var path_occupied: Dictionary = occupied.duplicate()
    for k in range(1, segments.size()):
        path_occupied[segments[k]] = true
    var next_head: Vector2i = host._next_step_toward(head_pos, host.player_pos, path_occupied)
    if next_head != head_pos and next_head != host.player_pos:
        var next_segments: Array[Vector2i] = [next_head]
        for k in range(segments.size() - 1):
            next_segments.append(segments[k])
        host.enemies[index]["segments"] = next_segments
        host.enemies[index]["pos"] = next_head
        host.enemies[index]["facing"] = next_head - head_pos
        segments = next_segments

    for cell in segments:
        occupied[cell] = true


func _heavy_take_turn(host, index: int, top_left: Vector2i, occupied: Dictionary) -> void:
    var current_cells: Array[Vector2i] = host._heavy_cells(top_left)

    # 予告済みなら固定された1マスを攻撃する。
    if bool(host.enemies[index]["telegraph_active"]):
        var target: Vector2i = host.enemies[index]["telegraph_target"]
        _enemy_attack(host, top_left, target, "heavy")
        host.enemies[index]["telegraph_active"] = false
        for cell in current_cells:
            occupied[cell] = true
        return

    # 4マスのどこかに隣接していれば、そのプレイヤーマスを予告する。
    var adjacent_cell := Vector2i.ZERO
    var is_adjacent := false
    for cell in current_cells:
        if host._manhattan(cell, host.player_pos) == 1:
            adjacent_cell = cell
            is_adjacent = true
            break
    if is_adjacent:
        host.enemies[index]["facing"] = host.player_pos - adjacent_cell
        host.enemies[index]["telegraph_target"] = host.player_pos
        host.enemies[index]["telegraph_active"] = true
        host._play_sfx(SFX_ENEMY_WARN)
        for cell in current_cells:
            occupied[cell] = true
        return

    # 重装機は2敵ターンに1回だけ移動する。
    var phase: int = int(host.enemies[index].get("move_phase", 0))
    if phase == 0:
        host.enemies[index]["move_phase"] = 1
        for cell in current_cells:
            occupied[cell] = true
        return
    host.enemies[index]["move_phase"] = 0

    for cell in current_cells:
        occupied.erase(cell)

    var best_pos: Vector2i = host._heavy_next_step(top_left, occupied)
    if best_pos != top_left:
        host.enemies[index]["facing"] = best_pos - top_left
        host.enemies[index]["pos"] = best_pos
        top_left = best_pos

    for cell in host._heavy_cells(top_left):
        occupied[cell] = true


func _tank_fire(host, top_left: Vector2i, d: Vector2i) -> void:
    host._play_sfx(SFX_TANK_FIRE)
    var beam: Array[Vector2i] = host._tank_beam_cells(top_left, d)
    for p in beam:
        if not host.last_attack_cells.has(p):
            host.last_attack_cells.append(p)
    if host.player_pos in beam:
        host._apply_player_damage(1, "ranged", "tank")


func _tank_take_turn(host, index: int, top_left: Vector2i, occupied: Dictionary) -> void:
    var current_cells: Array[Vector2i] = host._tank_cells(top_left)

    # 砲撃予告は2敵ターン維持し、予告した向きは固定する。
    if bool(host.enemies[index]["telegraph_active"]):
        var remaining: int = int(host.enemies[index].get("telegraph_turns", 0))
        if remaining > 1:
            host.enemies[index]["telegraph_turns"] = remaining - 1
            host._play_sfx(SFX_TANK_COUNT)
            for cell in current_cells:
                occupied[cell] = true
            return
        var fire_dir: Vector2i = Vector2i(host.enemies[index].get("tank_dir", Vector2i.DOWN))
        _tank_fire(host, top_left, fire_dir)
        host.enemies[index]["telegraph_active"] = false
        host.enemies[index]["telegraph_turns"] = 0
        host.enemies[index]["move_phase"] = 0
        for cell in current_cells:
            occupied[cell] = true
        return

    var aim: Vector2i = host._tank_aim_dir(top_left, host.player_pos)
    if aim != Vector2i.ZERO:
        host.enemies[index]["facing"] = aim
        host.enemies[index]["tank_dir"] = aim
        host.enemies[index]["telegraph_active"] = true
        host.enemies[index]["telegraph_turns"] = 2
        host._play_sfx(SFX_TANK_WARN)
        for cell in current_cells:
            occupied[cell] = true
        return

    # 砲撃条件が揃わない時は2敵ターンに1回だけ、3x3形状のまま接近する。
    var phase: int = int(host.enemies[index].get("move_phase", 0))
    if phase == 0:
        host.enemies[index]["move_phase"] = 1
        for cell in current_cells:
            occupied[cell] = true
        return
    host.enemies[index]["move_phase"] = 0

    for cell in current_cells:
        occupied.erase(cell)
    var best_pos: Vector2i = host._tank_next_step(top_left, occupied)
    if best_pos != top_left:
        host.enemies[index]["facing"] = best_pos - top_left
        host.enemies[index]["pos"] = best_pos
        top_left = best_pos
    for cell in host._tank_cells(top_left):
        occupied[cell] = true


func _cross_fire(host, center: Vector2i) -> void:
    host._play_sfx(SFX_CROSS_FIRE)
    var hit_player := false
    var dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
    for d in dirs:
        var ray: Array[Vector2i] = host._cross_ray_cells(center, d)
        for p in ray:
            if not host.last_attack_cells.has(p):
                host.last_attack_cells.append(p)
        if host.player_pos in ray:
            hit_player = true
    if hit_player:
        host._apply_player_damage(1, "area", "cross_discharge")


func _cross_discharge_take_turn(host, index: int, center: Vector2i, occupied: Dictionary) -> void:
    var current_cells: Array[Vector2i] = host._cross_cells(center)

    # 1ターン前に予告した十字4方向を発射。敵は完全に無視し、壁だけが射線を止める。
    if bool(host.enemies[index]["telegraph_active"]):
        _cross_fire(host, center)
        host.enemies[index]["telegraph_active"] = false
        host.enemies[index]["cooldown"] = 2
        for cell in current_cells:
            occupied[cell] = true
        return

    var cooldown: int = int(host.enemies[index].get("cooldown", 0))
    if cooldown <= 0:
        host.enemies[index]["telegraph_active"] = true
        host._play_sfx(SFX_CROSS_WARN)
        for cell in current_cells:
            occupied[cell] = true
        return

    # 放電の合間はゆっくり追跡する。十字形を保ったまま1マスだけ移動する。
    host.enemies[index]["cooldown"] = cooldown - 1
    for cell in current_cells:
        occupied.erase(cell)

    var best_center: Vector2i = host._cross_next_step(center, occupied)
    if best_center != center:
        host.enemies[index]["facing"] = best_center - center
        host.enemies[index]["pos"] = best_center
        center = best_center

    for cell in host._cross_cells(center):
        occupied[cell] = true


func _artillery_take_turn(host, index: int, left_cell: Vector2i) -> void:
    # 予告済みなら左右の砲身から同時に外向きへ発射する。
    # 敵は遮蔽物にもダメージ対象にもならず、壁だけがビームを止める。
    if bool(host.enemies[index]["telegraph_active"]):
        _artillery_fire(host, left_cell)
        host.enemies[index]["telegraph_active"] = false
        host.enemies[index]["cooldown"] = 1
        return

    var cooldown: int = int(host.enemies[index].get("cooldown", 0))
    if cooldown > 0:
        host.enemies[index]["cooldown"] = cooldown - 1
        return

    if not host._artillery_has_horizontal_target(left_cell, host.player_pos):
        return

    host.enemies[index]["telegraph_active"] = true
    host._play_sfx(SFX_ARTILLERY_WARN)


func _artillery_fire(host, left_cell: Vector2i) -> void:
    host._play_sfx(SFX_ARTILLERY_FIRE)
    var left_ray: Array[Vector2i] = host._artillery_ray_cells(left_cell, Vector2i.LEFT)
    var right_ray: Array[Vector2i] = host._artillery_ray_cells(left_cell, Vector2i.RIGHT)
    for p in left_ray:
        if not host.last_attack_cells.has(p):
            host.last_attack_cells.append(p)
    for p in right_ray:
        if not host.last_attack_cells.has(p):
            host.last_attack_cells.append(p)

    if host.player_pos in left_ray or host.player_pos in right_ray:
        host._apply_player_damage(1, "ranged", "artillery")


func _runner_take_turn(host, index: int, runner_pos: Vector2i, occupied: Dictionary) -> void:
    # 逃走機は攻撃しない。プレイヤーが近づいた時だけ1マス逃げる。
    # 同じ距離まで逃げられる候補なら、未帯電床を優先して
    # プレイヤーに「追うほど未帯電床を使う」状況を作る。
    if host._manhattan(runner_pos, host.player_pos) > 5:
        occupied[runner_pos] = true
        return

    occupied.erase(runner_pos)

    var dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
    var candidates: Array[Vector2i] = []
    var best_distance := -1

    for d in dirs:
        var n: Vector2i = runner_pos + d
        if not host._is_floor(n):
            continue
        if n == host.player_pos or occupied.has(n):
            continue
        var distance: int = host._manhattan(n, host.player_pos)
        if distance > best_distance:
            best_distance = distance
            candidates.clear()
            candidates.append(n)
        elif distance == best_distance:
            candidates.append(n)

    if candidates.is_empty():
        occupied[runner_pos] = true
        return

    # 最大距離候補の中では未帯電床を優先する。
    var uncharged_candidates: Array[Vector2i] = []
    for n in candidates:
        if not host.charged.has(n):
            uncharged_candidates.append(n)
    if not uncharged_candidates.is_empty():
        candidates = uncharged_candidates

    var next_pos: Vector2i = candidates[host.rng.randi_range(0, candidates.size() - 1)]
    host.enemies[index]["facing"] = next_pos - runner_pos
    host.enemies[index]["pos"] = next_pos
    occupied[next_pos] = true


func _charger_take_turn(host, index: int, charger_pos: Vector2i, occupied: Dictionary) -> void:
    # 予告済みなら、予告した方向へ最大4マス突進する。
    # 他の敵にはダメージを与えず、味方がいるマスの手前で止まる。
    if bool(host.enemies[index]["telegraph_active"]):
        var charge_dir: Vector2i = host.enemies[index]["charge_dir"]
        host.enemies[index]["telegraph_active"] = false

        # charge_dirがZEROなら、隣接時の通常1マス攻撃。
        if charge_dir == Vector2i.ZERO:
            var melee_target: Vector2i = host.enemies[index]["telegraph_target"]
            _enemy_attack(host, charger_pos, melee_target, "charger")
            occupied[charger_pos] = true
            return

        host._play_sfx(SFX_CHARGER_CHARGE)
        occupied.erase(charger_pos)

        var cur: Vector2i = charger_pos
        for _step in range(4):
            var next: Vector2i = cur + charge_dir
            if not host._is_floor(next):
                break
            if occupied.has(next):
                break
            if not host.last_attack_cells.has(next):
                host.last_attack_cells.append(next)
            if next == host.player_pos:
                host._apply_player_damage(1, "charge", "charger")
                # プレイヤーと同じマスには入れないため、現在位置で突進終了。
                break
            cur = next

        host.enemies[index]["pos"] = cur
        host.enemies[index]["facing"] = charge_dir
        occupied[cur] = true
        return

    # 距離2〜4で縦横軸が合い、間に壁がなければ突進を予告する。
    var charge_dir: Vector2i = host._charger_axis_dir(charger_pos, host.player_pos)
    if charge_dir != Vector2i.ZERO:
        host.enemies[index]["facing"] = charge_dir
        host.enemies[index]["charge_dir"] = charge_dir
        host.enemies[index]["telegraph_active"] = true
        host._play_sfx(SFX_CHARGER_WARN)
        occupied[charger_pos] = true
        return

    # 突進条件を満たさないときは通常敵と同じく接近する。
    occupied.erase(charger_pos)
    if host._manhattan(charger_pos, host.player_pos) == 1:
        var attack_dir: Vector2i = host.player_pos - charger_pos
        host.enemies[index]["facing"] = attack_dir
        host.enemies[index]["telegraph_target"] = charger_pos + attack_dir
        host.enemies[index]["telegraph_active"] = true
        # charge_dir=ZEROなら次ターンは通常近接攻撃として扱う。
        host.enemies[index]["charge_dir"] = Vector2i.ZERO
        host._play_sfx(SFX_ENEMY_WARN)
        occupied[charger_pos] = true
        return

    var next_step: Vector2i = host._next_step_toward(charger_pos, host.player_pos, occupied)
    if next_step != charger_pos and next_step != host.player_pos:
        host.enemies[index]["facing"] = next_step - charger_pos
        host.enemies[index]["pos"] = next_step
        charger_pos = next_step
    occupied[charger_pos] = true


func _turret_take_turn(host, index: int, turret_pos: Vector2i) -> void:
    # 予告済みなら、予告した方向へ壁まで直線射撃する。
    # 射線上の敵は無視し、プレイヤーだけがダメージを受ける。
    if bool(host.enemies[index]["telegraph_active"]):
        var fire_dir: Vector2i = host.enemies[index]["turret_dir"]
        _turret_fire(host, turret_pos, fire_dir)
        host.enemies[index]["telegraph_active"] = false
        host.enemies[index]["cooldown"] = 1
        return

    var cooldown: int = int(host.enemies[index].get("cooldown", 0))
    if cooldown > 0:
        host.enemies[index]["cooldown"] = cooldown - 1
        return

    var aim: Vector2i = host._turret_axis_dir(turret_pos, host.player_pos)
    if aim == Vector2i.ZERO:
        return

    host.enemies[index]["facing"] = aim
    host.enemies[index]["turret_dir"] = aim
    host.enemies[index]["telegraph_active"] = true
    host._play_sfx(SFX_TURRET_WARN)


func _turret_fire(host, turret_pos: Vector2i, d: Vector2i) -> void:
    host._play_sfx(SFX_TURRET_FIRE)
    var ray: Array[Vector2i] = host._turret_ray_cells(turret_pos, d)
    for p in ray:
        if not host.last_attack_cells.has(p):
            host.last_attack_cells.append(p)

    if host.player_pos in ray:
        host._apply_player_damage(1, "ranged", "turret")


func _enemy_attack(host, _enemy_pos: Vector2i, target: Vector2i, enemy_type: String = "enemy") -> void:
    host._play_sfx(SFX_ENEMY_MELEE)
    # 通常敵の隣接攻撃はAnalytics上ではcontactに集約し、enemy_typeだけ内部保持する。
    if host._is_floor(target) and not host.last_attack_cells.has(target):
        host.last_attack_cells.append(target)

    if host.player_pos == target:
        host._apply_player_damage(1, "contact", enemy_type)



