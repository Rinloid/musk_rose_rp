#ifndef CONSTANTS_INCLUDED
#define CONSTANTS_INCLUDED
// ^ don't delete them.






// 0: off, fastest
// 1: low steps, fast
// 2: high steps, slow
#define CLOUD_QUALITY 2

// 0: off, fastest
// 1: low steps, fast
// 2: high steps, slow
#define CLOUD_SHADE_QUALITY 2

#define CLOUD_RENDER_DISTAMCE 32

// Delete or comment out to disable.
#define ENABLE_WATER_WAVES
#define ENABLE_WATER_CAUSTICS
#define ENABLE_BLOCK_NORMAL_MAPS
#define ENABLE_REFLECTIONS
#define ENABLE_FOG
#define ENABLE_STARS



// Colours
const vec3 skyCol = vec3(0.4, 0.65, 1.0);
const float nightSkyBrightness = 0.5;
const float daySkyBrightness = 2.0;

const vec3 cloudCol = vec3(0.158, 0.15, 0.15);
const float nightCloudBrightness = 3.0;
const float dayCloudBrightness = 18.0;

const vec3 starCol = vec3(1.0, 0.98, 0.97);
const vec3 moonCol = vec3(1.0, 0.95, 0.8);

// Terrain
const vec3 skyLitCol = vec3(1.0, 1.0, 1.0);
const vec3 sunLitCol = vec3(1.0, 0.92, 0.83);
const vec3 sunSetLitCol = vec3(1.0, 0.85, 0.3);
const vec3 torchLitCol = vec3(1.0, 0.65, 0.3);
const vec3 moonLitCol = vec3(0.56, 0.60, 0.98);
const vec3 shadowCol = vec3(1.05, 1.08, 1.18);
const vec3 waterCol = vec3(0.0, 0.15, 0.3);






// Don't delete this.
#endif // !CONSTANTS_INCLUDED