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
static const float3 skyCol = float3(0.4, 0.65, 1.0);
static const float nightSkyBrightness = 0.5;
static const float daySkyBrightness = 2.0;

static const float3 cloudCol = float3(0.158, 0.15, 0.15);
static const float nightCloudBrightness = 3.0;
static const float dayCloudBrightness = 18.0;

static const float3 starCol = float3(1.0, 0.98, 0.97);
static const float3 moonCol = float3(1.0, 0.95, 0.8);

// Terrain
static const float3 skyLitCol = float3(1.0, 1.0, 1.0);
static const float3 sunLitCol = float3(1.0, 0.92, 0.83);
static const float3 sunSetLitCol = float3(1.0, 0.85, 0.3);
static const float3 torchLitCol = float3(1.0, 0.65, 0.3);
static const float3 moonLitCol = float3(0.56, 0.60, 0.98);
static const float3 shadowCol = float3(1.05, 1.08, 1.18);
static const float3 waterCol = float3(0.0, 0.15, 0.3);






// Don't delete this.
#endif // !CONSTANTS_INCLUDED