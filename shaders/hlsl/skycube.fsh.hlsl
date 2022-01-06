#include "ShaderConstants.fxh"

struct Input {
    float4 position : SV_Position;
	float3 worldPos : worldPos;
};

struct Output {
    float4 color : SV_Target;
};

#include "SETTINGS.hlsl"
#include "functions.hlsl"

ROOT_SIGNATURE
void main(in Input In, out Output Out) {
if (bool(step(FOG_CONTROL.x, 0.0))) {
    discard;
}
float time = getTime(FOG_COLOR);
float daylight = max(0.0, time);
float rain = smoothstep(0.5, 0.3, FOG_CONTROL.x);
float3 sunMoonPos = (time > 0.0 ? 1.0 : -1.0) * float3(0.45, 1.0, -0.65) * float3(cos(time), sin(time), -cos(time));
float4 albedo = float4(1.0, 1.0, 1.0, 1.0);
float3 skyPos = normalize(In.worldPos);

#include "reflectedview.hlsl"

albedo.rgb = reflectedView;

    Out.color = albedo;
}
