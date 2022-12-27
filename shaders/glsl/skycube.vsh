// __multiversion__

#include "vertexVersionCentroidUV.h"
#include "uniformWorldConstants.h"

varying POS3 relPos;

attribute POS4 POSITION;

void main() {
relPos = POSITION.xyz;
relPos.y -= 0.128;
relPos.yz *= -1.0;
    gl_Position = WORLDVIEWPROJ * POSITION;
}