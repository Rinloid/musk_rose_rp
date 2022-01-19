// __multiversion__
#include "fragmentVersionCentroid.h"

#if defined(GL_FRAGMENT_PRECISION_HIGH)
	#define hmp highp
#else
	#define hmp mediump
#endif

#if __VERSION__ >= 300
	#ifndef BYPASS_PIXEL_SHADER
		#if defined(TEXEL_AA) && defined(TEXEL_AA_FEATURE)
			_centroid in highp vec2 uv0;
			_centroid in highp vec2 uv1;
		#else
			_centroid in vec2 uv0;
			_centroid in vec2 uv1;
		#endif
	#endif
#else
	#ifndef BYPASS_PIXEL_SHADER
		varying vec2 uv0;
		varying vec2 uv1;
	#endif
#endif

varying vec4 inCol;
varying hmp vec3 camPos;
varying hmp vec3 worldPos;
flat varying float waterFlag;

#include "uniformShaderConstants.h"
#include "util.h"

LAYOUT_BINDING(0) uniform sampler2D TEXTURE_0;
LAYOUT_BINDING(1) uniform sampler2D TEXTURE_1;
LAYOUT_BINDING(2) uniform sampler2D TEXTURE_2;

uniform hmp float TOTAL_REAL_WORLD_TIME;
uniform vec4 FOG_COLOR;
uniform vec2 FOG_CONTROL;
uniform float RENDER_DISTANCE;

#include "SETTINGS.glsl"
#include "functions.glsl"

