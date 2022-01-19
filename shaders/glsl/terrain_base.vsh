// __multiversion__
// This signals the loading code to prepend either #version 100 or #version 300 es as apropriate.

#include "vertexVersionCentroid.h"
#if __VERSION__ >= 300
	#ifndef BYPASS_PIXEL_SHADER
		_centroid out vec2 uv0;
		_centroid out vec2 uv1;
	#endif
#else
	#ifndef BYPASS_PIXEL_SHADER
		varying vec2 uv0;
		varying vec2 uv1;
	#endif
#endif

#ifndef BYPASS_PIXEL_SHADER
	varying vec4 inCol;
	varying POS3 camPos;
	varying POS3 worldPos;
	flat varying float waterFlag;
#endif

#include "uniformWorldConstants.h"
#include "uniformPerFrameConstants.h"
#include "uniformShaderConstants.h"
#include "uniformRenderChunkConstants.h"

attribute POS4 POSITION;
attribute vec4 COLOR;
attribute vec2 TEXCOORD_0;
attribute vec2 TEXCOORD_1;

uniform highp float TOTAL_REAL_WORLD_TIME;

bool isPlant(vec4 vertexCol, highp vec4 pos) {
    vec3 fractPos = fract(pos.xyz);
    #if defined(ALPHA_TEST)
        return (vertexCol.g != vertexCol.b && vertexCol.r < vertexCol.g + vertexCol.b) || (fractPos.y == 0.9375 && (fractPos.z == 0.0 || fractPos.x == 0.0));
    #else
        return false;
    #endif
}

void main() {
#ifndef BYPASS_PIXEL_SHADER
    uv0 = TEXCOORD_0;
    uv1 = TEXCOORD_1;
	inCol = COLOR;
#endif
worldPos = POSITION.xyz;
#if !defined(SEASONS) && defined(BLEND)
	if (0.05 < COLOR.a && COLOR.a < 0.95) {
		waterFlag = 1.0; 
	} else {
		waterFlag = 0.0;
	}
#else
	waterFlag = 0.0;
#endif
#ifdef AS_ENTITY_RENDERER
	POS4 pos = WORLDVIEWPROJ * POSITION;
	camPos = pos.xyz;
#else
    camPos = (POSITION.xyz * CHUNK_ORIGIN_AND_SCALE.w) + CHUNK_ORIGIN_AND_SCALE.xyz;

	if (isPlant(COLOR, POSITION)) {
		highp vec3 wavPos = abs(POSITION.xyz - 8.0);
		highp float wave = sin(TOTAL_REAL_WORLD_TIME * 3.5 + 2.0 * wavPos.x + 2.0 * wavPos.z + wavPos.y);

		camPos.x += wave * 0.03 * smoothstep(0.7, 1.0, uv1.y);
	}

    POS4 pos = WORLDVIEW * vec4(camPos, 1.0);
    pos = PROJ * pos;
#endif

    gl_Position = pos;

#ifndef BYPASS_PIXEL_SHADER
	#ifndef FOG
		inCol.rgb += FOG_COLOR.rgb * 0.000001;
	#endif
#endif
}
