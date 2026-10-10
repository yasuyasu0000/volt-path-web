extends RefCounted

const GameBalance = preload("res://systems/game_balance.gd")

# FLOOR 10 spider boss gameplay/state authority.
# Rendering remains in main.gd for now so the existing Node2D draw pipeline is unchanged.

const LEG_CELL_COUNT := 9
const LEG_HP := GameBalance.ENEMY_HP_PER_CELL * LEG_CELL_COUNT
const LEG_COUNT := 4
const LEG_MOVE_INTERVAL_TURNS := 4
const STOMP_FX_DURATION := 0.42
const BREAK_FX_DURATION := 0.90
const SHAKE_DURATION := 0.22

var leg_cursor := 0
var boss_turn_count := 0
var acted_leg_ids: Dictionary = {}
var stomp_fx_time := 0.0
var stomp_fx_cells: Array[Vector2i] = []
var stomp_fx_origin := Vector2i.ZERO
var break_fx_time := 0.0
var break_fx_center := Vector2.ZERO
var break_destroyed_count := 0
var shake_time := 0.0
var shake_sequence := 0

func reset() -> void:
    leg_cursor = 0
    boss_turn_count = 0
    acted_leg_ids.clear()
    stomp_fx_time = 0.0
    stomp_fx_cells.clear()
    stomp_fx_origin = Vector2i.ZERO
    break_fx_time = 0.0
    break_fx_center = Vector2.ZERO
    break_destroyed_count = 0
    shake_time = 0.0
    shake_sequence = 0

func process(delta: float) -> bool:
    var redraw := false
    if stomp_fx_time > 0.0:
        stomp_fx_time = maxf(0.0, stomp_fx_time - delta)
        if stomp_fx_time <= 0.0:
            stomp_fx_cells.clear()
        redraw = true
    if break_fx_time > 0.0:
        break_fx_time = maxf(0.0, break_fx_time - delta)
        redraw = true
    if shake_time > 0.0:
        shake_time = maxf(0.0, shake_time - delta)
        redraw = true
    return redraw

func leg_cells(top_left: Vector2i) -> Array[Vector2i]:
    var out: Array[Vector2i] = []
    for oy in range(3):
        for ox in range(3):
            out.append(top_left + Vector2i(ox, oy))
    return out

func _make_leg(leg_id: int, pos: Vector2i) -> Dictionary:
    return {
        "type": "boss_leg",
        "leg_id": leg_id,
        "pos": pos,
        "hp": LEG_HP,
        "destroyed": false,
        "facing": Vector2i.DOWN,
        "telegraph_active": false,
        "telegraph_target": pos,
        "last_stomp": Vector2i(-99, -99),
        "next_move_turn": 1,
        "telegraph_turn": 0,
    }

func spawn_legs(enemies: Array[Dictionary]) -> void:
    enemies.clear()
    leg_cursor = 0
    boss_turn_count = 0
    acted_leg_ids.clear()
    # 3x3脚が外周壁の内側へぴったり収まる四隅。
    enemies.append(_make_leg(0, Vector2i(1, 1)))
    enemies.append(_make_leg(1, Vector2i(13, 1)))
    enemies.append(_make_leg(2, Vector2i(1, 7)))
    enemies.append(_make_leg(3, Vector2i(13, 7)))

func alive_leg_count(enemies: Array[Dictionary]) -> int:
    var count := 0
    for e in enemies:
        if str(e.get("type", "")) == "boss_leg" and not bool(e.get("destroyed", false)):
            count += 1
    return count

func all_legs_destroyed(enemies: Array[Dictionary]) -> bool:
    var found := false
    for e in enemies:
        if str(e.get("type", "")) != "boss_leg":
            continue
        found = true
        if not bool(e.get("destroyed", false)):
            return false
    return found

func begin_turn() -> void:
    boss_turn_count += 1

func _leg_id(e: Dictionary) -> int:
    return int(e.get("leg_id", -1))

