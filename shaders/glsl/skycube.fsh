// __multiversion__

#include "fragmentVersionCentroid.h"

#if defined(GL_FRAGMENT_PRECISION_HIGH)
	#define hmp highp
#else
	#define hmp mediump
#endif

#include "uniformShaderConstants.h"
#include "util.h"

varying hmp vec3 worldPos;

LAYOUT_BINDING(0) uniform sampler2D TEXTURE_0;

uniform hmp float TOTAL_REAL_WORLD_TIME;
uniform vec4 FOG_COLOR;
uniform vec2 FOG_CONTROL;
uniform float RENDER_DISTANCE;

#include "SETTINGS.glsl"
#include "functions.glsl"

void main() {
if (bool(step(FOG_CONTROL.x, 0.0))) {
    discard;
}
float time = getTime(FOG_COLOR);
float daylight = max(0.0, time);
float rain = smoothstep(0.5, 0.3, FOG_CONTROL.x);
vec3 sunMoonPos = (time > 0.0 ? 1.0 : -1.0) * vec3(0.45, 1.0, -0.65) * vec3(cos(time), sin(time), -cos(time));
vec4 albedo = vec4(1.0, 1.0, 1.0, 1.0);
hmp vec3 skyPos = normalize(worldPos);

#include "reflectedview.glsl"

albedo.rgb = reflectedView;

	gl_FragColor = albedo;
}
