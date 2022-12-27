// __multiversion__

#include "fragmentVersionCentroid.h"

#if defined(GL_FRAGMENT_PRECISION_HIGH)
#	define hmp highp
#else
#	define hmp mediump
#endif

#include "uniformShaderConstants.h"
#include "util.h"

varying hmp vec3 relPos;

LAYOUT_BINDING(0) uniform sampler2D TEXTURE_0;

uniform hmp float TOTAL_REAL_WORLD_TIME;
uniform vec4 FOG_COLOR;
uniform vec2 FOG_CONTROL;
uniform float RENDER_DISTANCE;

#include "functions.glsl"

#define SKY_COL vec3(0.4, 0.65, 1.0)

void main() {
vec3 albedo = vec3(0.0, 0.0, 0.0);

vec3 skyPos = normalize(relPos);
vec3 sunPos = vec3(-0.4, 1.0, 0.65);
float time = min(getTimeFromFog(FOG_COLOR), 0.7);
vec3 sunMoonPos = (time > 0.0 ? 1.0 : -1.0) * sunPos * vec3(cos(time), sin(time), -cos(time));
float daylight = max(0.0, time);
float duskDawn = min(smoothstep(0.0, 0.3, daylight), smoothstep(0.5, 0.3, daylight));
float clearWeather = 1.0 - mix(smoothstep(0.5, 0.3, FOG_CONTROL.x), 0.0, step(FOG_CONTROL.x, 0.0));
vec3 sky = getSky(skyPos, sunMoonPos, sunMoonPos, SKY_COL, daylight, 1.0 - clearWeather, TOTAL_REAL_WORLD_TIME, 7);

albedo = sky;

	gl_FragColor = vec4(albedo, 1.0);
}