func _normalize_round(enemies: Array[Dictionary]) -> void:
    # 破壊済みの脚は現在の1巡から除外する。
    var alive_ids: Array[int] = []
    for e in enemies:
        if str(e.get("type", "")) != "boss_leg" or bool(e.get("destroyed", false)):
            continue
        alive_ids.append(_leg_id(e))

    var stale_ids: Array = []
    for key in acted_leg_ids.keys():
        if int(key) not in alive_ids:
            stale_ids.append(key)
    for key in stale_ids:
        acted_leg_ids.erase(key)

    if alive_ids.is_empty():
        acted_leg_ids.clear()
        return

    # 生存している全脚が1回ずつ動いたら1巡終了。
    # 次の行動候補を探す前に新しい巡へ切り替える。
    for leg_id in alive_ids:
        if not acted_leg_ids.has(leg_id):
            return
    acted_leg_ids.clear()

func _leg_can_act_on_turn(e: Dictionary, action_turn: int) -> bool:
    if str(e.get("type", "")) != "boss_leg" or bool(e.get("destroyed", false)):
        return false
    if bool(e.get("telegraph_active", false)):
        return false
    # 同じ1巡の中では、すでに動いた脚は再行動できない。
    if acted_leg_ids.has(_leg_id(e)):
        return false
    # 1巡が終わっていても、各脚は前回行動から4ターン空ける。
    return int(e.get("next_move_turn", 1)) <= action_turn

func find_next_live_leg(enemies: Array[Dictionary], start_index: int, action_turn: int = -1) -> int:
    if enemies.is_empty():
        return -1
    _normalize_round(enemies)
    var target_turn: int = action_turn
    if target_turn < 0:
        target_turn = boss_turn_count + 1
    for offset in range(enemies.size()):
        var i: int = (start_index + offset) % enemies.size()
        if _leg_can_act_on_turn(enemies[i], target_turn):
            return i
    return -1

func find_telegraphed_leg(enemies: Array[Dictionary]) -> int:
    for i in range(enemies.size()):
        var e: Dictionary = enemies[i]
        if str(e.get("type", "")) != "boss_leg" or bool(e.get("destroyed", false)):
            continue
        if bool(e.get("telegraph_active", false)) and int(e.get("telegraph_turn", 0)) <= boss_turn_count:
            return i
    return -1

func _target_is_free(enemies: Array[Dictionary], top_left: Vector2i, moving_index: int, is_floor: Callable) -> bool:
    var target_cells: Array[Vector2i] = leg_cells(top_left)
    for cell in target_cells:
        if not bool(is_floor.call(cell)):
            return false
    for i in range(enemies.size()):
        if i == moving_index:
            continue
        var e: Dictionary = enemies[i]
        if str(e.get("type", "")) != "boss_leg" or bool(e.get("destroyed", false)):
            continue
        for cell in leg_cells(Vector2i(e["pos"])):
            if cell in target_cells:
                return false
    return true

func _manhattan(a: Vector2i, b: Vector2i) -> int:
    return absi(a.x - b.x) + absi(a.y - b.y)

func _chebyshev(a: Vector2i, b: Vector2i) -> int:
    return maxi(absi(a.x - b.x), absi(a.y - b.y))

func choose_stomp_target(enemies: Array[Dictionary], index: int, player_pos: Vector2i, is_floor: Callable) -> Vector2i:
    var e: Dictionary = enemies[index]
    var current_top_left: Vector2i = Vector2i(e.get("pos", Vector2i(1, 1)))
    var best: Vector2i = current_top_left
    var best_score := 1000000

    # 脚の中心を基準に、上下左右の4方向へ1マスだけ移動する。
    # Manhattan距離を最優先し、同点ならChebyshev距離で
    # プレイヤーへより自然に近づく軸を選ぶ。斜め移動はしない。
    var dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
    for d in dirs:
        var candidate := current_top_left + d
        if not _target_is_free(enemies, candidate, index, is_floor):
            continue
        var center := candidate + Vector2i(1, 1)
        var score: int = _manhattan(center, player_pos) * 100 + _chebyshev(center, player_pos)
        if score < best_score:
            best_score = score
            best = candidate

    return best

