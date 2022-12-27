#ifndef FUNCTIONS_INCLUDED
#define FUNCTIONS_INCLUDED

vec3 hdrExposure(const vec3 col, const float overExposure, const float underExposure) {
    vec3 overExposed   = col / overExposure;
    vec3 normalExposed = col;
    vec3 underExposed  = col * underExposure;

    return mix(overExposed, underExposed, normalExposed);
}

/*
 ** Uncharted 2 tone mapping
 ** Link (deleted): http://filmicworlds.com/blog/filmic-tonemapping-operators/
 ** Archive: https://bit.ly/3NSGy4r
 */
vec3 uncharted2ToneMap_(vec3 x) {
    const float A = 0.015; // Shoulder strength
    const float B = 0.500; // Linear strength
    const float C = 0.100; // Linear angle
    const float D = 0.010; // Toe strength
    const float E = 0.020; // Toe numerator
    const float F = 0.300; // Toe denominator

    return ((x * (A * x + C * B) + D * E) / (x * (A * x + B) + D * F)) - E / F;
}
vec3 uncharted2ToneMap(const vec3 col, const float exposureBias) {
    const float whiteLevel = 256.0;

    vec3 curr = uncharted2ToneMap_(exposureBias * col);
    vec3 whiteScale = 1.0 / uncharted2ToneMap_(vec3(whiteLevel, whiteLevel, whiteLevel));
    vec3 color = curr * whiteScale;

    return clamp(color, 0.0, 1.0);
}

vec3 contrastFilter(const vec3 col, const float contrast) {
    return (col - 0.5) * max(contrast, 0.0) + 0.5;
}

/*
 ** Atmoshpere based on one by robobo1221.
 ** See: https://www.shadertoy.com/view/Ml2cWG
*/
vec3 getAbsorption(const hmp vec3 pos, const hmp float posY, const float brightness) {
	vec3 absorption = pos * -posY;
	absorption = exp2(absorption) * brightness;
	
	return absorption;
}
float getRayleig(const hmp vec3 pos, const vec3 sunPos) {
    float dist = 1.0 - clamp(distance(pos, sunPos), 0.0, 1.0);

	return 1.0 + dist * dist * 3.14;
}
float getMie(const hmp vec3 pos, const vec3 sunPos) {
	float disk = clamp(1.0 - pow(distance(pos, sunPos), 0.1), 0.0, 1.0);
	
	return disk * disk * (3.0 - 2.0 * disk) * 2.0 * 3.14;
}
vec3 getAtmosphere(const hmp vec3 pos, const vec3 sunPos, const vec3 skyCol, const float brightness) {
	float zenith = 0.5 / sqrt(max(pos.y, 0.05));
	
	vec3 absorption = getAbsorption(skyCol, zenith, brightness);
    vec3 sunAbsorption = getAbsorption(skyCol, 0.5 / pow(max(sunPos.y, 0.05), 0.75), brightness);
	vec3 sky = skyCol * zenith * getRayleig(pos, sunPos);
	vec3 mie = getMie(pos, sunPos) * sunAbsorption;
	
	vec3 result = mix(sky * absorption, sky / (sky + 0.5), clamp(length(max(sunPos.y, 0.0)), 0.0, 1.0));
    result += mie;
	result *= sunAbsorption * 0.5 + 0.5 * length(sunAbsorption);
	
	return result;
}

/*
 ** Hash without sine modded by Rin
 ** Original author: David Hoskins (MIT License)
 ** See: https://www.shadertoy.com/view/4djSRW
*/

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

/*
 ** Simplex Noise modded by Rin
 ** Original author: Ashima Arts (MIT License)
 ** See: https://github.com/ashima/webgl-noise
 **      https://github.com/stegu/webgl-noise
*/
hmp vec2 mod289(hmp vec2 x) {
    return x - floor(x * 1.0 / 289.0) * 289.0;
}
hmp vec3 mod289(hmp vec3 x) {
    return x - floor(x * 1.0 / 289.0) * 289.0;
}
hmp vec3 permute289(hmp vec3 x) {
    return mod289((x * 34.0 + 1.0) * x);
}
hmp float simplexNoise(hmp vec2 v) {
    const vec4 c = vec4(0.211324865405187, 0.366025403784439, -0.577350269189626, 0.024390243902439);

    hmp vec2 i  = floor(v + dot(v, c.yy));
    hmp vec2 x0 = v -   i + dot(i, c.xx);

    hmp vec2 i1  = x0.x > x0.y ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
    hmp vec4 x12 = x0.xyxy + c.xxzz;
    x12.xy -= i1;

    i = mod289(i);
    hmp vec3 p = permute289(permute289(i.y + vec3(0.0, i1.y, 1.0)) + i.x + vec3(0.0, i1.x, 1.0));

    hmp vec3 m = max(0.5 - vec3(dot(x0, x0), dot(x12.xy, x12.xy), dot(x12.zw, x12.zw)), 0.0);
    m *= m * m * m;

    hmp vec3 x  = 2.0 * fract(p * c.www) - 1.0;
    hmp vec3 h  = abs(x) - 0.5;
    hmp vec3 ox = round(x);
    hmp vec3 a0 = x - ox;

    m *= inversesqrt(a0 * a0 + h * h);

    hmp vec3 g;
    g.x  = a0.x  * x0.x   + h.x  * x0.y;
    g.yz = a0.yz * x12.xz + h.yz * x12.yw;
    
    return 130.0 * dot(m, g);
}

