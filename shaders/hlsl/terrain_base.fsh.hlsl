#include "ShaderConstants.fxh"
#include "util.fxh"

struct Input {
	float4 pos : SV_Position;
#ifndef BYPASS_PIXEL_SHADER
	lpfloat4 col : COLOR;
	snorm float2 uv0 : TEXCOORD_0_FB_MSAA;
	snorm float2 uv1 : TEXCOORD_1_FB_MSAA;
#endif
	float fogFactor : fogFactor;
	float3 fragPos : fragPos;
	float3 relPos : relPos;
	bool isWater : isWater;
};

struct Output {
	float4 col : SV_Target;
};

#include "functions.hlsl"

#define SKY_COL float3(0.4, 0.65, 1.0)
#define RAY_COL float3(0.63, 0.62, 0.45)

#define AMBIENT_LIGHT_INTENSITY 10.0
#define SKYLIGHT_INTENSITY 30.0
#define SUNLIGHT_INTENSITY 30.0
#define MOONLIGHT_INTENSITY 10.0
#define TORCHLIGHT_INTENSITY 60.0

#define SKYLIGHT_COL float3(0.9, 0.98, 1.0)
#define SUNLIGHT_COL float3(1.0, 0.9, 0.85)
#define SUNLIGHT_COL_SET float3(1.0, 0.70, 0.1)
#define TORCHLIGHT_COL float3(1.0, 0.65, 0.3)
#define MOONLIGHT_COL float3(0.2, 0.4, 1.0)

#define EXPOSURE_BIAS 5.0
#define GAMMA 2.3

