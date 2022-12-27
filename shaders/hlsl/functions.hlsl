#ifndef FUNCTIONS_INCLUDED
#define FUNCTIONS_INCLUDED

float3 hdrExposure(const float3 col, const float overExposure, const float underExposure) {
    float3 overExposed   = col / overExposure;
    float3 normalExposed = col;
    float3 underExposed  = col * underExposure;

    return lerp(overExposed, underExposed, normalExposed);
}

/*
 ** Uncharted 2 tone mapping
 ** Link (deleted): http://filmicworlds.com/blog/filmic-tonemapping-operators/
 ** Archive: https://bit.ly/3NSGy4r
 */
float3 uncharted2ToneMap_(float3 x) {
    static const float A = 0.015; // Shoulder strength
    static const float B = 0.500; // Linear strength
    static const float C = 0.100; // Linear angle
    static const float D = 0.010; // Toe strength
    static const float E = 0.020; // Toe numerator
    static const float F = 0.300; // Toe denominator

    return ((x * (A * x + C * B) + D * E) / (x * (A * x + B) + D * F)) - E / F;
}
float3 uncharted2ToneMap(const float3 col, const float exposureBias) {
    static const float whiteLevel = 256.0;

    float3 curr = uncharted2ToneMap_(exposureBias * col);
    float3 whiteScale = 1.0 / uncharted2ToneMap_(float3(whiteLevel, whiteLevel, whiteLevel));
    float3 color = curr * whiteScale;

    return clamp(color, 0.0, 1.0);
}

float3 contrastFilter(const float3 col, const float contrast) {
    return (col - 0.5) * max(contrast, 0.0) + 0.5;
}

/*
 ** Atmoshpere based on one by robobo1221.
 ** See: https://www.shadertoy.com/view/Ml2cWG
*/
float3 getAbsorption(const float3 pos, const float posY, const float brightness) {
	float3 absorption = pos * -posY;
	absorption = exp2(absorption) * brightness;
	
	return absorption;
}
float getRayleig(const float3 pos, const float3 sunPos) {
    float dist = 1.0 - clamp(distance(pos, sunPos), 0.0, 1.0);

	return 1.0 + dist * dist * 3.14;
}
float getMie(const float3 pos, const float3 sunPos) {
	float disk = clamp(1.0 - pow(distance(pos, sunPos), 0.1), 0.0, 1.0);
	
	return disk * disk * (3.0 - 2.0 * disk) * 2.0 * 3.14;
}
float3 getAtmosphere(const float3 pos, const float3 sunPos, const float3 skyCol, const float brightness) {
	float zenith = 0.5 / sqrt(max(pos.y, 0.05));
	
	float3 absorption = getAbsorption(skyCol, zenith, brightness);
    float3 sunAbsorption = getAbsorption(skyCol, 0.5 / pow(max(sunPos.y, 0.05), 0.75), brightness);
	float3 sky = skyCol * zenith * getRayleig(pos, sunPos);
	float3 mie = getMie(pos, sunPos) * sunAbsorption;
	
	float3 result = lerp(sky * absorption, sky / (sky + 0.5), clamp(length(max(sunPos.y, 0.0)), 0.0, 1.0));
    result += mie;
	result *= sunAbsorption * 0.5 + 0.5 * length(sunAbsorption);
	
	return result;
}

/*
 ** Hash without sine modded by Rin
 ** Original author: David Hoskins (MIT License)
 ** See: https://www.shadertoy.com/view/4djSRW
*/

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

/*
 ** Simplex Noise modded by Rin
 ** Original author: Ashima Arts (MIT License)
 ** See: https://github.com/ashima/webgl-noise
 **      https://github.com/stegu/webgl-noise
*/
float2 mod289(float2 x) {
    return x - floor(x * 1.0 / 289.0) * 289.0;
}
float3 mod289(float3 x) {
    return x - floor(x * 1.0 / 289.0) * 289.0;
}
float3 permute289(float3 x) {
    return mod289((x * 34.0 + 1.0) * x);
}
float simplexNoise(float2 v) {
    static const float4 c = float4(0.211324865405187, 0.366025403784439, -0.577350269189626, 0.024390243902439);

    float2 i  = floor(v + dot(v, c.yy));
    float2 x0 = v -   i + dot(i, c.xx);

    float2 i1  = x0.x > x0.y ? float2(1.0, 0.0) : float2(0.0, 1.0);
    float4 x12 = x0.xyxy + c.xxzz;
    x12.xy -= i1;

    i = mod289(i);
    float3 p = permute289(permute289(i.y + float3(0.0, i1.y, 1.0)) + i.x + float3(0.0, i1.x, 1.0));

    float3 m = max(0.5 - float3(dot(x0, x0), dot(x12.xy, x12.xy), dot(x12.zw, x12.zw)), 0.0);
    m *= m * m * m;

    float3 x  = 2.0 * frac(p * c.www) - 1.0;
    float3 h  = abs(x) - 0.5;
    float3 ox = round(x);
    float3 a0 = x - ox;

    m *= rsqrt(a0 * a0 + h * h);

    float3 g;
    g.x  = a0.x  * x0.x   + h.x  * x0.y;
    g.yz = a0.yz * x12.xz + h.yz * x12.yw;
    
    return 130.0 * dot(m, g);
}