hmp float fBM(hmp vec2 x, const float amp, const float lower, const float upper, const float time, const int octaves) {
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

float cloudMap(const hmp vec2 pos, const float time, const float amp, const float rain, const int oct) {
    return fBM(pos, 0.65 - abs(amp) * 0.1, mix(0.8, 0.0, rain), 0.9, time, oct);
}

float cloudMapShade(const hmp vec2 pos, const float time, const float amp, const float rain, const int oct) {
    return fBM(pos * 0.995, 0.64 - abs(amp) * 0.1, mix(0.8, 0.0, rain), 0.9, time, oct);
}

#define ENABLE_CLOUDS
#define ENABLE_CLOUD_SHADING

/*
 ** Generate volumetric clouds with piled 2D noise.
*/
vec2 renderClouds(const hmp vec3 pos, const vec3 sunPos, const float brightness, const float rain, const float time) {
    const float stepSize = 0.048;
    const int cloudSteps = 5;
    const int cloudOctaves = 5;
    const int raySteps = 1;
    const float rayStepSize = 0.2;
    
    float clouds = 0.0;
    float shade = 0.0;
    float amp = -0.5;

    #ifdef ENABLE_CLOUDS
        float drawSpace = max(0.0, length(pos.xz / (pos.y * float(10))));
        if (drawSpace < 1.0 && !bool(step(pos.y, 0.0))) {
            for (int i = 0; i < cloudSteps; i++) {
                float height = 1.0 + float(i) * stepSize;
                hmp vec2 cloudPos = pos.xz / pos.y * height;
                cloudPos *= 0.3 + hash13(floor(pos * 2048.0)) * 0.01;

                clouds = mix(clouds, 1.0, cloudMap(cloudPos, time, amp, rain, cloudOctaves));

                #ifdef ENABLE_CLOUD_SHADING
                    /* 
                    ** Compute self-casting shadows of clouds with
                    * a (sort of) volumetric ray marching!
                    */
                    hmp vec3 rayStep = normalize(sunPos - pos) * rayStepSize;
                    hmp vec3 rayPos = pos;
                    for (int i = 0; i < raySteps; i++) {
                        rayPos += rayStep;
                        float rayHeight = cloudMapShade(cloudPos, time, amp, rain, cloudOctaves);
                        
                        shade += mix(0.0, 1.0, max(0.0, rayHeight - (rayPos.y - pos.y)));
                    }

                #endif
                amp += 1.0 / float(cloudSteps);

            } shade /= float(cloudSteps);
        }

        clouds = mix(clouds, 0.0, drawSpace);
#   endif

    return vec2(clouds, shade);
}

vec3 getAtmosphereClouds(const hmp vec3 pos, const vec3 sunPos, const vec3 skyCol, const float rain, const float brightness, const float daylight, const float time) {
	float zenith = 0.5 / sqrt(max(pos.y, 0.05));
	
	vec3 absorption = getAbsorption(skyCol, zenith, brightness);
    vec3 sunAbsorption = getAbsorption(skyCol, 0.5 / pow(max(sunPos.y, 0.05), 0.75), brightness);
	vec3 sky = skyCol * zenith * getRayleig(pos, sunPos);
	vec2 clouds = renderClouds(pos, sunPos, daylight, rain, time);

	vec3 mie = getMie(pos, sunPos) * sunAbsorption;
	
	vec3 result = mix(sky * absorption, sky / (sky + 0.5), clamp(length(max(sunPos.y, 0.0)), 0.0, 1.0));
	
	float cloudBrightness = clamp(dot(result, vec3(0.4)), 0.0, 1.0);
	vec3 cloudCol = mix(result, vec3(1.0), cloudBrightness);
	cloudCol = mix(cloudCol, vec3(dot(cloudCol, vec3(0.4))), 0.5);
	
	result = mix(result, mix(cloudCol, cloudCol * 0.6, clouds.y), 1.0 / absorption * clouds.x * 0.8);
	
    result += mie;
	result *= sunAbsorption * 0.5 + 0.5 * length(sunAbsorption);
	
	return result;
}

float getStars(const hmp vec3 pos) {
    hmp vec3 p = floor((normalize(pos) + 16.0) * 265.0);
    float stars = smoothstep(0.998, 1.0, hash13(p));

    return stars;
}

float getSun(const hmp vec3 pos) {
	return 1.0 / length(pos);
}

vec3 toneMapReinhard(const hmp vec3 color) {
	vec3 col = color * color;
    float luma = dot(col, vec3(0.4));
    vec3 exposure = col / (col + 1.0);
	vec3 result = mix(col / (luma + 1.0), exposure, exposure);

    return result;
}

vec3 getSky(const hmp vec3 pos, const vec3 sunPos, const vec3 moonPos, const vec3 skyCol, const float daylight, const float rain, const float time, const int moonPhase) {
	vec3 sky = getAtmosphereClouds(pos, sunPos, skyCol, rain, mix(0.7, 2.0, smoothstep(0.0, 0.1, daylight)), daylight, time);
	sky = toneMapReinhard(sky);
	sky += mix(vec3(0.0, 0.0, 0.0), vec3(1.0, 1.0, 1.0), getSun(cross(pos, sunPos) * 127.0));
	sky = mix(sky, vec3(1.0, 0.96, 0.82), getStars(pos) * smoothstep(0.4, 0.0, daylight));

	sky = mix(sky, vec3(dot(sky, vec3(0.4))), rain);
	
	return sky;
}

vec3 getSkyLight(const vec3 pos, const vec3 sunPos, const vec3 skyCol, const float daylight, const float rain) {
	vec3 sky = getAtmosphere(pos, sunPos, skyCol, mix(0.7, 2.0, smoothstep(0.0, 0.1, daylight)));
	sky = toneMapReinhard(sky);

	sky = mix(sky, vec3(dot(sky, vec3(0.4))), rain);

	return sky;
}

#define ENABLE_WATER_WAVES

/*
 ** Generate water waves with simplex noises.
*/
hmp float getWaterWav(const hmp vec2 pos, const float time) {
	float wav = 0.0;
    #ifdef ENABLE_WATER_WAVES
        hmp vec2 p = pos * 0.5;

        wav += simplexNoise(vec2(p.x * 1.4 - time * 0.4, p.y + time * 0.4) * 0.6) * 4.0;
        wav += simplexNoise(vec2(p.x * 1.4 - time * 0.3, p.y + time * 0.2) * 1.2) * 1.2;
        wav += simplexNoise(vec2(p.x * 2.2 - time * 0.3, p.y * 2.8 - time * 0.6)) * 0.4;
    #endif

    return wav * 0.004;
}

/*
 ** Generate a normal map of water waves.
*/
vec3 getWaterWavNormal(const hmp vec2 pos, const float time) {
	const float texStep = 0.04;
    
	float height = getWaterWav(pos, time);
	vec2 delta = vec2(height, height);

    delta.x -= getWaterWav(pos + vec2(texStep, 0.0), time);
    delta.y -= getWaterWav(pos + vec2(0.0, texStep), time);
    
	return normalize(vec3(delta / texStep, 1.0));
}

vec3 getTexNormal(vec2 uv, float resolution, float scale) {
    vec2 texStep = 1.0 / resolution * vec2(2.0, 1.0);
#   if USE_TEXEL_AA
        float height = dot(texture2D_AA(TEXTURE_0, uv).rgb, vec3(0.4));
        vec2 dxy = height - vec2(dot(texture2D_AA(TEXTURE_0, uv + vec2(texStep.x, 0.0)).rgb, vec3(0.4)),
            dot(texture2D_AA(TEXTURE_0, uv + vec2(0.0, texStep.y)).rgb, vec3(0.4)));
#   else
        float height = dot(textureLod(TEXTURE_0, uv, 0.0).rgb, vec3(0.4));
        vec2 dxy = height - vec2(dot(textureLod(TEXTURE_0, uv + vec2(texStep.x, 0.0), 0.0).rgb, vec3(0.4)),
            dot(textureLod(TEXTURE_0, uv + vec2(0.0, texStep.y), 0.0).rgb, vec3(0.4)));
#   endif

	return normalize(vec3(dxy * scale / texStep, 1.0));
}

mat3 getTBNMatrix(const vec3 normal) {
    vec3 T = vec3(abs(normal.y) + normal.z, 0.0, normal.x);
    vec3 B = cross(T, normal);
    vec3 N = vec3(-normal.x, normal.y, normal.z);

    return mat3(T, B, N);
}

int alpha2BlockID(const vec4 texCol) {
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

float getTimeFromFog(const vec4 fogCol) {
	return fogCol.g > 0.213101 ? 1.0 : 
		dot(vec4(fogCol.g * fogCol.g * fogCol.g, fogCol.g * fogCol.g, fogCol.g, 1.0), 
			vec4(349.305545, -159.858192, 30.557216, -1.628452));
}

#endif /* !FUNCTIONS_INCLUDED */