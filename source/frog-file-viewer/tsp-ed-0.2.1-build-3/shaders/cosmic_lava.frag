#version 460 core
#include <flutter/runtime_effect.glsl>

out vec4 fragColor;

// Logical canvas size, elapsed time, and continuously eased heart transition.
uniform vec2 uSize;
uniform float uTime;
uniform float uHeart;
uniform float uSeed;

float hash21(vec2 p) {
  p = fract(p * vec2(123.34, 345.45));
  p += dot(p, p + 34.345);
  return fract(p.x * p.y);
}

float noise2(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  float a = hash21(i);
  float b = hash21(i + vec2(1.0, 0.0));
  float c = hash21(i + vec2(0.0, 1.0));
  float d = hash21(i + vec2(1.0, 1.0));
  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

vec3 dyePalette(float phase) {
  vec3 base = vec3(0.57, 0.56, 0.60);
  vec3 span = vec3(0.48, 0.49, 0.45);
  vec3 wave = vec3(1.0, 0.86, 0.73);
  vec3 shift = vec3(0.00, 0.22, 0.57);
  return clamp(base + span * cos(6.283185 * (wave * phase + shift)), 0.0, 1.0);
}

float heartField(vec2 p) {
  // Keep the existing proportions and pointed bottom exactly as they were.
  // Only deepen the upper-center notch to make the lobes read as a drawn heart.
  // Positive y is upward, with the two lobes above the point.
  vec2 h = vec2(p.x * 2.25, (0.07 - p.y) * 2.55);
  float a = dot(h, h) - 1.0;
  float heart = a * a * a - h.x * h.x * h.y * h.y * h.y;

  // This adds to the implicit field only at the top-center. The smoothstep
  // is exactly zero below h.y=0.05, preserving the lower silhouette.
  float topCleft =
      exp(-26.0 * h.x * h.x) *
      smoothstep(0.05, 0.85, h.y);
  heart += 0.18 * topCleft;

  return heart;
}

void main() {
  vec2 uv = FlutterFragCoord().xy / max(uSize, vec2(1.0));
  vec2 p = (FlutterFragCoord().xy - 0.5 * uSize) /
      max(min(uSize.x, uSize.y), 1.0);

  // A slowly rotating, softly mirrored kaleidoscope. The asymmetrical
  // currents below disturb the mirror so it doesn't look like fixed wedges.
  float t = uTime;
  float a = atan(p.y, p.x) + 0.046 * sin(t * 0.086 + uSeed);
  float r = length(p);
  float wedge = 6.283185 / 5.0;
  float folded = abs(mod(a + wedge * 0.5, wedge) - wedge * 0.5);
  vec2 k = r * vec2(cos(folded), sin(folded));

  vec2 drift = vec2(
    0.17 * sin(t * 0.095 + 1.7 * uSeed),
    0.19 * cos(t * 0.073 + 2.2 * uSeed)
  );
  vec2 q = k * 3.3 + drift;
  float n1 = noise2(q + vec2(t * 0.083, -t * 0.049));
  float n2 = noise2(q * 1.53 + vec2(-t * 0.058, t * 0.069) + 12.8);
  vec2 liquid = k +
      0.18 * vec2(n1 - 0.5, n2 - 0.5) +
      0.078 * vec2(
        sin(p.y * 7.0 - t * 0.15 + n2 * 6.0),
        cos(p.x * 6.0 + t * 0.11 + n1 * 6.0)
      );
  float flow = noise2(liquid * 4.6 - vec2(t * 0.084, -t * 0.076));
  float ribbon = sin(
      10.5 * liquid.x +
      7.7 * liquid.y +
      7.5 * flow +
      3.5 * n1 +
      t * 0.16
  );
  float phase = 0.18 * ribbon + 0.46 * flow + 0.28 * n2 + 0.07 * t;
  vec3 color = dyePalette(phase);
  // Saturated flowing ribbons and gentle dark troughs, no transparent circles.
  color *= 0.88 + 0.12 * sin(4.0 * flow + ribbon * 0.9 + 1.5);

  // Heart transition attracts the dye towards a living, deforming silhouette.
  // The flowing pigment remains the SAME texture throughout the transition.
  float heartDist = heartField(p + vec2(
      0.017 * sin(t * 0.31 + 0.4),
      0.014 * cos(t * 0.24 + 1.6)));
  float heartMask = 1.0 - smoothstep(-0.15, 0.16, heartDist);
  float heartLight = mix(1.0, 0.13 + 0.94 * heartMask, uHeart);
  float outline = (1.0 - smoothstep(0.02, 0.30, abs(heartDist))) * uHeart * 0.18;
  color = color * heartLight + vec3(0.20, 0.05, 0.15) * outline;

  float vignette = 1.0 - smoothstep(0.14, 1.10, length(p));
  color *= 0.71 + 0.29 * vignette;
  color = mix(vec3(0.038, 0.032, 0.09), color, 0.985);
  fragColor = vec4(color, 1.0);
}
