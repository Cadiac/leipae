#version 330 core

in vec4 gl_FragCoord;
out vec4 FragColor;

uniform vec2 iResolution;

const int MAX_MARCHING_STEPS = 255;
const float MIN_DIST = 0.0;
const float MAX_DIST = 100.0;
const float FOV = 45.0;
const float EPSILON = 0.0001;

float sdSphere( vec3 p, float s ) {
    return length(p) - s;
}

float sdScene( vec3 p ) {
    return sdSphere(p, 1.0);
}

vec3 rayDirection(float fov, vec2 dimensions, vec2 fragCoord) {
    vec2 xy = fragCoord - dimensions / 2.0;
    float z = dimensions.y / tan(radians(fov) / 2.0);
    return normalize(vec3(xy, -z));
}

float shortestDistanceToSurface(vec3 camera, vec3 marchingDirection, float start, float end) {
    float depth = start;
    for (int i = 0; i < MAX_MARCHING_STEPS; i++) {
        float dist = sdScene(camera + depth * marchingDirection);
        if (dist < EPSILON) {
			return depth;
        }
        depth += dist;
        if (depth >= end) {
            return end;
        }
    }
    return end;
}

void main() {
    vec3 dir = rayDirection(FOV, iResolution, gl_FragCoord.xy);
    vec3 camera = vec3(0.0, 0.0, 10.0);
    float dist = shortestDistanceToSurface(camera, dir, MIN_DIST, MAX_DIST);

    if (dist > MAX_DIST - EPSILON) {
        FragColor = vec4(0.0, 0.0, 0.0, 0.0);
		return;
    }

    FragColor = vec4(1.0, 0.0, 0.0, 1.0);
}