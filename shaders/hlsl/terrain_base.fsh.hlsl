#include "ShaderConstants.fxh"
#include "util.fxh"

struct Input {
	float4 pos : SV_Position;
#ifndef BYPASS_PIXEL_SHADER
	lpfloat4 col : COLOR;
	snorm float2 uv0 : TEXCOORD_0_FB_MSAA;
	snorm float2 uv1 : TEXCOORD_1_FB_MSAA;
#endif
	float3 worldPos : worldPos;
	float3 camPos : camPos;
	bool isWater : isWater;
};

struct Output {
	float4 col : SV_Target;
};

#include "SETTINGS.hlsl"
#include "functions.hlsl"

ROOT_SIGNATURE
void main(in Input In, out Output Out) {
#ifdef BYPASS_PIXEL_SHADER
    Out.col = float4(0.0, 0.0, 0.0, 0.0);
    return;
#else

#if USE_TEXEL_AA
	float4 albedo = texture2D_AA(TEXTURE_0, TextureSampler0, In.uv0);
	float4 texCol = texture2D_AA_lod(TEXTURE_0, TextureSampler0, In.uv0);
#else
	float4 albedo = TEXTURE_0.Sample(TextureSampler0, In.uv0);
	float4 texCol = TEXTURE_0.SampleLevel(TextureSampler0, In.uv0, 0.0);
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
	albedo.a *= In.col.a;
#endif

#ifndef SEASONS
	#if !USE_ALPHA_TEST && !defined(BLEND)
		albedo.a = In.col.a;
	#endif
    if (abs(In.col.r - In.col.g) > 0.001 || abs(In.col.g - In.col.b) > 0.001) {
        albedo.rgb *= normalize(In.col.rgb);
	}
	#ifdef ALPHA_TEST
		if (In.col.b == 0.0) {
			albedo.rgb *= In.col.rgb;
		}
	#endif
#else
	float2 uv = In.col.xy;
	albedo.rgb *= lerp(1.0, TEXTURE_2.Sample(TextureSampler2, uv).rgb * 2.0, In.col.b);
	albedo.rgb *= In.col.aaa;
	albedo.a = 1.0;
#endif

float time = getTime(FOG_COLOR);
float daylight = max(0.0, time);

float3 sunMoonPos = (time > 0.0 ? 1.0 : -1.0) * float3(0.45, 1.0, -0.65) * float3(cos(time), sin(time), -cos(time));
float3 worldNormal = normalize(cross(ddx(-In.worldPos), ddy(In.worldPos)));
float3 reflectPos = reflect(normalize(In.camPos), worldNormal);

float outdoor = smoothstep(0.850, 0.875, In.uv1.y);
float skyLit = lerp(0.0, lerp(0.0, max(0.0, dot(sunMoonPos, worldNormal)), daylight), outdoor);
float sunLit = lerp(0.0, lerp(0.0, max(0.0, dot(sunMoonPos, reflectPos)), daylight), outdoor);
float sunSetLit = lerp(0.0, lerp(0.0, max(0.0, dot(sunMoonPos, reflectPos)), min(smoothstep(0.0, 0.2, daylight), smoothstep(0.6, 0.3, daylight))), outdoor);
sunSetLit *= sunSetLit * sunSetLit * sunSetLit * sunSetLit * sunSetLit;
float moonLit = lerp(0.0, lerp(max(0.0, dot(sunMoonPos, reflectPos)), 0.0, daylight), outdoor);
float torchLit = In.uv1.x * In.uv1.x * In.uv1.x * In.uv1.x;
torchLit = lerp(0.0, torchLit, smoothstep(0.875, 0.5, In.uv1.y * daylight));

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
bool isRealUnderwater = isUnderwater(worldNormal, In.uv1, In.worldPos, texCol, In.col);
float rain = 
#ifdef FOG
	lerp(0.0, lerp(smoothstep(0.5, 0.3, FOG_CONTROL.x), 0.0, underwater), outdoor);
#else
	0.0;
#endif

bool isBlend = false;
#ifdef BLEND
	isBlend = true;
#endif

bool isMetallic = false;
#if !defined(ALPHA_TEST) || !defined(BLEND)
	if (alpha2BlockID(texCol) < 4 && In.col.b == In.col.g && In.col.r == In.col.g) {
		isMetallic = true;
		albedo.rgb = lerp(albedo.rgb, getF0(texCol, albedo).rgb, 1.0);
	}
#endif

float wet = 0.0;

#ifdef ENABLE_RAINY_WET_EFFECTS
	if (rain > 0.0) {
		float cosT = abs(dot(float3(0.0, 1.0, 0.0), normalize(In.camPos)));
		wet = 0.5;
		wet = min(1.0, wet + step(0.7, snoise(In.worldPos.xz * 0.3)) * 0.5);
		wet = lerp(wet * max(0.0, worldNormal.y) * rain, 0.0, cosT);
	}
#endif

float reflectance = 0.0;
if (In.isWater) {
	albedo.rgb = waterCol;
	reflectance = WATER_REFLECTANCE;
} else if (isBlend) {
	reflectance = ALPHA_BLENDED_BLOCK_REFLECTANCE;
} else if (isMetallic) {
	reflectance = METALLIC_BLOCK_REFLECTANCE;
	if (alpha2BlockID(texCol) == 3) {
		reflectance = REFLECTIVE_BLOCK_REFLECTANCE;
	}
} else if (wet > 0.0) {
	reflectance = wet;
}

bool isReflective = false;
if (In.isWater || isBlend || isMetallic || wet > 0.0) {
	isReflective = true;
}

float3x3 tBN = getTBNMatrix(worldNormal);

if (In.isWater && bool(step(0.7, In.uv1.y))) {
	#ifdef ENABLE_WATER_WAVES
		worldNormal = normalize(mul(tBN, waterWaves2Normal(In.worldPos.xz, TOTAL_REAL_WORLD_TIME)));
	#endif
} else if (isReflective && bool(step(0.7, In.uv1.y))) {
	#ifdef ENABLE_BLOCK_NORMAL_MAPS
		worldNormal = normalize(mul(tBN, texture2Normal(In.uv0, 3072.0, 0.0008)));
	#endif
}

reflectPos = reflect(normalize(In.camPos), worldNormal);

float darkenOverWorld = lerp(max(0.2, In.uv1.y * lerp(0.25, 0.65, daylight)), lerp(0.25, 0.65, daylight), outdoor);
float darkenNether = TEXTURE_1.Sample(TextureSampler1, In.uv1).r;

albedo.rgb *= lerp(darkenOverWorld, darkenNether, nether);
albedo.rgb *= shadowCol;

float3 lit = float3(1.0, 1.0, 1.0);

lit *= lerp(float3(1.0, 1.0, 1.0), SKYLIGHT_INTENSITY * skyLitCol, skyLit);
lit *= lerp(float3(1.0, 1.0, 1.0), SUNLIGHT_INTENSITY * sunLitCol, sunLit);
lit *= lerp(float3(1.0, 1.0, 1.0), SUNSETLIGHT_INTENSITY * sunSetLitCol, sunSetLit);
lit *= lerp(float3(1.0, 1.0, 1.0), MOONLIGHT_INTENSITY * moonLitCol, moonLit);
lit *= lerp(float3(1.0, 1.0, 1.0), TORCHLIGHT_INTENSITY * torchLitCol, torchLit);

lit = lerp(lerp(lit, float3(1.0, 1.0, 1.0), rain * 0.65), float3(1.0, 1.0, 1.0), nether);

albedo.rgb *= lit;

#ifndef SEASONS
	albedo.rgb *= getAO(In.col, max(0.0, AMBIENT_OCCLUSION_INTENSITY - min(rgb2luma(lit - 1.0), 1.0)));
#endif

albedo.rgb = uncharted2ToneMap(albedo.rgb, 11.2, 2.2);
albedo.rgb = contrastFilter(albedo.rgb, 1.25);
albedo.rgb = desaturate(albedo.rgb, max(0.0, 0.3 - min(rgb2luma(lit - 1.0), 1.0)));

if (bool(underwater)) {
	albedo.rgb *= 1.0 + waterCol;
}

#ifdef ENABLE_REFLECTIONS
	if (isReflective && !bool(underwater)) {
		float cosTheta = abs(dot(normalize(In.camPos), worldNormal));
		float3 skyPos = reflectPos;

		#include "reflectedview.hlsl"

		albedo.rgb = lerp(albedo.rgb, lerp(albedo.rgb, reflectedView, smoothstep(0.7, 0.875, In.uv1.y)), reflectance);
		if (In.isWater) {
			albedo.a = lerp(0.9, 0.2, cosTheta);
			albedo.a = lerp(albedo.a, 1.0, lerp(0.0, reflectAlpha, smoothstep(0.7, 0.875, In.uv1.y)));
		}
	} 
	#ifdef ENABLE_WATER_CAUSTICS
		else if (isRealUnderwater) {
			float caustic = waterWaves(In.worldPos.xz, TOTAL_REAL_WORLD_TIME) / 0.005;

			albedo.rgb *= lerp(1.1, 1.2, 1.0 - caustic);
		}
	#endif
#endif

#ifdef ENABLE_FOG
	float fogFactor = fog(FOG_CONTROL, length(-In.camPos) / RENDER_DISTANCE);
	float3 fogCol;
	if (bool(underwater) || bool(nether)) {
		fogCol = FOG_COLOR.rgb;
	} else {
		fogCol = uncharted2ToneMap(lit, 11.2, 1.0);
	}
	albedo.rgb = lerp(albedo.rgb, fogCol, fogFactor * 0.5);
#endif

	Out.col = albedo;

#ifdef VR_MODE
	Out.col = max(Out.col, 1.0 / 255.0);
#endif

#endif // !BYPASS_PIXEL_SHADER
}