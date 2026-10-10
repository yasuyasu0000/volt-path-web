extends RefCounted

const FontData = preload("res://systems/ui_font_data.gd")
const ATLAS_PATH := "res://assets/ui_font_atlas.png"

static func build() -> Font:
    var texture := load(ATLAS_PATH) as Texture2D
    if texture == null:
        push_warning("VOLT PATH UI font atlas could not be loaded; using Godot fallback font.")
        return ThemeDB.fallback_font
    var image := texture.get_image()
    if image == null or image.is_empty():
        push_warning("VOLT PATH UI font atlas image is unavailable; using Godot fallback font.")
        return ThemeDB.fallback_font

    var font := FontFile.new()
    font.font_name = "VOLT PATH Raster UI"
    font.fixed_size = FontData.BASE_SIZE
    font.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_ENABLED
    font.allow_system_fallback = false
    font.set_modulate_color_glyphs(true)

    var cache_size := Vector2i(FontData.BASE_SIZE, 0)
    font.set_texture_image(0, cache_size, 0, image)
    font.set_cache_ascent(0, FontData.BASE_SIZE, float(FontData.BASELINE_Y))
    font.set_cache_descent(0, FontData.BASE_SIZE, float(FontData.CELL_H - FontData.BASELINE_Y))

    for i in range(FontData.CODEPOINTS.size()):
        var codepoint: int = FontData.CODEPOINTS[i]
        var col: int = i % FontData.COLS
        var row: int = int(i / FontData.COLS)
        var uv := Rect2(
            float(col * FontData.CELL_W),
            float(row * FontData.CELL_H),
            float(FontData.CELL_W),
            float(FontData.CELL_H)
        )
        font.set_glyph_advance(0, FontData.BASE_SIZE, codepoint, Vector2(FontData.ADVANCES[i], 0.0))
        font.set_glyph_offset(0, cache_size, codepoint, Vector2(-float(FontData.ORIGIN_X), -float(FontData.BASELINE_Y)))
        font.set_glyph_size(0, cache_size, codepoint, Vector2(float(FontData.CELL_W), float(FontData.CELL_H)))
        font.set_glyph_uv_rect(0, cache_size, codepoint, uv)
        font.set_glyph_texture_idx(0, cache_size, codepoint, 0)

    return font
