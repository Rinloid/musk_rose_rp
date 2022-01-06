// __multiversion__

#include "vertexVersionCentroidUV.h"
#include "uniformWorldConstants.h"

varying POS3 worldPos;

attribute POS4 POSITION;

void main() {
worldPos = POSITION.xyz;
worldPos.y -= 0.128;
worldPos.yz *= -1.0;
    gl_Position = WORLDVIEWPROJ * POSITION;
}