float fBM(float2 x, const float amp, const float lower, const float upper, const float time, const int octaves) {
    float v = 0.0;
    float amptitude = amp;

    x += time * 0.01;

    for (int i = 0; i < octaves; i++) {
        v += amptitude * (simplexNoise(x) * 0.5 + 0.5);

        /* Optimization */
        if (v >= upper) {
            break;
        } else if (v + amptitude <= lower) {
            break;
        }

        x         *= 2.0;
        x.y       -= float(i + 1) * time * 0.025;
        amptitude *= 0.5;
    }

	return smoothstep(lower, upper, v);
}

float cloudMap(const float2 pos, const float time, const float amp, const float rain, const int oct) {
    return fBM(pos, 0.65 - abs(amp) * 0.1, lerp(0.8, 0.0, rain), 0.9, time, oct);
}

float cloudMapShade(const float2 pos, const float time, const float amp, const float rain, const int oct) {
    return fBM(pos * 0.995, 0.64 - abs(amp) * 0.1, lerp(0.8, 0.0, rain), 0.9, time, oct);
}

#define ENABLE_CLOUDS
#define ENABLE_CLOUD_SHADING

/*
 ** Generate volumetric clouds with piled 2D noise.
*/
float2 renderClouds(const float3 pos, const float3 sunPos, const float brightness, const float rain, const float time) {
    static const float stepSize = 0.048;
    static const int cloudSteps = 5;
    static const int cloudOctaves = 5;
    static const int raySteps = 1;
    static const float rayStepSize = 0.2;
    
    float clouds = 0.0;
    float shade = 0.0;
    float amp = -0.5;

    #ifdef ENABLE_CLOUDS
        float drawSpace = max(0.0, length(pos.xz / (pos.y * float(10))));
        if (drawSpace < 1.0 && !bool(step(pos.y, 0.0))) {
            for (int i = 0; i < cloudSteps; i++) {
                float height = 1.0 + float(i) * stepSize;
                float2 cloudPos = pos.xz / pos.y * height;
                cloudPos *= 0.3 + hash13(floor(pos * 2048.0)) * 0.01;

                clouds = lerp(clouds, 1.0, cloudMap(cloudPos, time, amp, rain, cloudOctaves));

                #ifdef ENABLE_CLOUD_SHADING
                    /* 
                    ** Compute self-casting shadows of clouds with
                    * a (sort of) volumetric ray marching!
                    */
                    float3 rayStep = normalize(sunPos - pos) * rayStepSize;
                    float3 rayPos = pos;
                    for (int i = 0; i < raySteps; i++) {
                        rayPos += rayStep;
                        float rayHeight = cloudMapShade(cloudPos, time, amp, rain, cloudOctaves);
                        
                        shade += lerp(0.0, 1.0, max(0.0, rayHeight - (rayPos.y - pos.y)));
                    }

                #endif
                amp += 1.0 / float(cloudSteps);

            } shade /= float(cloudSteps);
        }

        clouds = lerp(clouds, 0.0, drawSpace);
#   endif

    return float2(clouds, shade);
}

float3 getAtmosphereClouds(const float3 pos, const float3 sunPos, const float3 skyCol, const float rain, const float brightness, const float daylight, const float time) {
	float zenith = 0.5 / sqrt(max(pos.y, 0.05));
	
	float3 absorption = getAbsorption(skyCol, zenith, brightness);
    float3 sunAbsorption = getAbsorption(skyCol, 0.5 / pow(max(sunPos.y, 0.05), 0.75), brightness);
	float3 sky = skyCol * zenith * getRayleig(pos, sunPos);
	float2 clouds = renderClouds(pos, sunPos, daylight, rain, time);

	float3 mie = getMie(pos, sunPos) * sunAbsorption;
	
	float3 result = lerp(sky * absorption, sky / (sky + 0.5), clamp(length(max(sunPos.y, 0.0)), 0.0, 1.0));
	
	float cloudBrightness = clamp(dot(result, 0.4), 0.0, 1.0);
	float3 cloudCol = lerp(result, 1.0, cloudBrightness);
	cloudCol = lerp(cloudCol, dot(cloudCol, 0.4), 0.5);
	
	result = lerp(result, lerp(cloudCol, cloudCol * 0.6, clouds.y), 1.0 / absorption * clouds.x * 0.8);
	
    result += mie;
	result *= sunAbsorption * 0.5 + 0.5 * length(sunAbsorption);
	
	return result;
}

float getStars(const float3 pos) {
    float3 p = floor((normalize(pos) + 16.0) * 265.0);
    float stars = smoothstep(0.998, 1.0, hash13(p));

    return stars;
}

float getSun(const float3 pos) {
	return 1.0 / length(pos);
}

