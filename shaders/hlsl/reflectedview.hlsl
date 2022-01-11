#ifndef REFLECTEDVIEW_INCLUDED
#define REFLECTEDVIEW_INCLUDED

float skyBrightness = lerp(nightSkyBrightness, daySkyBrightness, smoothstep(0.0, 0.1, daylight));

float3 reflectedView = atmo(skyPos, sunMoonPos, skyCol, skyBrightness);
reflectedView = desaturate(reflectedView, rain);
float reflectAlpha = 0.0;

#ifdef ENABLE_STARS
    float stars = lerp(getStars(skyPos), 0.0, smoothstep(0.0, 0.3, daylight));
    float sun = lerp(drawSun(cross(skyPos, sunMoonPos) * 20.0), 0.0, smoothstep(0.01, 0.0, daylight));
    float moon = lerp(getMoon(cross(skyPos, sunMoonPos) * 260.0, 1.5, 14.0), 0.0, smoothstep(0.0, 0.01, daylight));
    reflectedView += lerp(sun + starCol * stars + moonCol * moon, float3(0.0, 0.0, 0.0), rain);
    reflectAlpha = lerp(reflectAlpha, 1.0, max(sun, moon));
#endif

#if CLOUD_QUALITY != 0
    float drawSpace = max(0.0, length(skyPos.xz / (skyPos.y * float(CLOUD_RENDER_DISTAMCE))));
    if (drawSpace < 1.0 && !bool(step(skyPos.y, 0.0))) {
        float2 clouds = renderThickClouds(skyPos, rain, TOTAL_REAL_WORLD_TIME);
        clouds = lerp(clouds, float2(0.0, 0.0), drawSpace);

        float3 shadedCloudCol = cloudCol;

        #ifdef ENABLE_CLOUD_SHADE
            float cloudBrightness = lerp(nightCloudBrightness, dayCloudBrightness, smoothstep(0.0, 0.2, daylight));
            
            if (clouds.x > 0.0) {
                shadedCloudCol *= lerp(float3(1.0, 1.0, 1.0), cloudBrightness + reflectedView * 0.5, 1.0 - clouds.y * 0.7);
            }
        #else
            float cloudBrightness = lerp(nightCloudBrightness, dayCloudBrightness, smoothstep(0.0, 0.2, daylight));
            
            if (clouds.x > 0.0) {
                shadedCloudCol *= cloudBrightness + reflectedView * 0.5;
            }
        #endif
        
        reflectedView = lerp(reflectedView, shadedCloudCol, clouds.x * 0.6);
    }
#endif

reflectedView = jodieReinhardTonemap(reflectedView);
reflectedView = contrastFilter(reflectedView, 1.8);

#endif // !REFLECTEDVIEW_INCLUDED