func schedule_next_telegraph(enemies: Array[Dictionary], player_pos: Vector2i, is_floor: Callable) -> bool:
    # 予告は「次のボスターンに動ける脚」1本だけに出す。
    # 同一巡で行動済みの脚は、まだ動いていない生存脚がいる間は候補外。
    # 1巡終了後も各脚の4ターン間隔は維持する。
    for e in enemies:
        if str(e.get("type", "")) == "boss_leg" and not bool(e.get("destroyed", false)) and bool(e.get("telegraph_active", false)):
            return true
    var action_turn := boss_turn_count + 1
    var index: int = find_next_live_leg(enemies, leg_cursor, action_turn)
    if index == -1:
        return false
    leg_cursor = index
    var target: Vector2i = choose_stomp_target(enemies, index, player_pos, is_floor)
    enemies[index]["telegraph_target"] = target
    enemies[index]["telegraph_active"] = true
    enemies[index]["telegraph_turn"] = action_turn
    return true

func stomp(enemies: Array[Dictionary], index: int, last_attack_cells: Array[Vector2i], player_pos: Vector2i, is_floor: Callable) -> Dictionary:
    if index < 0 or index >= enemies.size():
        return {"valid": false, "hit_player": false}
    var target: Vector2i = Vector2i(enemies[index].get("telegraph_target", enemies[index]["pos"]))
    var cells: Array[Vector2i] = leg_cells(target)
    last_attack_cells.clear()
    stomp_fx_cells = cells.duplicate()
    stomp_fx_origin = target
    stomp_fx_time = STOMP_FX_DURATION
    shake_time = SHAKE_DURATION
    shake_sequence += 1
    for cell in cells:
        if bool(is_floor.call(cell)):
            last_attack_cells.append(cell)
    enemies[index]["pos"] = target
    enemies[index]["last_stomp"] = target
    enemies[index]["telegraph_active"] = false
    enemies[index]["telegraph_turn"] = 0
    enemies[index]["next_move_turn"] = boss_turn_count + LEG_MOVE_INTERVAL_TURNS
    acted_leg_ids[_leg_id(enemies[index])] = true
    _normalize_round(enemies)
    return {"valid": true, "hit_player": player_pos in cells, "cells": cells}

func mark_leg_destroyed(enemies: Array[Dictionary], index: int, cell_center: Callable) -> bool:
    if index < 0 or index >= enemies.size():
        return false
    var e: Dictionary = enemies[index]
    if str(e.get("type", "")) != "boss_leg" or bool(e.get("destroyed", false)):
        return false
    var leg_pos: Vector2i = Vector2i(e["pos"])
    e["hp"] = 0
    e["destroyed"] = true
    e["telegraph_active"] = false
    enemies[index] = e
    acted_leg_ids.erase(_leg_id(e))
    _normalize_round(enemies)
    break_fx_center = Vector2(cell_center.call(leg_pos + Vector2i(1, 1)))
    break_destroyed_count = LEG_COUNT - alive_leg_count(enemies)
    break_fx_time = BREAK_FX_DURATION
    shake_time = maxf(shake_time, SHAKE_DURATION)
    shake_sequence += 1
    return true

func shake_offset() -> Vector2:
    if shake_time <= 0.0 or SHAKE_DURATION <= 0.0:
        return Vector2.ZERO
    var remain: float = clampf(shake_time / SHAKE_DURATION, 0.0, 1.0)
    var progress: float = 1.0 - remain
    var phase: float = progress * 34.0 + float(shake_sequence) * 1.91
    var amplitude: float = 4.0 * remain * remain
    return Vector2(sin(phase) * amplitude, cos(phase * 1.27) * amplitude * 0.62)
