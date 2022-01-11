#ifndef FUNCTIONS_INCLUDED
#define FUNCTIONS_INCLUDED

// https://www.shadertoy.com/view/4djSRW
float hash12(float2 p) {
	float3 p3  = frac(float3(p.xyx) * .1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return frac((p3.x + p3.y) * p3.z);
}

float hash13(float3 p3) {
	p3  = frac(p3 * .1031);
    p3 += dot(p3, p3.zyx + 31.32);
    return frac((p3.x + p3.y) * p3.z);
}

// https://github.com/stegu/webgl-noise/blob/master/src/noise2D.glsl
#define NOISE_SIMPLEX_1_DIV_289 0.00346020761245674740484429065744

float mod289(float x) {
    return x - floor(x * NOISE_SIMPLEX_1_DIV_289) * 289.0;
}

float2 mod289(float2 x) {
    return x - floor(x * NOISE_SIMPLEX_1_DIV_289) * 289.0;
}

float3 mod289(float3 x) {
    return x - floor(x * NOISE_SIMPLEX_1_DIV_289) * 289.0;
}

float4 mod289(float4 x) {
    return x - floor(x * NOISE_SIMPLEX_1_DIV_289) * 289.0;
}

float permute289(float x) {
    return mod289((x * 34.0 + 1.0) * x);
}

float3 permute289(float3 x) {
    return mod289((x * 34.0 + 1.0) * x);
}

float4 permute289(float4 x) {
    return mod289((x * 34.0 + 1.0) * x);
}

float snoise(float2 v) {
    const float4 C = float4(
        0.211324865405187,   // (3.0-sqrt(3.0))/6.0
        0.366025403784439,   // 0.5*(sqrt(3.0)-1.0)
        -0.577350269189626,  // -1.0 + 2.0 * C.x
        0.024390243902439);  // 1.0 / 41.0

    // First corner
    float2 i  = floor(v + dot(v, C.yy));
    float2 x0 = v -   i + dot(i, C.xx);

    // Other corners
    float2 i1  = x0.x > x0.y ? float2(1.0, 0.0) : float2(0.0, 1.0);
    float4 x12 = x0.xyxy + C.xxzz;
    x12.xy -= i1;

    // Permutations
    i = mod289(i); // Avoid truncation effects in permutation
    float3 p =
        permute289(
            permute289(
                i.y + float3(0.0, i1.y, 1.0)
                ) + i.x + float3(0.0, i1.x, 1.0)
            );

    float3 m = max(0.5 - float3(dot(x0, x0), dot(x12.xy, x12.xy), dot(x12.zw, x12.zw)), 0.0);
    m = m*m;
    m = m*m;

    // Gradients: 41 points uniformly over a line, mapped onto a
    // diamond.  The ring size 17*17 = 289 is close to a multiple of
    // 41 (41*7 = 287)
    float3 x  = 2.0 * frac(p * C.www) - 1.0;
    float3 h  = abs(x) - 0.5;
    float3 ox = round(x);
    float3 a0 = x - ox;

    // Normalise gradients implicitly by scaling m
    m *= rsqrt(a0 * a0 + h * h);

    // Compute final noise value at P
    float3 g;
    g.x  = a0.x  * x0.x   + h.x  * x0.y;
    g.yz = a0.yz * x12.xz + h.yz * x12.yw;
    return 130.0 * dot(m, g);
}

#define PI 3.1415

float3 absorb(const float3 x, const float y, const float brightness) {
	float3 absorption = x * -y;
	absorption = exp2(absorption) * brightness;
	
	return absorption;
}

float sunSpot(const float3 pos, const float3 sunMoonPos) {
	return smoothstep(0.03, 0.025, distance(pos, sunMoonPos)) * 25.0;
}

float rayleig(const float3 pos, const float3 sunMoonPos) {
    float dist = 1.0 - clamp(distance(pos, sunMoonPos), 0.0, 1.0);

	return 1.0 + dist * dist * PI * 0.5;
}

float getMie(const float3 pos, const float3 sunMoonPos) {
	float disk = clamp(1.0 - pow(distance(pos, sunMoonPos), 0.1), 0.0, 1.0);
	
	return disk * disk * (3.0 - 2.0 * disk) * 2.0 * PI;
}

float3 atmo(const float3 pos, const float3 sunMoonPos, const float3 skyCol, const float brightness) {
	float zenith = 0.5 / pow(max(pos.y, 0.05), 0.75);
	float sunPointDistMult =  clamp(length(max(sunMoonPos.y, 0.0)), 0.0, 1.0);
	
	float rayleighMult = rayleig(pos, sunMoonPos);
	
	float3 absorption = absorb(skyCol, zenith, brightness);
    float3 sunAbsorption = absorb(skyCol, 0.5 / pow(max(sunMoonPos.y, 0.05), 0.75), brightness);
	float3 sky = skyCol * zenith * rayleighMult;
	float3 sun = sunSpot(pos, sunMoonPos) * absorption;
	float3 mie = getMie(pos, sunMoonPos) * sunAbsorption;
	
	float3 result = lerp(sky * absorption, sky / (sky + 0.5), sunPointDistMult);
    result += sun + mie;
	result *= sunAbsorption * 0.5 + 0.5 * length(sunAbsorption);
	
	return result;
}

float render2DClouds(const float2 pos, const float rain, const float time) {
    float2 p = pos;
    p += time * 0.1;
    float body = hash12(floor(p));
    body = (body > lerp(0.92, 0.0, rain)) ? 1.0 : 0.0;

    return body;
}

float2 renderThickClouds(const float3 pos, const float rain, const float time) {
    #if CLOUD_QUALITY == 2
        static const int steps = 48;
        static const float stepSize = 0.008;
    #elif CLOUD_QUALITY == 1
        static const int steps = 24;
        static const float stepSize = 0.016;
    #endif

    float clouds = 0.0;
    float cHeight = 0.0;
        for (int i = 0; i < steps; i++) {
            float height = 1.0 + float(i) * stepSize;
            float2 cloudPos = pos.xz / pos.y * height;
            cloudPos *= 1.5;
            clouds += render2DClouds(cloudPos, rain, time);
            cHeight = lerp(cHeight, 1.0, clouds / float(steps) * float(steps) * stepSize);
        }
    clouds /= float(steps);
    clouds = clamp(clouds * 10.0, 0.0, 1.0);
    // clouds > 0.0 ? 1.0 : 0.0;

    return float2(clouds, cHeight);
}

float getStars(const float3 pos) {
    float3 p = floor((abs(normalize(pos)) + 16.0) * 265.0);
    float stars = smoothstep(0.998, 1.0, hash13(p));

    return stars;
}

float drawSun(const float3 pos) {
	return rsqrt(pos.x * pos.x + pos.y * pos.y + pos.z * pos.z);
}

float diffuseSphere(float3 spherePosition, float radius, float3 lightPosition) {
    float sq = radius * radius - spherePosition.x * spherePosition.x - spherePosition.y * spherePosition.y - spherePosition.z * spherePosition.z;

    if (sq < 0.0) {
        return 0.0;
    } else {
        float z = sqrt(sq);
        float3  normal = normalize(float3(spherePosition.yx, z));
        return max(0.0, dot(normal, lightPosition));
    }
}

float getMoon(float3 moonPosition, float moonPhase, float moonScale) {
	float3 lightPosition = float3(sin(moonPhase), 0.0, -cos(moonPhase));
    float m = diffuseSphere(moonPosition, moonScale, lightPosition);
    
	return m;
}

float3x3 getTBNMatrix(const float3 normal) {
    float3 T = float3(abs(normal.y) + normal.z, 0.0, normal.x);
    float3 B = cross(T, normal);
    float3 N = float3(-normal.x, normal.y, normal.z);

    return transpose(float3x3(T, B, N));
}

float rgb2luma(float3 color) {
    return dot(color, float3(0.22, 0.707, 0.071));
}

float3 desaturate(float3 baseColor, float degree) {
    float luma = rgb2luma(baseColor);

    return lerp(baseColor, luma, degree);
}

float3 jodieReinhardTonemap(float3 c){
    float l = dot(c, float3(0.2126, 0.7152, 0.0722));
    float3 tc = c / (c + 1.0);

    return lerp(c / (l + 1.0), tc, tc);
}

float3 toneMap(float3 x) {
    static const float A = 0.25; // Shoulder strength
    static const float B = 0.30; // Linear strength
    static const float C = 0.10; // Linear angle
    static const float D = 0.20; // Toe strength
    static const float E = 0.01; // Toe numerator
    static const float F = 0.30; // Toe denominator

    return ((x * (A * x + C * B) + D * E) / (x * (A * x + B) + D * F)) - E / F;
}
float3 uncharted2ToneMap(float3 frag, float whiteLevel, float exposureBias) {
    float3 curr = toneMap(exposureBias * frag);
    float3 whiteScale = 1.0 / toneMap(float3(whiteLevel, whiteLevel, whiteLevel));
    float3 color = curr * whiteScale;

    return clamp(color, 0.0, 1.0);
}

float3 contrastFilter(float3 color, float contrast) {
    float t = 0.5 - contrast * 0.5;

    return clamp(color * contrast + t, 0.0, 1.0);
}

float fog(const float2 control, float dist) {
    float base = sqrt(log(1.0 / 0.015)) / (control.y - control.x);
    dist = max(0.0, dist - control.x);

    float fogFactor = 1.0 / exp(pow(dist * base, 2.0));
    fogFactor = clamp(fogFactor, 0.0, 1.0);

    return 1.0 - fogFactor;
}

float getAO(float4 vertexCol, const float shrinkLevel) {
    float lum = vertexCol.g * 2.0 - (vertexCol.r < vertexCol.b ? vertexCol.r : vertexCol.b);

    return min(lum + (1.0 - shrinkLevel), 1.0);
}

float3 texture2Normal(float2 uv, float resolution, float scale) {
	float2 texStep = 1.0 / resolution * float2(2.0, 1.0);
	#if !USE_TEXEL_AA
		float height = length(TEXTURE_0.SampleLevel(TextureSampler0, uv, 0.0).rgb);
		float2 dxy = height - float2(length(TEXTURE_0.SampleLevel(TextureSampler0, uv + float2(texStep.x, 0.0), 0.0).rgb),
			length(TEXTURE_0.SampleLevel(TextureSampler0, uv + float2(0.0, texStep.y), 0.0).rgb));
	#else
		float height = texture2D_AA_lod(length(TEXTURE_0, TextureSampler0, uv).rgb);
		float2 dxy = height - float2(texture2D_AA_lod(length(TEXTURE_0, TextureSampler0, uv + float2(texStep.x, 0.0)).rgb),
			texture2D_AA_lod(length(TEXTURE_0, TextureSampler0, uv + float2(0.0, texStep.y)).rgb));
	#endif
    
	return normalize(float3(dxy * scale / texStep, 1.0));
}

float waterWaves(float2 p, const float time) {
	float r = 0.0;
    p *= float2(0.8, 1.4);
    p += cos(time * 3.0 + p.x + p.y + p.x * 2.0 + sin(time * 5.0 + p.y + p.x + p.y)) * 0.1;
    r += snoise(p + time * 0.3);

	return r * 0.005;
}

float3 waterWaves2Normal(const float2 pos, const float time) {
	static const float texStep = 0.04;
	float height = waterWaves(pos, time);
	float2 dxy = height - float2(waterWaves(pos + float2(texStep, 0.0), time),
		waterWaves(pos + float2(0.0, texStep), time));
    
	return normalize(float3(dxy / texStep, 1.0));
}

// All codes below is from Origin Shader by linlin.
// Huge thanks to their great effort.  See:
// https://github.com/origin0110/OriginShader
float getTime(const float4 fogCol) {
	return fogCol.g > 0.213101 ? 1.0 : 
		dot(float4(fogCol.g * fogCol.g * fogCol.g, fogCol.g * fogCol.g, fogCol.g, 1.0), 
			float4(349.305545, -159.858192, 30.557216, -1.628452));
}
bool equ3(const float3 v) {
	return abs(v.x - v.y) < 0.000002 && abs(v.y - v.z) < 0.000002;
}
bool isUnderwater(const float3 normal, const float2 uv1, const float3 worldPos, const float4 texCol, const float4 vertexCol) {
	return normal.y > 0.9
	    && uv1.y < 0.9
	    && abs((2.0 * worldPos.y - 15.0) / 16.0 - uv1.y) < 0.00002
	    && !equ3(texCol.rgb)
	    && (equ3(vertexCol.rgb) || vertexCol.a < 0.00001)
	    && abs(frac(worldPos.y) - 0.5) > 0.00001;
}

#endif // !FUNCTIONS_INCLUDED