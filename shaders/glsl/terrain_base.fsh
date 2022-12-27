// __multiversion__

#include "fragmentVersionCentroid.h"

#if defined(GL_FRAGMENT_PRECISION_HIGH)
#	define hmp highp
#else
#	define hmp mediump
#endif

#ifndef BYPASS_PIXEL_SHADER
#	if __VERSION__ >= 300
#		if defined(TEXEL_AA) && defined(TEXEL_AA_FEATURE)
			_centroid in highp vec2 uv0;
			_centroid in highp vec2 uv1;
#		else
			_centroid in vec2 uv0;
			_centroid in vec2 uv1;
#		endif
#	else
		varying vec2 uv0;
		varying vec2 uv1;
#	endif
#endif

varying vec4 inCol;
varying hmp vec3 relPos;
varying hmp vec3 fragPos;
flat varying float waterFlag;

#ifdef FOG
	varying float fogFactor;
#endif

#include "uniformShaderConstants.h"
#include "util.h"

LAYOUT_BINDING(0) uniform sampler2D TEXTURE_0;
LAYOUT_BINDING(1) uniform sampler2D TEXTURE_1;
LAYOUT_BINDING(2) uniform sampler2D TEXTURE_2;

uniform hmp float TOTAL_REAL_WORLD_TIME;
uniform vec4 FOG_COLOR;
uniform vec2 FOG_CONTROL;
uniform float RENDER_DISTANCE;

#include "functions.glsl"

#define SKY_COL vec3(0.4, 0.65, 1.0)
#define RAY_COL vec3(0.63, 0.62, 0.45)

#define AMBIENT_LIGHT_INTENSITY 10.0
#define SKYLIGHT_INTENSITY 30.0
#define SUNLIGHT_INTENSITY 30.0
#define MOONLIGHT_INTENSITY 10.0
#define TORCHLIGHT_INTENSITY 60.0

#define SKYLIGHT_COL vec3(0.9, 0.98, 1.0)
#define SUNLIGHT_COL vec3(1.0, 0.9, 0.85)
#define SUNLIGHT_COL_SET vec3(1.0, 0.70, 0.1)
#define TORCHLIGHT_COL vec3(1.0, 0.65, 0.3)
#define MOONLIGHT_COL vec3(0.2, 0.4, 1.0)

#define EXPOSURE_BIAS 5.0
#define GAMMA 2.3

