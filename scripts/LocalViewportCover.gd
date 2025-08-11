extends CanvasLayer
class_name LocalViewportCover

signal fade_out_finished
signal fade_in_finished

@export var color: Color = Color("#ead4b4")
@export var layer_index: int = 100        # draws above world
@export var debug_enabled: bool = false

var _rect: ColorRect
var _mat: ShaderMaterial

func _ready() -> void:
	layer = layer_index
	follow_viewport_enabled = true
	_build_rect()
	_build_shader()
	_rect.visible = false  # start hidden to avoid any flash

	# Keep size in sync (not strictly needed with Full Rect, but handy for logs)
	if get_viewport().has_signal("size_changed"):
		get_viewport().size_changed.connect(_on_viewport_size_changed)
	_dbg("ready; progress=0, vp=" + str(get_viewport().size))

func _build_rect() -> void:
	_rect = ColorRect.new()
	_rect.name = "CoverRect"
	_rect.color = color
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)

func _build_shader() -> void:
	var sh := Shader.new()
	sh.code = """
		shader_type canvas_item;

		// 0 = hidden, 1 = fully covered
		uniform float progress : hint_range(0.0,1.0) = 0.0;
		uniform vec4  fade_color : source_color = vec4(0.918,0.831,0.705,1.0);
		uniform float edge_softness : hint_range(0.0,0.4) = 0.12;

		// Optional dissolve texture (SceneManager patterns). If false, uses noise fallback.
		uniform bool use_tex = false;
		uniform bool inverted = false;
		uniform sampler2D dissolve_tex;

		// Noise fallback
		uniform float noise_scale : hint_range(1.0,12.0) = 4.0;
		uniform int   noise_octaves = 4;
		uniform float noise_lacunarity = 2.0;
		uniform float noise_gain       = 0.5;

		// Cosmetic dimples
		uniform float dimple_freq    : hint_range(8.0,80.0)  = 36.0;
		uniform float dimple_radius  : hint_range(0.02,0.12) = 0.06;
		uniform float dimple_feather : hint_range(0.0,0.08)  = 0.03;
		uniform float dimple_depth   : hint_range(0.0,0.5)   = 0.15;

		float hash2(vec2 p){ return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453123); }
		float noise2(vec2 p){
			vec2 i=floor(p), f=fract(p);
			float a=hash2(i), b=hash2(i+vec2(1,0)), c=hash2(i+vec2(0,1)), d=hash2(i+vec2(1,1));
			vec2 u=f*f*(3.0-2.0*f);
			return mix(a,b,u.x) + (c-a)*u.y*(1.0-u.x) + (d-b)*u.x*u.y;
		}
		float fbm(vec2 p){
			float v=0.0, a=0.5;
			for (int i=0;i<8;i++){ if (i>=noise_octaves) break; v+=a*noise2(p); p*=noise_lacunarity; a*=noise_gain; }
			return v;
		}

		vec2 hex_coords(vec2 uv){
			vec2 r=vec2(1.0,1.7320508), h=r*0.5;
			vec2 a=mod(uv,r)-h, b=mod(uv-h,r)-h;
			return dot(a,a)<dot(b,b)?a:b;
		}
		float dimple_at(vec2 uv){
			vec2 hc=hex_coords(uv * dimple_freq);
			float dist=length(hc);
			float rim0=dimple_radius;
			float rim1=max(0.0, dimple_radius-dimple_feather);
			return 1.0 - smoothstep(rim1, rim0, dist);
		}

		void fragment(){
			if (progress <= 0.0001){
				discard; // fully invisible
			}

			float n = use_tex ? texture(dissolve_tex, UV).r : fbm(UV * noise_scale);
			if (inverted) { n = 1.0 - n; }

			// As progress grows, more area is covered
			float t = smoothstep(progress, progress + edge_softness, n);
			float mask = 1.0 - t;  // 1 = covered

			if (mask <= 0.0001){
				discard;
			}

			// subtle dimples so it isn't flat
			float dimp = dimple_at(UV);
			float shade = 1.0 - dimple_depth * dimp;

			vec3 rgb = fade_color.rgb * shade;
			COLOR = vec4(rgb, fade_color.a * mask);
		}
	"""
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat.set_shader_parameter("progress", 0.0)
	_mat.set_shader_parameter("fade_color", color)
	_rect.material = _mat

# ---------- Public API ----------
func set_color(c: Color) -> void:
	color = c
	if _rect: _rect.color = c
	if _mat:  _mat.set_shader_parameter("fade_color", c)

func set_edge_softness(v: float) -> void:
	if _mat: _mat.set_shader_parameter("edge_softness", v)

func use_scribbles_from_plugin(invert: bool) -> void:
	var tex: Texture2D = null
	var path := "res://addons/scene_manager/shader_patterns/scribbles.png"
	if ResourceLoader.exists(path):
		tex = load(path)
	if _mat:
		_mat.set_shader_parameter("use_tex", tex != null)
		if tex: _mat.set_shader_parameter("dissolve_tex", tex)
		_mat.set_shader_parameter("inverted", invert)

func fade_out(speed: float) -> void:
	_dbg("fade_out start")
	_rect.visible = true
	var secs :float= 1.0 / max(0.001, speed)
	await _tween_progress(1.0, secs)
	emit_signal("fade_out_finished")
	_dbg("fade_out done")

func fade_in(speed: float) -> void:
	_dbg("fade_in start")
	var secs :float= 1.0 / max(0.001, speed)
	await _tween_progress(0.0, secs)
	_rect.visible = false
	emit_signal("fade_in_finished")
	_dbg("fade_in done")

# ---------- Internals ----------
func _tween_progress(target: float, seconds: float) -> void:
	var from_val := float(_mat.get_shader_parameter("progress"))
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE)
	tw.set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(Callable(self, "_set_progress"), from_val, clamp(target, 0.0, 1.0), max(0.0, seconds))
	await tw.finished

func _set_progress(v: float) -> void:
	if _mat:
		_mat.set_shader_parameter("progress", clamp(v, 0.0, 1.0))

func _on_viewport_size_changed() -> void:
	_dbg("viewport size -> " + str(get_viewport().size))

func _dbg(msg: String) -> void:
	if debug_enabled:
		print("[ViewportCover] ", msg)
