#include "ShaderConstants.fxh"

struct Input {
    float4 position : SV_Position;
	float3 relPos : relPos;
};

struct Output {
    float4 color : SV_Target;
};

#include "functions.hlsl"

#define SKY_COL float3(0.4, 0.65, 1.0)

ROOT_SIGNATURE
void main(in Input In, out Output Out) {
float3 albedo = float3(0.0, 0.0, 0.0);

float3 skyPos = normalize(In.relPos);
float3 sunPos = float3(-0.4, 1.0, 0.65);
float time = min(getTimeFromFog(FOG_COLOR), 0.7);
float3 sunMoonPos = (time > 0.0 ? 1.0 : -1.0) * sunPos * float3(cos(time), sin(time), -cos(time));
float daylight = max(0.0, time);
float duskDawn = min(smoothstep(0.0, 0.3, daylight), smoothstep(0.5, 0.3, daylight));
float clearWeather = 1.0 - lerp(smoothstep(0.5, 0.3, FOG_CONTROL.x), 0.0, step(FOG_CONTROL.x, 0.0));
float3 sky = getSky(skyPos, sunMoonPos, sunMoonPos, SKY_COL, daylight, 1.0 - clearWeather, TOTAL_REAL_WORLD_TIME, 7);

albedo = sky;

    Out.color = float4(albedo, 1.0);
}
