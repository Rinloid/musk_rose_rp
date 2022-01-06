#ifndef FUNCTIONS_INCLUDED
#define FUNCTIONS_INCLUDED

hmp float hash12(hmp vec2 p) {
	hmp vec3 p3  = fract(vec3(p.xyx) * .1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

hmp float hash13(hmp vec3 p3) {
	p3  = fract(p3 * .1031);
    p3 += dot(p3, p3.zyx + 31.32);
    return fract((p3.x + p3.y) * p3.z);
}

// https://github.com/stegu/webgl-noise/blob/master/src/noise2D.glsl
#define NOISE_SIMPLEX_1_DIV_289 0.00346020761245674740484429065744

hmp float mod289(hmp float x) {
    return x - floor(x * NOISE_SIMPLEX_1_DIV_289) * 289.0;
}

hmp vec2 mod289(hmp vec2 x) {
    return x - floor(x * NOISE_SIMPLEX_1_DIV_289) * 289.0;
}

hmp vec3 mod289(hmp vec3 x) {
    return x - floor(x * NOISE_SIMPLEX_1_DIV_289) * 289.0;
}

hmp vec4 mod289(hmp vec4 x) {
    return x - floor(x * NOISE_SIMPLEX_1_DIV_289) * 289.0;
}

hmp float permute289(hmp float x) {
    return mod289((x * 34.0 + 1.0) * x);
}

hmp vec3 permute289(hmp vec3 x) {
    return mod289((x * 34.0 + 1.0) * x);
}

hmp vec4 permute289(hmp vec4 x) {
    return mod289((x * 34.0 + 1.0) * x);
}

hmp float snoise(hmp vec2 v) {
    const hmp vec4 C = vec4(
        0.211324865405187,   // (3.0-sqrt(3.0))/6.0
        0.366025403784439,   // 0.5*(sqrt(3.0)-1.0)
        -0.577350269189626,  // -1.0 + 2.0 * C.x
        0.024390243902439);  // 1.0 / 41.0

    // First corner
    hmp vec2 i  = floor(v + dot(v, C.yy));
    hmp vec2 x0 = v -   i + dot(i, C.xx);

    // Other corners
    hmp vec2 i1  = x0.x > x0.y ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
    hmp vec4 x12 = x0.xyxy + C.xxzz;
    x12.xy -= i1;

    // Permutations
    i = mod289(i); // Avoid truncation effects in permutation
    hmp vec3 p =
        permute289(
            permute289(
                i.y + vec3(0.0, i1.y, 1.0)
                ) + i.x + vec3(0.0, i1.x, 1.0)
            );

    hmp vec3 m = max(0.5 - vec3(dot(x0, x0), dot(x12.xy, x12.xy), dot(x12.zw, x12.zw)), 0.0);
    m = m*m;
    m = m*m;

    // Gradients: 41 points uniformly over a line, mapped onto a
    // diamond.  The ring size 17*17 = 289 is close to a multiple of
    // 41 (41*7 = 287)
    hmp vec3 x  = 2.0 * fract(p * C.www) - 1.0;
    hmp vec3 h  = abs(x) - 0.5;
    hmp vec3 ox = round(x);
    hmp vec3 a0 = x - ox;

    // Normalise gradients implicitly by scaling m
    m *= inversesqrt(a0 * a0 + h * h);

    // Compute final noise value at P
    hmp vec3 g;
    g.x  = a0.x  * x0.x   + h.x  * x0.y;
    g.yz = a0.yz * x12.xz + h.yz * x12.yw;
    return 130.0 * dot(m, g);
}

#define PI 3.1415

vec3 absorb(const vec3 x, const float y, const float brightness) {
	vec3 absorption = x * -y;
	absorption = exp2(absorption) * brightness;
	
	return absorption;
}

float sunSpot(const hmp vec3 pos, const vec3 sunMoonPos) {
	return smoothstep(0.03, 0.025, distance(pos, sunMoonPos)) * 25.0;
}

float rayleig(const hmp vec3 pos, const vec3 sunMoonPos) {
    float dist = 1.0 - clamp(distance(pos, sunMoonPos), 0.0, 1.0);

	return 1.0 + dist * dist * PI * 0.5;
}

float getMie(const hmp vec3 pos, const vec3 sunMoonPos) {
	float disk = clamp(1.0 - pow(distance(pos, sunMoonPos), 0.1), 0.0, 1.0);
	
	return disk * disk * (3.0 - 2.0 * disk) * 2.0 * PI;
}

vec3 atmo(const hmp vec3 pos, const vec3 sunMoonPos, const vec3 skyCol, const float brightness) {
	float zenith = 0.5 / pow(max(pos.y, 0.05), 0.75);
	float sunPointDistMult =  clamp(length(max(sunMoonPos.y, 0.0)), 0.0, 1.0);
	
	float rayleighMult = rayleig(pos, sunMoonPos);
	
	vec3 absorption = absorb(skyCol, zenith, brightness);
    vec3 sunAbsorption = absorb(skyCol, 0.5 / pow(max(sunMoonPos.y, 0.05), 0.75), brightness);
	vec3 sky = skyCol * zenith * rayleighMult;
	vec3 sun = sunSpot(pos, sunMoonPos) * absorption;
	vec3 mie = getMie(pos, sunMoonPos) * sunAbsorption;
	
	vec3 result = mix(sky * absorption, sky / (sky + 0.5), sunPointDistMult);
    result += sun + mie;
	result *= sunAbsorption * 0.5 + 0.5 * length(sunAbsorption);
	
	return result;
}

#if CLOUD_QUALITY != 0
    float render2DClouds(const hmp vec2 pos, const float rain, const hmp float time) {
        hmp vec2 p = pos;
        p += time * 0.15;
        float body = hash12(floor(p));
        body = (body > mix(0.92, 0.0, rain)) ? 1.0 : 0.0;

        return body;
    }

    vec2 renderThickClouds(const hmp vec3 pos, const float rain, const hmp float time) {
        #if CLOUD_QUALITY == 2
            const int steps = 48;
            const float stepSize = 0.008;
        #elif CLOUD_QUALITY == 1
            const int steps = 24;
            const float stepSize = 0.016;
        #endif

        float clouds = 0.0;
        float cHeight = 0.0;
            for (int i = 0; i < steps; i++) {
                float height = 1.0 + float(i) * stepSize;
                hmp vec2 cloudPos = pos.xz / pos.y * height;
                cloudPos *= 1.5;
                clouds += render2DClouds(cloudPos, rain, time);
                cHeight = mix(cHeight, 1.0, clouds / float(steps) * float(steps) * stepSize);
            }
        clouds /= float(steps);
        clouds = clamp(clouds * 10.0, 0.0, 1.0);
        // clouds > 0.0 ? 1.0 : 0.0;

        return vec2(clouds, cHeight);
    }

    #if CLOUD_SHADE_QUALITY != 0
        float cloudRayMarching(const hmp vec3 pos, const vec3 sunMoonPos, const float height) {
            #if CLOUD_SHADE_QUALITY == 2
                const int raySteps = 5;
                const float stepSize = 0.02;
            #elif CLOUD_SHADE_QUALITY == 1
                const int raySteps = 2;
                const float stepSize = 0.02;
            #endif
            
            hmp vec3 rayStep = normalize(sunMoonPos - pos) * stepSize;
            hmp vec3 rayPos  = pos * 0.08;
            float  inside  = 0.0;
                for (int i = 0; i < raySteps; i++) {
                    rayPos += rayStep;
                    inside += max(0.0, (1.0 - height) - (rayPos.y - pos.y));
                } inside /= float(raySteps);
            
            return inside;
        }
    #endif
#endif

float getStars(const hmp vec3 pos) {
    hmp vec3 p = floor((abs(normalize(pos)) + 16.0) * 265.0);
    float stars = smoothstep(0.998, 1.0, hash13(p));

    return stars;
}

float drawSun(const hmp vec3 pos) {
	return inversesqrt(pos.x * pos.x + pos.y * pos.y + pos.z * pos.z);
}

float diffuseSphere(hmp vec3 spherePosition, float radius, vec3 lightPosition) {
    float sq = radius * radius - spherePosition.x * spherePosition.x - spherePosition.y * spherePosition.y - spherePosition.z * spherePosition.z;

    if (sq < 0.0) {
        return 0.0;
    } else {
        float z = sqrt(sq);
        vec3  normal = normalize(vec3(spherePosition.yx, z));
        return max(0.0, dot(normal, lightPosition));
    }
}

float getMoon(hmp vec3 moonPosition, float moonPhase, float moonScale) {
	vec3 lightPosition = vec3(sin(moonPhase), 0.0, -cos(moonPhase));
    float m = diffuseSphere(moonPosition, moonScale, lightPosition);
    
	return m;
}

mat3 getTBNMatrix(const vec3 normal) {
    vec3 T = vec3(abs(normal.y) + normal.z, 0.0, normal.x);
    vec3 B = cross(T, normal);
    vec3 N = vec3(-normal.x, normal.y, normal.z);

    return mat3(T, B, N);
}

float rgb2luma(vec3 color) {
    return dot(color, vec3(0.22, 0.707, 0.071));
}

vec3 desaturate(vec3 baseColor, float degree) {
    float luma = rgb2luma(baseColor);

    return mix(baseColor, vec3(luma), degree);
}

vec3 jodieReinhardTonemap(vec3 c){
    float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
    vec3 tc = c / (c + 1.0);

    return mix(c / (l + 1.0), tc, tc);
}

vec3 toneMap(vec3 x) {
    const float A = 0.25; // Shoulder strength
    const float B = 0.30; // Linear strength
    const float C = 0.10; // Linear angle
    const float D = 0.20; // Toe strength
    const float E = 0.01; // Toe numerator
    const float F = 0.30; // Toe denominator

    return ((x * (A * x + C * B) + D * E) / (x * (A * x + B) + D * F)) - E / F;
}
vec3 uncharted2ToneMap(vec3 frag, float whiteLevel, float exposureBias) {
    vec3 curr = toneMap(exposureBias * frag);
    vec3 whiteScale = 1.0 / toneMap(vec3(whiteLevel, whiteLevel, whiteLevel));
    vec3 color = curr * whiteScale;

    return clamp(color, 0.0, 1.0);
}

vec3 contrastFilter(vec3 color, float contrast) {
    float t = 0.5 - contrast * 0.5;

    return clamp(color * contrast + t, 0.0, 1.0);
}

float fog(const vec2 control, float dist) {
    float base = sqrt(log(1.0 / 0.015)) / (control.y - control.x);
    dist = max(0.0, dist - control.x);

    float fogFactor = 1.0 / exp(pow(dist * base, 2.0));
    fogFactor = clamp(fogFactor, 0.0, 1.0);

    return 1.0 - fogFactor;
}

float getAO(vec4 vertexCol, const float shrinkLevel) {
    float lum = vertexCol.g * 2.0 - (vertexCol.r < vertexCol.b ? vertexCol.r : vertexCol.b);

    return min(lum + (1.0 - shrinkLevel), 1.0);
}

vec3 texture2Normal(vec2 uv, float resolution, float scale) {
	vec2 texStep = 1.0 / resolution * vec2(2.0, 1.0);
	#if !USE_TEXEL_AA
		float height = length(textureLod(TEXTURE_0, uv, 0.0).rgb);
		vec2 dxy = height - vec2(length(textureLod(TEXTURE_0, uv + vec2(texStep.x, 0.0), 0.0).rgb),
			length(textureLod(TEXTURE_0, uv + vec2(0.0, texStep.y), 0.0).rgb));
	#else
		float height = length(texture2D_AA_lod(TEXTURE_0, uv).rgb);
		vec2 dxy = height - vec2(length(texture2D_AA_lod(TEXTURE_0, uv + vec2(texStep.x, 0.0)).rgb),
			length(texture2D_AA_lod(TEXTURE_0, uv + vec2(0.0, texStep.y)).rgb));
	#endif
    
	return normalize(vec3(dxy * scale / texStep, 1.0));
}

float waterWaves(hmp vec2 p, const hmp float time) {
	float r = 0.0;
    p *= vec2(0.8, 1.4);
    p += cos(time * 3.0 + p.x + p.y + p.x * 2.0 + sin(time * 5.0 + p.y + p.x + p.y)) * 0.1;
    r += snoise(p + time * 0.3);

	return r * 0.005;
}

vec3 waterWaves2Normal(const hmp vec2 pos, const hmp float time) {
    const float texStep = 0.05;

	float h0 = waterWaves(pos, time);
	float h1 = waterWaves(pos + vec2(texStep, 0.0), time);
	float h2 = waterWaves(pos + vec2(-texStep, 0.0), time);
	float h3 = waterWaves(pos + vec2(0.0, texStep), time);
	float h4 = waterWaves(pos + vec2(0.0, -texStep), time);

	float deltaX = ((h1 - h0) + (h0 - h2)) / texStep;
	float deltaY = ((h3 - h0) + (h0 - h4)) / texStep;

	return normalize(vec3(deltaX, deltaY, 1.0 - deltaX * deltaX - deltaY * deltaY));
}

// All codes below is from Origin Shader by linlin.
// Huge thanks to their great effort.  See:
// https://github.com/origin0110/OriginShader
float getTime(const vec4 fogCol) {
	return fogCol.g > 0.213101 ? 1.0 : 
		dot(vec4(fogCol.g * fogCol.g * fogCol.g, fogCol.g * fogCol.g, fogCol.g, 1.0), 
			vec4(349.305545, -159.858192, 30.557216, -1.628452));
}
bool equ3(const vec3 v) {
	return abs(v.x - v.y) < 0.000002 && abs(v.y - v.z) < 0.000002;
}
bool isUnderwater(const vec3 normal, const vec2 uv1, const hmp vec3 worldPos, const vec4 texCol, const vec4 vertexCol) {
	return normal.y > 0.9
	    && uv1.y < 0.9
	    && abs((2.0 * worldPos.y - 15.0) / 16.0 - uv1.y) < 0.00002
	    && !equ3(texCol.rgb)
	    && (equ3(vertexCol.rgb) || vertexCol.a < 0.00001)
	    && abs(fract(worldPos.y) - 0.5) > 0.00001;
}

#endif // !FUNCTIONS_INCLUDED