void main() {
#ifdef BYPASS_PIXEL_SHADER
	discard;
	return;
#else 

#if USE_TEXEL_AA
	vec4 albedo = texture2D_AA(TEXTURE_0, uv0);
#else
	vec4 albedo = texture2D(TEXTURE_0, uv0);
#endif

vec4 texCol = albedo;

#ifdef SEASONS_FAR
	albedo.a = 1.0;
#endif

#if USE_ALPHA_TEST
	if (albedo.a <
	#ifdef ALPHA_TO_COVERAGE
		0.05
	#else
		0.5
	#endif
	) {
		discard;
		return;
	}
#endif
	
#if defined(BLEND)
	albedo.a *= inCol.a;
#endif

#ifndef SEASONS
	#if !USE_ALPHA_TEST && !defined(BLEND)
		albedo.a = inCol.a;
	#endif
	
    if (abs(inCol.r - inCol.g) > 0.001 || abs(inCol.g - inCol.b) > 0.001) {
        albedo.rgb *= normalize(inCol.rgb);
	}
	#ifdef ALPHA_TEST
		if (inCol.b == 0.0) {
			albedo.rgb *= inCol.rgb;
		}
	#endif
#else
	vec2 uv = inCol.xy;
	albedo.rgb *= mix(vec3(1.0, 1.0, 1.0), texture2D(TEXTURE_2, uv).rgb * 2.0, inCol.b);
	albedo.rgb *= inCol.aaa;
	albedo.a = 1.0;
#endif

bool isMetallic = false;
#if !defined(ALPHA_TEST) && !defined(BLEND)
	if ((0.95 < texCol.a && texCol.a < 1.0) && inCol.b == inCol.g && inCol.r == inCol.g) {
		isMetallic = true;
	}
#endif

vec3 skyPos = normalize(relPos);
vec3 sunPos = vec3(-0.4, 1.0, 0.65);
float time = min(getTimeFromFog(FOG_COLOR), 0.7);
vec3 sunMoonPos = (time > 0.0 ? 1.0 : -1.0) * sunPos * vec3(cos(time), sin(time), -cos(time));
vec3 normal = normalize(cross(dFdx(fragPos), dFdy(fragPos)));
if (isMetallic) {
	normal = getTexNormal(uv0, 4096.0, 0.0012) * getTBNMatrix(normal);
	normal = getTexNormal(uv0, 8192.0, 0.0008) * getTBNMatrix(normal);
}
float outdoor = smoothstep(0.86, 0.875, uv1.y);
float diffuse = max(0.0, dot(sunMoonPos, normal));
float daylight = max(0.0, time);
float duskDawn = min(smoothstep(0.0, 0.3, daylight), smoothstep(0.5, 0.3, daylight));
float amnientLightFactor = mix(0.2, mix(0.2, 1.4, daylight), uv1.y);;
float dirLightFactor = mix(0.0, diffuse, outdoor);
float emissiveLightFactor = uv1.x * uv1.x * uv1.x * uv1.x * uv1.x;
float clearWeather = 1.0 - mix(0.0, mix(smoothstep(0.5, 0.3, FOG_CONTROL.x), 0.0, step(FOG_CONTROL.x, 0.0)), smoothstep(0.0, 0.875, uv1.y));
vec3 skylightCol = getSkyLight(reflect(skyPos, normal), sunMoonPos, SKY_COL, daylight, 1.0 - clearWeather);
vec3 sunlightCol = mix(SUNLIGHT_COL, SUNLIGHT_COL_SET, duskDawn);
vec3 daylightCol = mix(skylightCol, sunlightCol, 0.4);
vec3 ambientLightCol = mix(mix(vec3(0.0, 0.0, 0.0), TORCHLIGHT_COL, emissiveLightFactor), mix(MOONLIGHT_COL, daylightCol, daylight), dirLightFactor);
ambientLightCol += 1.0 - max(max(ambientLightCol.r, ambientLightCol.g), ambientLightCol.b);
float vanillaAO = 0.0;
#ifndef SEASONS
	vanillaAO = 1.0 - (inCol.g * 2.0 - (inCol.r < inCol.b ? inCol.r : inCol.b)) * 1.4;
#endif
float occlShadow = mix(1.0, 0.2, vanillaAO);

vec3 light = vec3(0.0, 0.0, 0.0);

light += ambientLightCol * AMBIENT_LIGHT_INTENSITY * amnientLightFactor * occlShadow;
light += sunlightCol * SUNLIGHT_INTENSITY * dirLightFactor * daylight * clearWeather;
light += MOONLIGHT_COL * MOONLIGHT_INTENSITY * dirLightFactor * (1.0 - daylight) * clearWeather;
light += skylightCol * SKYLIGHT_INTENSITY * dirLightFactor * daylight * clearWeather;
light += TORCHLIGHT_COL * TORCHLIGHT_INTENSITY * emissiveLightFactor;

albedo.rgb = pow(albedo.rgb, vec3(GAMMA));
albedo.rgb *= light;
albedo.rgb = hdrExposure(albedo.rgb, EXPOSURE_BIAS, 0.2);
albedo.rgb = uncharted2ToneMap(albedo.rgb, EXPOSURE_BIAS);
albedo.rgb = pow(albedo.rgb, vec3(1.0 / GAMMA));
albedo.rgb = contrastFilter(albedo.rgb, GAMMA - 0.6);

if (waterFlag > 0.5 || isMetallic) {
	if (waterFlag > 0.5) {
		normal = getWaterWavNormal(fragPos.xz, TOTAL_REAL_WORLD_TIME) * getTBNMatrix(normalize(cross(dFdx(fragPos), dFdy(fragPos))));
	}

	float cosTheta = 1.0 - abs(dot(normalize(relPos), normal));
	vec3 sky = getSky(reflect(skyPos, normal), sunMoonPos, sunMoonPos, SKY_COL, daylight, 1.0 - clearWeather, TOTAL_REAL_WORLD_TIME, 7);

	if (waterFlag > 0.5) {
		albedo.rgb = mix(albedo.rgb, inCol.rgb, outdoor) * 0.5;
		albedo.a = mix(0.2, 1.0, cosTheta);
	}
	
	albedo.rgb = mix(albedo.rgb, sky, cosTheta * outdoor);

	float specularLight = getSun(cross(reflect(skyPos, normal), sunMoonPos) * 45.0);
	albedo += specularLight * outdoor;
}

#ifdef FOG
	float fogBrightness = mix(0.7, 2.0, smoothstep(0.0, 0.1, daylight));
	vec3 fogCol = toneMapReinhard(getAtmosphere(skyPos, sunMoonPos, SKY_COL, fogBrightness));

	albedo.rgb = mix(albedo.rgb, mix(fogCol, vec3(dot(fogCol, vec3(0.4))), 1.0 - clearWeather), fogFactor);
#endif

#if !defined(BLEND)
	if (!isMetallic) {
		float sunRayFactor = !bool(step(FOG_CONTROL.x, 0.0)) ? min(smoothstep(0.5, 0.875, uv1.y) * max(0.0, 1.0 - distance(skyPos, sunMoonPos)) * smoothstep(0.0, 0.1, daylight), 1.0) : 0.0;
		albedo.rgb = mix(albedo.rgb, RAY_COL, sunRayFactor);
	}
#endif

	gl_FragColor = albedo;
	
#endif /* !BYPASS_PIXEL_SHADER */
}