void main() {
#ifdef BYPASS_PIXEL_SHADER
	gl_FragColor = vec4(0, 0, 0, 0);
	return;
#else 

#if USE_TEXEL_AA
	vec4 albedo = texture2D_AA(TEXTURE_0, uv0);
	vec4 texCol = texture2D_AA_lod(TEXTURE_0, uv0);
#else
	vec4 albedo = texture2D(TEXTURE_0, uv0);
	vec4 texCol = textureLod(TEXTURE_0, uv0, 0.0);
#endif

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
	albedo.rgb *= mix(vec3(1.0, 1.0, 1.0), texture2D(TEXTURE_2, uv).rgb*2.0, inCol.b);
	albedo.rgb *= inCol.aaa;
	albedo.a = 1.0;
#endif

float time = getTime(FOG_COLOR);
float daylight = max(0.0, time);

vec3 sunMoonPos = (time > 0.0 ? 1.0 : -1.0) * vec3(0.45, 1.0, -0.65) * vec3(cos(time), sin(time), -cos(time));
vec3 worldNormal = normalize(cross(dFdx(worldPos), dFdy(worldPos)));
vec3 reflectPos = reflect(normalize(camPos), worldNormal);

float outdoor = smoothstep(0.850, 0.875, uv1.y);
float skyLit = mix(0.0, mix(0.0, max(0.0, dot(sunMoonPos, worldNormal)), daylight), outdoor);
float sunLit = mix(0.0, mix(0.0, max(0.0, dot(sunMoonPos, reflectPos)), daylight), outdoor);
float sunSetLit = mix(0.0, mix(0.0, max(0.0, dot(sunMoonPos, reflectPos)), min(smoothstep(0.0, 0.2, daylight), smoothstep(0.6, 0.3, daylight))), outdoor);
sunSetLit *= sunSetLit * sunSetLit * sunSetLit * sunSetLit * sunSetLit;
float moonLit = mix(0.0, mix(max(0.0, dot(sunMoonPos, reflectPos)), 0.0, daylight), outdoor);
float torchLit = uv1.x * uv1.x * uv1.x * uv1.x;
torchLit = mix(0.0, torchLit, smoothstep(0.875, 0.5, uv1.y * daylight));

float nether = 
#ifdef FOG
	FOG_CONTROL.x / FOG_CONTROL.y;
	nether = step(0.1, nether) - step(0.12,nether);
#else
	0.0;
#endif
float underwater =
#ifdef FOG
	step(FOG_CONTROL.x, 0.0);
#else
	0.0;
#endif
bool isRealUnderwater = isUnderwater(worldNormal, uv1, worldPos, texCol, inCol);
float rain = 
#ifdef FOG
	mix(0.0, mix(smoothstep(0.5, 0.3, FOG_CONTROL.x), 0.0, underwater), outdoor);
#else
	0.0;
#endif

bool isBlend = false;
#ifdef BLEND
	isBlend = true;
#endif

bool isMetallic = false;
#if !defined(ALPHA_TEST) || !defined(BLEND)
	if ((0.95 < texCol.a && texCol.a < 1.0) && inCol.b == inCol.g && inCol.r == inCol.g) {
		isMetallic = true;
		albedo.rgb = mix(albedo.rgb, getF0(texCol, albedo).rgb, 1.0);
	}
#endif

#ifdef ENABLE_RAINY_WET_EFFECTS
	float wet = 0.0;
	if (rain > 0.0) {
		float cosT = abs(dot(vec3(0.0, 1.0, 0.0), normalize(camPos)));
		wet = 0.5;
		wet = min(1.0, wet + step(0.7, snoise(worldPos.xz * 0.3)) * 0.5);
		wet = mix(wet * max(0.0, worldNormal.y) * rain, 0.0, cosT);
	}
#endif

float reflectance = 0.0;
if (waterFlag > 0.5) {
	albedo.rgb = waterCol;
	reflectance = WATER_REFLECTANCE;
} else if (isBlend) {
	reflectance = ALPHA_BLENDED_BLOCK_REFLECTANCE;
} else if (isMetallic) {
	reflectance = METALLIC_BLOCK_REFLECTANCE;
} else if (wet > 0.0) {
	reflectance = wet;
}

bool isReflective = false;
if (waterFlag > 0.5 || isBlend || isMetallic || wet > 0.0) {
	isReflective = true;
}

mat3 tBN = getTBNMatrix(worldNormal);

if (waterFlag > 0.5 && bool(step(0.7, uv1.y))) {
	#ifdef ENABLE_WATER_WAVES
		worldNormal = normalize(tBN * waterWaves2Normal(worldPos.xz, TOTAL_REAL_WORLD_TIME));
	#endif
} else if (isReflective && bool(step(0.7, uv1.y))) {
	#ifdef ENABLE_BLOCK_NORMAL_MAPS
		worldNormal = normalize(tBN * texture2Normal(uv0, 2048.0, 0.0008));
	#endif
}

reflectPos = reflect(normalize(camPos), worldNormal);

float darkenOverWorld = mix(max(0.2, uv1.y * mix(0.25, 0.65, daylight)), mix(0.25, 0.65, daylight), outdoor);
float darkenNether = texture2D(TEXTURE_1, uv1).r;

albedo.rgb *= mix(darkenOverWorld, darkenNether, nether);
albedo.rgb *= shadowCol;

vec3 lit = vec3(1.0, 1.0, 1.0);

lit *= mix(vec3(1.0, 1.0, 1.0), SKYLIGHT_INTENSITY * skyLitCol, skyLit);
lit *= mix(vec3(1.0, 1.0, 1.0), SUNLIGHT_INTENSITY * sunLitCol, sunLit);
lit *= mix(vec3(1.0, 1.0, 1.0), SUNSETLIGHT_INTENSITY * sunSetLitCol, sunSetLit);
lit *= mix(vec3(1.0, 1.0, 1.0), MOONLIGHT_INTENSITY * moonLitCol, moonLit);
lit *= mix(vec3(1.0, 1.0, 1.0), TORCHLIGHT_INTENSITY * torchLitCol, torchLit);

lit = mix(mix(lit, vec3(1.0, 1.0, 1.0), rain * 0.65), vec3(1.0, 1.0, 1.0), nether);

albedo.rgb *= lit;

#ifndef SEASONS
	albedo.rgb *= getAO(inCol, max(0.0, AMBIENT_OCCLUSION_INTENSITY - min(rgb2luma(lit - 1.0), 1.0)));
#endif

albedo.rgb = uncharted2ToneMap(albedo.rgb, 11.2, 2.2);
albedo.rgb = contrastFilter(albedo.rgb, 1.25);
albedo.rgb = desaturate(albedo.rgb, max(0.0, 0.3 - min(rgb2luma(lit - 1.0), 1.0)));

if (bool(underwater)) {
	albedo.rgb *= 1.0 + waterCol;
}

#ifdef ENABLE_REFLECTIONS
	if (isReflective && !bool(underwater)) {
		float cosTheta = abs(dot(normalize(camPos), worldNormal));
		vec3 skyPos = reflectPos;
		
		#include "reflectedview.glsl"

		albedo.rgb = mix(albedo.rgb, mix(albedo.rgb, reflectedView, smoothstep(0.7, 0.875, uv1.y)), reflectance);
		if (waterFlag > 0.5) {
			albedo.a = mix(0.9, 0.05, cosTheta);
			albedo.a = mix(albedo.a, 1.0, mix(0.0, reflectAlpha, smoothstep(0.7, 0.875, uv1.y)));
		}
	} 
	#ifdef ENABLE_WATER_CAUSTICS
		else if (isRealUnderwater) {
			float caustic = waterWaves(worldPos.xz, TOTAL_REAL_WORLD_TIME) / 0.005;

			albedo.rgb *= mix(1.1, 1.2, 1.0 - caustic);
		}
	#endif
#endif

#ifdef ENABLE_FOG
	float fogFactor = fog(FOG_CONTROL, length(-camPos) / RENDER_DISTANCE);
	vec3 fogCol;
	if (bool(underwater) || bool(nether)) {
		fogCol = FOG_COLOR.rgb;
	} else {
		fogCol = uncharted2ToneMap(lit, 11.2, 1.0);
	}
	albedo.rgb = mix(albedo.rgb, fogCol, fogFactor * 0.5);
#endif

	gl_FragColor = albedo;
	
#endif // BYPASS_PIXEL_SHADER
}
