shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D slash_tex : source_color;
uniform float collapse_center : hint_range(0.0, 1.0, 0.01) = 0.5;

// 0.0 = nothing, 1.0 = full length visible
uniform float progress : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float emissive_multi: hint_range(0.0, 10.0, 1.0);

// 0.0 = full height, 1.0 = fully collapsed to centerline
uniform float collapse : hint_range(0.0, 1.0, 0.01) = 0.0;

// soft fade size in UV units (0.05 ≈ 5% of width/height)
uniform float edge_softness : hint_range(0.0, 0.2, 0.001) = 0.05;

void fragment() {
    vec2 uv = UV;

    // -----------------------
    // 1) PROGRESS: slide UV along -X, no repeat
    // -----------------------
    float offset = 1.0 - progress;   // 0 → full; 1 → fully off
    float sx = uv.x - offset;        // slide texture left as progress grows

    float mask = 1.0;

    // Outside [0,1] ⇒ no slash
    if (sx < 0.0 || sx > 1.0) {
        mask = 0.0;
    }

    vec2 suv = vec2(sx, uv.y);
    vec4 tex = texture(slash_tex, suv);

    vec3 col = tex.rgb;
    float alpha = tex.r;

float half_h = 0.5 * (1.0 - collapse); // 0.5 → full, 0 → none

float vert_alpha = 1.0;

if (half_h <= 0.0) {
    vert_alpha = 0.0;
} else {
    float inner = max(0.0, half_h - edge_softness);

    // distance from collapse_center, with wrap-around
    float dy = abs(uv.y - collapse_center);
    dy = min(dy, 1.0 - dy); // wrap top/bottom

    if (dy >= half_h) {
        vert_alpha = 0.0;
    } else if (dy <= inner) {
        vert_alpha = 1.0;
    } else {
        // smooth fade near band edges
        vert_alpha = 1.0 - smoothstep(inner, half_h, dy);
    }
}


    // -----------------------
    // 3) RIGHT EDGE SOFT FADE (horizontal)
    // -----------------------
    float right_alpha = 1.0;
    if (edge_softness > 0.0) {
        right_alpha = 1.0 - smoothstep(1.0 - edge_softness, 1.0, sx);
    }

    // -----------------------
    // 4) Combine masks and output
    // -----------------------
    float final_alpha = alpha * vert_alpha * right_alpha * mask;

    if (final_alpha <= 0.001) {
        ALBEDO = vec3(0.0);
        ALPHA  = 0.0;
    } else {
        ALBEDO = col * emissive_multi;
        ALPHA  = final_alpha;
    }
}