float3 toneMapReinhard(const float3 color) {
	float3 col = color * color;
    float luma = dot(col, 0.4);
    float3 exposure = col / (col + 1.0);
	float3 result = lerp(col / (luma + 1.0), exposure, exposure);

    return result;
}

float3 getSky(const float3 pos, const float3 sunPos, const float3 moonPos, const float3 skyCol, const float daylight, const float rain, const float time, const int moonPhase) {
	float3 sky = getAtmosphereClouds(pos, sunPos, skyCol, rain, lerp(0.7, 2.0, smoothstep(0.0, 0.1, daylight)), daylight, time);
	sky = toneMapReinhard(sky);
	sky += lerp(float3(0.0, 0.0, 0.0), float3(1.0, 1.0, 1.0), getSun(cross(pos, sunPos) * 127.0));
	sky = lerp(sky, float3(1.0, 0.96, 0.82), getStars(pos) * smoothstep(0.4, 0.0, daylight));

	sky = lerp(sky, dot(sky, 0.4), rain);
	
	return sky;
}

float3 getSkyLight(const float3 pos, const float3 sunPos, const float3 skyCol, const float daylight, const float rain) {
	float3 sky = getAtmosphere(pos, sunPos, skyCol, lerp(0.7, 2.0, smoothstep(0.0, 0.1, daylight)));
	sky = toneMapReinhard(sky);

	sky = lerp(sky, dot(sky, 0.4), rain);

	return sky;
}

#define ENABLE_WATER_WAVES

/*
 ** Generate water waves with simplex noises.
*/
float getWaterWav(const float2 pos, const float time) {
	float wav = 0.0;
    #ifdef ENABLE_WATER_WAVES
        float2 p = pos * 0.5;

        wav += simplexNoise(float2(p.x * 1.4 - time * 0.4, p.y + time * 0.4) * 0.6) * 4.0;
        wav += simplexNoise(float2(p.x * 1.4 - time * 0.3, p.y + time * 0.2) * 1.2) * 1.2;
        wav += simplexNoise(float2(p.x * 2.2 - time * 0.3, p.y * 2.8 - time * 0.6)) * 0.4;
    #endif

    return wav * 0.004;
}

/*
 ** Generate a normal map of water waves.
*/
float3 getWaterWavNormal(const float2 pos, const float time) {
	static const float texStep = 0.04;
    
	float height = getWaterWav(pos, time);
	float2 delta = float2(height, height);

    delta.x -= getWaterWav(pos + float2(texStep, 0.0), time);
    delta.y -= getWaterWav(pos + float2(0.0, texStep), time);
    
	return normalize(float3(delta / texStep, 1.0));
}

float3 getTexNormal(float2 uv, float resolution, float scale) {
    float2 texStep = 1.0 / resolution * float2(2.0, 1.0);
#   if USE_TEXEL_AA
        float height = dot(texture2D_AA(TEXTURE_0, TextureSampler0, uv).rgb, 0.4);
        float2 dxy = height - float2(dot(texture2D_AA(TEXTURE_0, TextureSampler0, uv + float2(texStep.x, 0.0)).rgb, 0.4),
            dot(texture2D_AA(TEXTURE_0, TextureSampler0, uv + float2(0.0, texStep.y)).rgb, 0.4));
#   else
        float height = dot(TEXTURE_0.SampleLevel(TextureSampler0, uv, 0.0).rgb, 0.4);
        float2 dxy = height - float2(dot(TEXTURE_0.SampleLevel(TextureSampler0, uv + float2(texStep.x, 0.0), 0.0).rgb, 0.4),
            dot(TEXTURE_0.SampleLevel(TextureSampler0, uv + float2(0.0, texStep.y), 0.0).rgb, 0.4));
#   endif

	return normalize(float3(dxy * scale / texStep, 1.0));
}

float3x3 getTBNMatrix(const float3 normal) {
    float3 T = float3(abs(normal.y) + normal.z, 0.0, normal.x);
    float3 B = cross(T, normal);
    float3 N = float3(-normal.x, normal.y, normal.z);

    return float3x3(T, B, N);
}

int alpha2BlockID(const float4 texCol) {
    bool iron   = 0.99 <= texCol.a && texCol.a < 1.00;
    bool gold   = 0.98 <= texCol.a && texCol.a < 0.99;
    bool copper = 0.97 <= texCol.a && texCol.a < 0.98;
    bool other  = 0.96 <= texCol.a && texCol.a < 0.97;

    return iron ? 0 : gold ? 1 : copper ? 2 : other ? 3 : 4;
}

/*
 * All codes below are from Origin Shader by linlin.
 * Huge thanks to their great effort.  See:
 * https://github.com/origin0110/OriginShader
*/

float getTimeFromFog(const float4 fogCol) {
	return fogCol.g > 0.213101 ? 1.0 : 
		dot(float4(fogCol.g * fogCol.g * fogCol.g, fogCol.g * fogCol.g, fogCol.g, 1.0), 
			float4(349.305545, -159.858192, 30.557216, -1.628452));
}

#endif /* !FUNCTIONS_INCLUDED */