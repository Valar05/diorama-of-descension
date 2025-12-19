@tool
extends Polygon2D

@export_range(1, 256, 1)
var segment_count: int = 24 : set = _set_segment_count

@export var strip_length: float = 256.0 : set = _set_strip_length
@export var strip_width: float = 64.0 : set = _set_strip_width

# Size of the slash texture in pixels – set this to your real texture size
@export var tex_size: Vector2 = Vector2(1024.0, 256.0) : set = _set_tex_size

@export var center_on_origin: bool = true : set = _set_center_on_origin


func _ready() -> void:
	if Engine.is_editor_hint():
		_rebuild_strip()


func _set_segment_count(v: int) -> void:
	segment_count = max(1, v)
	_rebuild_strip()

func _set_strip_length(v: float) -> void:
	strip_length = max(1.0, v)
	_rebuild_strip()

func _set_strip_width(v: float) -> void:
	strip_width = max(1.0, v)
	_rebuild_strip()

func _set_tex_size(v: Vector2) -> void:
	tex_size = Vector2(max(v.x, 1.0), max(v.y, 1.0))
	_rebuild_strip()

func _set_center_on_origin(v: bool) -> void:
	center_on_origin = v
	_rebuild_strip()


func _rebuild_strip() -> void:
	if !Engine.is_editor_hint():
		return

	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var polys: Array[PackedInt32Array] = []

	var segs : int= max(segment_count, 1)
	var half_w := strip_width * 0.5

	# We’ll create 3 columns per row: left, center, right
	# Row i has base index = i * 3

	for i in range(segs + 1):
		var t := float(i) / float(segs)  # 0..1 along length
		var y := t * strip_length
		if center_on_origin:
			y -= strip_length * 0.5

		# Left vertex
		pts.append(Vector2(-half_w, y))
		uvs.append(Vector2(t * tex_size.x, 0.0))

		# Center vertex
		pts.append(Vector2(0.0, y))
		uvs.append(Vector2(t * tex_size.x, tex_size.y * 0.5))

		# Right vertex
		pts.append(Vector2(half_w, y))
		uvs.append(Vector2(t * tex_size.x, tex_size.y))

	# Build quads per segment (two quads: left-center and center-right)
	for i in range(segs):
		var row0 := i * 3
		var row1 := (i + 1) * 3

		var left0   := row0
		var center0 := row0 + 1
		var right0  := row0 + 2

		var left1   := row1
		var center1 := row1 + 1
		var right1  := row1 + 2

		# Quad 1: left0, center0, center1, left1
		var poly1 := PackedInt32Array()
		poly1.push_back(left0)
		poly1.push_back(center0)
		poly1.push_back(center1)
		poly1.push_back(left1)
		polys.append(poly1)

		# Quad 2: center0, right0, right1, center1
		var poly2 := PackedInt32Array()
		poly2.push_back(center0)
		poly2.push_back(right0)
		poly2.push_back(right1)
		poly2.push_back(center1)
		polys.append(poly2)

	polygon = pts
	uv = uvs
	polygons = polys

	color = Color.WHITE
	queue_redraw()
