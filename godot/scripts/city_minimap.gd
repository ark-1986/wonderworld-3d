extends Control
## Lightweight mobile minimap; no network or Google Maps services.
var marker: Vector2 = Vector2.ZERO
var visible_time: float = 0.0
const DOTS := [
    {"point":Vector2(0,-35),"color":Color("e87984")},
    {"point":Vector2(-34,22),"color":Color("53c8a3")},
    {"point":Vector2(-32,-31),"color":Color("5ca5e7")},
    {"point":Vector2(32,26),"color":Color("e8ad58")},
    {"point":Vector2(31,-29),"color":Color("a997f4")}
]

func _ready() -> void:
    custom_minimum_size = Vector2(214, 168)
    mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_world_position(pos: Vector3) -> void:
    marker = Vector2(pos.x, pos.z)
    queue_redraw()

func _map_point(p: Vector2) -> Vector2:
    return Vector2(107.0 + p.x * 1.55, 94.0 + p.y * 1.25)

func _draw() -> void:
    var bounds := Rect2(Vector2(0,0), Vector2(214, 168))
    draw_rect(bounds, Color(0.06, 0.13, 0.22, 0.84), true)
    draw_rect(bounds.grow(-1), Color("4fa7a1"), false, 2.0)
    draw_line(_map_point(Vector2(-48,0)), _map_point(Vector2(48,0)), Color("d5b18b"), 4.0)
    draw_line(_map_point(Vector2(0,-48)), _map_point(Vector2(0,48)), Color("d5b18b"), 4.0)
    draw_circle(_map_point(Vector2.ZERO), 9.0, Color("f1dda9"))
    for d in DOTS:
        draw_circle(_map_point(d["point"]), 6.0, d["color"])
    draw_circle(_map_point(marker), 5.0, Color.WHITE)
    draw_arc(_map_point(marker), 7.6, 0, TAU, 14, Color("d8feff"), 1.8, true)
