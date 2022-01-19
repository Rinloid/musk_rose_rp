#include "ShaderConstants.fxh"

struct Input {
	float3 pos : POSITION;
	float4 col : COLOR;
	float2 uv0 : TEXCOORD_0;
	float2 uv1 : TEXCOORD_1;
#ifdef INSTANCEDSTEREO
	uint instID : SV_InstanceID;
#endif
};

struct Output {
	float4 pos : SV_Position;
#ifndef BYPASS_PIXEL_SHADER
	lpfloat4 col : COLOR;
	snorm float2 uv0 : TEXCOORD_0_FB_MSAA;
	snorm float2 uv1 : TEXCOORD_1_FB_MSAA;
#endif
	float3 worldPos : worldPos;
	float3 camPos : camPos;
	bool isWater : isWater;
#ifdef GEOMETRY_INSTANCEDSTEREO
	uint instanceID : SV_InstanceID;
#endif
#ifdef VERTEXSHADER_INSTANCEDSTEREO
	uint renTarget_id : SV_RenderTargetArrayIndex;
#endif
};

bool isPlant(float4 vertexCol, float4 pos) {
    float3 fracPos = frac(pos.xyz);
    #if defined(ALPHA_TEST)
        return (vertexCol.g != vertexCol.b && vertexCol.r < vertexCol.g + vertexCol.b) || (fracPos.y == 0.9375 && (fracPos.z == 0.0 || fracPos.x == 0.0));
    #else
        return false;
    #endif
}

ROOT_SIGNATURE
void main(in Input In, out Output Out) {
#ifndef BYPASS_PIXEL_SHADER
	Out.uv0 = In.uv0;
	Out.uv1 = In.uv1;
	Out.col = In.col;
#endif
Out.worldPos = In.pos.xyz;
#if !defined(SEASONS) && defined(BLEND)
	if (0.05 < In.col.a && In.col.a < 0.95) {
		Out.isWater = true; 
	} else {
		Out.isWater = false;
	}
#else
	Out.isWater = false;
#endif

#ifdef AS_ENTITY_RENDERER
	#ifdef INSTANCEDSTEREO
		Out.pos = mul(WORLDVIEWPROJ_STEREO[In.instID], float4(In.pos, 1.0));
	#else
		Out.pos = mul(WORLDVIEWPROJ, float4(In.pos, 1.0));
	#endif
	Out.camPos = Out.pos;
#else
	Out.camPos = (In.pos.xyz * CHUNK_ORIGIN_AND_SCALE.w) + CHUNK_ORIGIN_AND_SCALE.xyz;

	if (isPlant(In.col, float4(In.pos.xyz, 1.0))) {
		float3 wavPos = abs(In.pos.xyz - 8.0);
		float wave = sin(TOTAL_REAL_WORLD_TIME * 3.5 + 2.0 * wavPos.x + 2.0 * wavPos.z + wavPos.y);

		Out.camPos.x += wave * 0.03 * smoothstep(0.7, 1.0, In.uv1.y);
	}

	#ifdef INSTANCEDSTEREO
		Out.pos = mul(WORLDVIEW_STEREO[In.instID], float4(Out.camPos, 1.0));
		Out.pos = mul(PROJ_STEREO[In.instID], Out.pos);
	#else
		Out.pos = mul(WORLDVIEW, float4(Out.camPos, 1.0));
		Out.pos = mul(PROJ, Out.pos);
	#endif
#endif

#ifdef GEOMETRY_INSTANCEDSTEREO
	Out.instanceID = In.instID;
#endif 
#ifdef VERTEXSHADER_INSTANCEDSTEREO
	Out.renTarget_id = In.instID;
#endif
}