ROOT_SIGNATURE
void main(in Input In, out Output Out) {
#ifdef BYPASS_PIXEL_SHADER
    discard;
    return;
#else

#if USE_TEXEL_AA
	float4 albedo = texture2D_AA(TEXTURE_0, TextureSampler0, In.uv0);
#else
	float4 albedo = TEXTURE_0.Sample(TextureSampler0, In.uv0);
#endif

float4 texCol = albedo;

#ifdef SEASONS_FAR
	albedo.a = 1.0;
#endif

#if USE_ALPHA_TEST
	if (albedo.a <
#	ifdef ALPHA_TO_COVERAGE
		0.05
#	else
		0.5
#	endif
	) {
		discard;
		return;
	}
#endif

#if defined(BLEND)
	albedo.a *= In.col.a;
#endif

#ifndef SEASONS
#	if !USE_ALPHA_TEST && !defined(BLEND)
		albedo.a = In.col.a;
#	endif
    if (abs(In.col.r - In.col.g) > 0.001 || abs(In.col.g - In.col.b) > 0.001) {
        albedo.rgb *= normalize(In.col.rgb);
	}
#	ifdef ALPHA_TEST
		if (In.col.b == 0.0) {
			albedo.rgb *= In.col.rgb;
		}
#	endif
#else
	float2 uv = In.col.xy;
	albedo.rgb *= lerp(1.0, TEXTURE_2.Sample(TextureSampler2, uv).rgb * 2.0, In.col.b);
	albedo.rgb *= In.col.aaa;
	albedo.a = 1.0;
#endif

bool isMetallic = false;
#if !defined(ALPHA_TEST) && !defined(BLEND)
	if ((0.95 < texCol.a && texCol.a < 1.0) && In.col.b == In.col.g && In.col.r == In.col.g) {
		isMetallic = true;
	}
#endif

float3 skyPos = normalize(In.relPos);
float3 sunPos = float3(-0.4, 1.0, 0.65);
float time = min(getTimeFromFog(FOG_COLOR), 0.7);
float3 sunMoonPos = (time > 0.0 ? 1.0 : -1.0) * sunPos * float3(cos(time), sin(time), -cos(time));
float3 normal = normalize(cross(ddy(In.fragPos), ddx(In.fragPos)));
if (isMetallic) {
	normal = mul(getTexNormal(In.uv0, 4096.0, 0.0012), getTBNMatrix(normal));
	normal = mul(getTexNormal(In.uv0, 8192.0, 0.0008), getTBNMatrix(normal));
}
float outdoor = smoothstep(0.86, 0.875, In.uv1.y);
float diffuse = max(0.0, dot(sunMoonPos, normal));
float daylight = max(0.0, time);
float duskDawn = min(smoothstep(0.0, 0.3, daylight), smoothstep(0.5, 0.3, daylight));
float amnientLightFactor = lerp(0.2, lerp(0.2, 1.4, daylight), In.uv1.y);;
float dirLightFactor = lerp(0.0, diffuse, outdoor);
float emissiveLightFactor = In.uv1.x * In.uv1.x * In.uv1.x * In.uv1.x * In.uv1.x;
float clearWeather = 1.0 - lerp(0.0, lerp(smoothstep(0.5, 0.3, FOG_CONTROL.x), 0.0, step(FOG_CONTROL.x, 0.0)), smoothstep(0.0, 0.875, In.uv1.y));
float3 skylightCol = getSkyLight(reflect(skyPos, normal), sunMoonPos, SKY_COL, daylight, 1.0 - clearWeather);
float3 sunlightCol = lerp(SUNLIGHT_COL, SUNLIGHT_COL_SET, duskDawn);
float3 daylightCol = lerp(skylightCol, sunlightCol, 0.4);
float3 ambientLightCol = lerp(lerp(float3(0.0, 0.0, 0.0), TORCHLIGHT_COL, emissiveLightFactor), lerp(MOONLIGHT_COL, daylightCol, daylight), dirLightFactor);
ambientLightCol += 1.0 - max(max(ambientLightCol.r, ambientLightCol.g), ambientLightCol.b);
float vanillaAO = 0.0;
#ifndef SEASONS
	vanillaAO = 1.0 - (In.col.g * 2.0 - (In.col.r < In.col.b ? In.col.r : In.col.b)) * 1.4;
#endif
float occlShadow = lerp(1.0, 0.2, vanillaAO);

float3 light = float3(0.0, 0.0, 0.0);

light += ambientLightCol * AMBIENT_LIGHT_INTENSITY * amnientLightFactor * occlShadow;
light += sunlightCol * SUNLIGHT_INTENSITY * dirLightFactor * daylight * clearWeather;
light += MOONLIGHT_COL * MOONLIGHT_INTENSITY * dirLightFactor * (1.0 - daylight) * clearWeather;
light += skylightCol * SKYLIGHT_INTENSITY * dirLightFactor * daylight * clearWeather;
light += TORCHLIGHT_COL * TORCHLIGHT_INTENSITY * emissiveLightFactor;

albedo.rgb = pow(albedo.rgb, GAMMA);
albedo.rgb *= light;
albedo.rgb = hdrExposure(albedo.rgb, EXPOSURE_BIAS, 0.2);
albedo.rgb = uncharted2ToneMap(albedo.rgb, EXPOSURE_BIAS);
albedo.rgb = pow(albedo.rgb, 1.0 / GAMMA);
albedo.rgb = contrastFilter(albedo.rgb, GAMMA - 0.6);

if (In.isWater || isMetallic) {
	if (In.isWater) {
		normal = mul(getWaterWavNormal(In.fragPos.xz, TOTAL_REAL_WORLD_TIME), getTBNMatrix(normalize(cross(ddy(In.fragPos), ddx(In.fragPos)))));
	}

	float cosTheta = 1.0 - abs(dot(normalize(In.relPos), normal));
	float3 sky = getSky(reflect(skyPos, normal), sunMoonPos, sunMoonPos, SKY_COL, daylight, 1.0 - clearWeather, TOTAL_REAL_WORLD_TIME, 7);

	if (In.isWater) {
		albedo.rgb = lerp(albedo.rgb, In.col.rgb, outdoor) * 0.5;
		albedo.a = lerp(0.2, 1.0, cosTheta);
	}
	
	albedo.rgb = lerp(albedo.rgb, sky, cosTheta * outdoor);

	float specularLight = getSun(cross(reflect(skyPos, normal), sunMoonPos) * 45.0);
	albedo += specularLight * outdoor;
}

#ifdef FOG
	float fogBrightness = lerp(0.7, 2.0, smoothstep(0.0, 0.1, daylight));
	float3 fogCol = toneMapReinhard(getAtmosphere(skyPos, sunMoonPos, SKY_COL, fogBrightness));

	albedo.rgb = lerp(albedo.rgb, lerp(fogCol, dot(fogCol, 0.4), 1.0 - clearWeather), In.fogFactor);
#endif

#if !defined(BLEND)
	if (!isMetallic) {
		float sunRayFactor = !bool(step(FOG_CONTROL.x, 0.0)) ? min(smoothstep(0.5, 0.875, In.uv1.y) * max(0.0, 1.0 - distance(skyPos, sunMoonPos)) * smoothstep(0.0, 0.1, daylight), 1.0) : 0.0;
		albedo.rgb = lerp(albedo.rgb, RAY_COL, sunRayFactor);
	}
#endif

	Out.col = albedo;

#ifdef VR_MODE
	Out.col = max(Out.col, 1.0 / 255.0);
#endif

#endif /* !BYPASS_PIXEL_SHADER */
}