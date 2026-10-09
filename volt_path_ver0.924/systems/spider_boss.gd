extends RefCounted

# FLOOR 10 spider boss gameplay/state authority.
# Rendering remains in main.gd for now so the existing Node2D draw pipeline is unchanged.

const LEG_HP := 12
const LEG_COUNT := 4
const STOMP_FX_DURATION := 0.42
const BREAK_FX_DURATION := 0.90
const SHAKE_DURATION := 0.22

var leg_cursor := 0
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
    }

func spawn_legs(enemies: Array[Dictionary]) -> void:
    enemies.clear()
    leg_cursor = 0
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

func _leg_can_act(e: Dictionary) -> bool:
    if str(e.get("type", "")) != "boss_leg" or bool(e.get("destroyed", false)):
        return false
    return not acted_leg_ids.has(int(e.get("leg_id", -1)))

func _has_eligible_leg(enemies: Array[Dictionary]) -> bool:
    for e in enemies:
        if _leg_can_act(e):
            return true
    return false

func find_next_live_leg(enemies: Array[Dictionary], start_index: int) -> int:
    if enemies.is_empty():
        return -1

    # 生存脚が全て1回ずつ行動したら、次の4脚サイクルを開始する。
    if not _has_eligible_leg(enemies):
        acted_leg_ids.clear()

    for offset in range(enemies.size()):
        var i: int = (start_index + offset) % enemies.size()
        if _leg_can_act(enemies[i]):
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

    # 脚の中心を基準に、周囲8方向へ1マスだけ移動する。
    # Chebyshev距離を最優先、Manhattan距離を同点時の補助にして
    # プレイヤーへ自然に近づく方向（斜めを含む）を選ぶ。
    for oy in range(-1, 2):
        for ox in range(-1, 2):
            if ox == 0 and oy == 0:
                continue
            var candidate := current_top_left + Vector2i(ox, oy)
            if not _target_is_free(enemies, candidate, index, is_floor):
                continue
            var center := candidate + Vector2i(1, 1)
            var score: int = _chebyshev(center, player_pos) * 100 + _manhattan(center, player_pos)
            if score < best_score:
                best_score = score
                best = candidate

    return best

func schedule_next_telegraph(enemies: Array[Dictionary], player_pos: Vector2i, is_floor: Callable) -> bool:
    var index: int = find_next_live_leg(enemies, leg_cursor)
    if index == -1:
        return false
    leg_cursor = index
    var target: Vector2i = choose_stomp_target(enemies, index, player_pos, is_floor)
    enemies[index]["telegraph_target"] = target
    enemies[index]["telegraph_active"] = true
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
    acted_leg_ids[int(enemies[index].get("leg_id", index))] = true
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
