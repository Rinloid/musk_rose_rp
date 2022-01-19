#ifndef REFLECTEDVIEW_INCLUDED
#define REFLECTEDVIEW_INCLUDED

float skyBrightness = mix(nightSkyBrightness, daySkyBrightness, smoothstep(0.0, 0.1, daylight));

vec3 reflectedView = atmo(skyPos, sunMoonPos, skyCol, skyBrightness);
reflectedView = desaturate(reflectedView, rain);
float reflectAlpha = 0.0;

#ifdef ENABLE_STARS
    float stars = mix(getStars(skyPos), 0.0, smoothstep(0.0, 0.3, daylight));
    float sun = mix(drawSun(cross(skyPos, sunMoonPos) * 20.0), 0.0, smoothstep(0.01, 0.0, daylight));
    float moon = mix(getMoon(cross(skyPos, sunMoonPos) * 260.0, 1.5, 14.0), 0.0, smoothstep(0.0, 0.01, daylight));
    reflectedView += mix(sun + starCol * stars + moonCol * moon, vec3(0.0, 0.0, 0.0), rain);
    reflectAlpha = mix(reflectAlpha, 1.0, max(sun, moon));
#endif

#if CLOUD_QUALITY != 0
    float drawSpace = max(0.0, length(skyPos.xz / (skyPos.y * float(CLOUD_RENDER_DISTAMCE))));
    if (drawSpace < 1.0 && !bool(step(skyPos.y, 0.0))) {
        #if CLOUD_TYPE == 0
            vec2 clouds = renderThickClouds(skyPos, sunMoonPos, rain, TOTAL_REAL_WORLD_TIME);
        #elif CLOUD_TYPE == 1
            vec2 clouds = renderFluffyClouds(skyPos, sunMoonPos, rain, TOTAL_REAL_WORLD_TIME);
        #endif
        clouds = mix(clouds, vec2(0.0, 0.0), drawSpace);

        vec3 shadedCloudCol = cloudCol;

        #ifdef ENABLE_CLOUD_SHADE
            float cloudBrightness = mix(nightCloudBrightness, dayCloudBrightness, smoothstep(0.0, 0.2, daylight));
            
            if (clouds.x > 0.0) {
                shadedCloudCol *= mix(vec3(1.0, 1.0, 1.0), cloudBrightness + reflectedView * 0.5, 1.0 - clouds.y * 0.7);
            }
        #else
            float cloudBrightness = mix(nightCloudBrightness, dayCloudBrightness, smoothstep(0.0, 0.2, daylight));
            
            if (clouds.x > 0.0) {
                shadedCloudCol *= cloudBrightness + reflectedView * 0.5;
            }
        #endif
        
        reflectedView = mix(reflectedView, shadedCloudCol, clouds.x * 0.6);
    }
#endif

reflectedView = jodieReinhardTonemap(reflectedView);
reflectedView = contrastFilter(reflectedView, 1.8);

#endif // !REFLECTEDVIEW_INCLUDED