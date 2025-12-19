shader_type canvas_item;

uniform sampler2D slash_tex : source_color;
uniform sampler2D gradient_tex; // 1D gradient strip
uniform float hdr_intensity = 1.0;
uniform float time;
uniform float intensity = 1.0;

void fragment() {
    vec2 uv = UV;

    // Mild UV distortion (e.g. noise or radial warp)
    float wave = sin(uv.y * 20.0 + time * 10.0) * 0.002 * intensity;
    uv.x += wave;

    vec4 base = texture(slash_tex, uv);
    float lum = dot(base.rgb, vec3(0.299, 0.587, 0.114));

    // Gradient mapping: grayscale -> color ramp
    vec4 grad = texture(gradient_tex, vec2(lum, 0.5));

    // Simple chromatic aberration
    vec2 ca_off = vec2(0.0015 * intensity, 0.0);
    float r = texture(slash_tex, uv + ca_off).r;
    float g = texture(slash_tex, uv).g;
    float b = texture(slash_tex, uv - ca_off).b;

    vec3 ca_color = grad.rgb * vec3(r, g, b);

    COLOR = vec4(ca_color, r) * hdr_intensity;

}
