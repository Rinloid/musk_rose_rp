#include "ShaderConstants.fxh"

struct Input {
    float3 pos : POSITION;
#ifdef INSTANCEDSTEREO
	uint instID : SV_InstanceID;
#endif
};

struct Output {
    float4 pos : SV_Position;
	float3 worldPos : worldPos;
#ifdef GEOMETRY_INSTANCEDSTEREO
	uint instanceID : SV_InstanceID;
#endif
#ifdef VERTEXSHADER_INSTANCEDSTEREO
	uint renTarget_id : SV_RenderTargetArrayIndex;
#endif
};

ROOT_SIGNATURE
void main(in Input In, out Output Out) {
Out.worldPos = In.pos;
Out.worldPos.y -= 0.128;
Out.worldPos.yz *= -1.0;
#ifdef INSTANCEDSTEREO
	Out.pos = mul(WORLDVIEWPROJ_STEREO[In.instID], float4(In.pos, 1.0));
#else
	Out.pos = mul(WORLDVIEWPROJ, float4(In.pos, 1.0));
#endif
#ifdef GEOMETRY_INSTANCEDSTEREO
	Out.instanceID = In.instID;
#endif 
#ifdef VERTEXSHADER_INSTANCEDSTEREO
	Out.renTarget_id = In.instID;
#endif
}