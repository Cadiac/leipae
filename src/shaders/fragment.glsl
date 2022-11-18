#version 330 core

in vec4 gl_FragCoord;
out vec4 FragColor;

const int LEIPAE_COUNT = 20;
const float TOTAL_DURATION = 100.0;

uniform float iTime;
uniform vec2 iResolution;
uniform vec3 iCamera;
uniform vec3 iTarget;
uniform vec4 iLeipae[LEIPAE_COUNT];

float PROGRESS = (TOTAL_DURATION - iTime) / TOTAL_DURATION;

const int MAX_MARCHING_STEPS = 400;
const float MIN_DIST = 0.0;
const float MAX_DIST = 100.0;
const float FOV = 60.0;
const float EPSILON = 0.00001;
const float PI = 3.14159265;
const float WATER_LEVEL = 0.3;

const vec3 SUN_COLOR = vec3(0.8, 1.0, 1.0);
const vec3 SKY_COLOR = vec3(0.06, 0.03, 0.69);
const vec3 FOG_COLOR = vec3(0.94, 0.12, 0.58);
const vec3 COLOR_SHIFT = vec3(2.5, 1.5, 1.0);

// Translations
// http://en.wikipedia.org/wiki/Rotation_matrix#Basic_rotations
mat3 tRotateX(float theta) {
    float s = sin(theta);
    float c = cos(theta);

    return mat3(vec3(1, 0, 0), vec3(0, c, -s), vec3(0, s, c));
}

mat3 tRotateY(float theta) {
    float s = sin(theta);
    float c = cos(theta);

    return mat3(vec3(c, 0, s), vec3(0, 1, 0), vec3(-s, 0, c));
}

mat3 tRotateZ(float theta) {
    float s = sin(theta);
    float c = cos(theta);

    return mat3(vec3(c, -s, 0), vec3(s, c, 0), vec3(0, 0, 1));
}


/**
 * The following functions are derived from:
 * - https://iquilezles.org/articles/distfunctions/ - sdBox, sdSphere, sdEllipsoid, sdTriPrism, sdArc, opUnion, opBend
 * - https://iquilezles.org/articles/morenoise/ - hash, valuenoise, fbm
 * - https://iquilezles.org/articles/fbm/ - fbm
 * - https://iquilezles.org/articles/rmshadows/ - softShadows
 *
 * The MIT License
 * Copyright © 2019 Inigo Quilez
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions: The above copyright
 * notice and this permission notice shall be included in all copies or
 * substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS",
 * WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED
 * TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
 * FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 * TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR
 * THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

// SDF primitive distance functions
float sdBox(vec3 p, vec3 b) {
    vec3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

float sdSphere(vec3 p, float s) {
    return length(p) - s;
}

float sdEllipsoid(vec3 p, vec3 r) {
    float k0 = length(p / r);
    float k1 = length(p / (r * r));
    return k0 * (k0 - 1.0) / k1;
}

float sdTriPrism(vec3 p, vec2 h) {
    vec3 q = abs(p);
    return max(q.z - h.y, max(q.x * 0.866025 + p.y * 0.5, -p.y) - h.x * 0.5);
}

float sdArc(in vec2 p, in float sc, in float ra, float rb) {
    // sc is the sin/cos of the arc's aperture
    p.x = abs(p.x);
    float s = sin(sc);
    float c = cos(sc);
    return ((c * p.x > s * p.y) ? length(p - vec2(s, c) * ra)
                                : abs(length(p) - ra)) -
           rb;
}

// Noise generation
float hash(vec2 x) {
    vec2 integer = floor(x);
    vec2 fractional = fract(x);

    vec2 u =
        3 * fractional * fractional - 2 * fractional * fractional * fractional;

    vec2 ua = 50.0 * fract(x / PI);
    return 2.0 * fract(ua.x * ua.y * (ua.x + ua.y)) - 1.0;
}

float valuenoise(in vec2 x) {
    vec2 integer = floor(x);
    vec2 fractional = fract(x);

    vec2 u = fractional * fractional * (3.0 - 2.0 * fractional);

    float a = hash(integer + vec2(0, 0));
    float b = hash(integer + vec2(1, 0));
    float c = hash(integer + vec2(0, 1));
    float d = hash(integer + vec2(1, 1));

    float k0 = a;
    float k1 = b - a;
    float k2 = c - a;
    float k4 = a - b - c + d;

    return 0.0 + 1.0 * (k0 + k1 * u.x + k2 * u.y + k4 * u.x * u.y);
}

float fbm(in vec2 x, in float H, int octaves) {
    float G = exp2(-H);
    float f = 1.0;
    float a = 0.5;
    float t = 0.0;
    for (int i = 0; i < octaves; i++) {
        t += a * valuenoise(f * x);
        f *= 1.9;
        a *= G;
    }
    return t;
}

// https://stackoverflow.com/a/4275343
float rand(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

// https://gist.github.com/patriciogonzalezvivo/670c22f3966e662d2f83
float noise(vec2 p) {
    vec2 ip = floor(p);
    vec2 u = fract(p);
    u = u * u * (3.0 - 2.0 * u);

    float res = mix(
        mix(rand(ip), rand(ip + vec2(1.0, 0.0)), u.x),
        mix(rand(ip + vec2(0.0, 1.0)), rand(ip + vec2(1.0, 1.0)), u.x), u.y);
    return res * res;
}

// Union of SDF distances, modified to carry material color in "xyz" properties
vec4 opUnion(vec4 distA, vec4 distB) {
    if (distA.a < distB.a) {
        return distA;
    }

    return distB;
}

vec3 opBend(vec3 p, float k) {
    float c = cos(k * p.x);
    float s = sin(k * p.x);
    mat2 m = mat2(c, -s, s, c);
    return vec3(m * p.xy, p.z);
}

// Scene object SDF functions

// Dark water with pink and cyan texture
vec4 sdWater(vec3 p, float y) {
    vec3 material = vec3(0.0);

    vec3 fractional = fract(p);
    if (fractional.x < 0.03) {
        material = vec3(1, 0, 1);        
    } else if (fractional.z <= 0.03) {
        material = vec3(0, 1, 1);
    }

    float dist = p.y - y;
    return vec4(material, dist);
}

// Unused leipae, decided to not use this after all and just stick to the round one
vec4 sdLeipae(in vec3 p) {
    if (sdSphere(p, 10) > 0) {
        // Get a better estimate and use that
        return vec4(0.0, 0.0, 0.0, sdSphere(p, 6));
    }

    float noise5 = noise(p.xz * 5);
    float noise30 = noise(p.xz * 30);
    float noise50 = noise(p.xz * 50);

    float ellipsoidDist = sdEllipsoid(opBend(p, -0.03), vec3(5.0, 1.0, 1.5)) -
                          0.25 + (0.05 * noise5) + (0.01 * noise30) +
                          (0.005 * noise50);

    float dist = ellipsoidDist;
    for (int i = -3; i <= 3; i++) {
        float offsetY = 1.9;
        if (i == -2 || i == 2) {
            offsetY = 1.7;
        } else if (i == -3 || i == 3) {
            offsetY = 1.4;
        }

        float wedge = sdTriPrism(tRotateZ(1.0) * tRotateY(0.3) *
                                     vec3(p.x + i * 1.1, p.y - offsetY, p.z),
                                 vec2(1.0, 2.0)) +
                      (0.03 * noise(p.xz * 10));

        dist = max(dist, -wedge);
    }

    vec3 material =
        vec3(0.88, 0.52, 0.07) + (noise5 * vec3(0.5) + noise30 * vec3(0.5));
    return vec4(material, dist);
}

// The main leipae, round with wedges cut to it
vec4 sdLeipaeRound(in vec3 p) {
    if (sdSphere(p, 5) > 0) {
        // Get a better estimate and use that
        return vec4(0.0, 0.0, 0.0, sdSphere(p, 2.5));
    }

    float noise5 = noise(p.xz * 5);
    float noise30 = noise(p.xz * 30);
    float noise50 = noise(p.xz * 50);

    float ellipsoidDist = sdEllipsoid(opBend(p, -0.08), vec3(2.2, 0.8, 2.1)) -
                          0.25 + (0.05 * noise5) + (0.01 * noise30) +
                          (0.005 * noise50);

    float dist = ellipsoidDist;
    for (int i = -1; i <= 1; i++) {
        float offsetY = 1.55;

        float wedge = sdTriPrism(tRotateZ(0.9) * tRotateY(0.3) *
                                     vec3(p.x + i * 1.1, p.y - offsetY, p.z),
                                 vec2(1.0, 6.0)) +
                      (0.03 * noise(p.xz * 10));

        dist = max(dist, -wedge);
    }

    for (int i = -1; i <= 1; i++) {
        float offsetY = 1.55;

        float wedge = sdTriPrism(tRotateZ(1.1) * tRotateY(-0.8) *
                                     vec3(p.x + i * 1.1, p.y - offsetY, p.z),
                                 vec2(1.0, 6.0)) +
                      (0.03 * noise(p.xz * 10));

        dist = max(dist, -wedge);
    }

    vec3 material =
        vec3(0.88, 0.52, 0.07) + (noise5 * vec3(0.5) + noise30 * vec3(0.5));
    return vec4(material, dist);
}

// Terrain with hills
vec4 sdTerrain(in vec3 p) {
    vec3 material = vec3(0.6 * PROGRESS);
    if (p.y - WATER_LEVEL < 0) {
        return vec4(material, MAX_DIST);
    }

    return vec4(material,
                p.y - abs(fbm((p.xz + vec2(50.0, -30.0)) / 2, 1.1, 4)) * 2);
}

vec4 sdScene(in vec3 p) {
    vec4 terrain = sdTerrain(p);
    vec4 water = sdWater(p, WATER_LEVEL);

    vec4 leipae = vec4(0.0, 0.0, 0.0, MAX_DIST);

    for (int i = 0; i < LEIPAE_COUNT; i++) {
        vec4 offset = iLeipae[i];
        vec4 dist = sdLeipaeRound(tRotateZ(iTime - offset.z) * tRotateX(iTime - offset.x) * (p - offset.xyz) * offset.w) / offset.w;
        leipae = opUnion(leipae, dist);

        if (leipae.w < EPSILON) {
            break;
        }
    }

    return opUnion(opUnion(terrain, water), leipae);
}

vec3 estimateNormal(vec3 p) {
    float dx = sdScene(vec3(p.x + EPSILON, p.y, p.z)).a -
               sdScene(vec3(p.x - EPSILON, p.y, p.z)).a;
    float dy = sdScene(vec3(p.x, p.y + EPSILON, p.z)).a -
               sdScene(vec3(p.x, p.y - EPSILON, p.z)).a;
    float dz = sdScene(vec3(p.x, p.y, p.z + EPSILON)).a -
               sdScene(vec3(p.x, p.y, p.z - EPSILON)).a;
    return normalize(vec3(dx, dy, dz));
}

// Create a homogeneous transformation matrix that will cause a vector to
// point at `target`, using `up` for orientation.
mat4 lookAt(vec3 camera, vec3 target, vec3 up) {
    vec3 f = normalize(target - camera);
    vec3 s = normalize(cross(up, f));
    vec3 u = cross(f, s);

    return mat4(vec4(s, 0.0), vec4(u, 0.0), vec4(-f, 0.0),
                vec4(0.0, 0.0, 0.0, 1.0));
}

vec3 rayDirection(float fov, vec2 dimensions, vec2 fragCoord) {
    vec2 xy = fragCoord - dimensions / 2.0;
    float z = dimensions.y / tan(radians(fov) / 2.0);
    return normalize(vec3(xy, -z));
}

vec4 rayMarch(in vec3 camera, in vec3 rayDir, float start, float end) {
    // Check if we would hit the bounding plane before reaching "end"
    float stepsToBoundingPlane = (100.0 - camera.y) / rayDir.y;
    if (stepsToBoundingPlane > 0.0) {
        end = min(end, stepsToBoundingPlane);
    }

    float dist = 0.0;
    float depth = start;

    vec3 material = vec3(1.0);

    for (int i = 0; i < MAX_MARCHING_STEPS; i++) {
        vec3 pos = camera + depth * rayDir;
        vec4 res = sdScene(pos);
        float dist = res.a;

        if (abs(dist) < 0.0001) {
            material = res.xyz;
            break;
        }

        if (depth >= end) {
            break;
        }

        depth += dist * 0.8;
    }

    if (depth >= end) {
        return vec4(material, -1.0);
    }

    return vec4(material, depth);
}

// Derived from: https://iquilezles.org/articles/rmshadows/
float softShadows(in vec3 sunDir, in vec3 p, float k) {
    float opacity = 1.0;
    for (float depth = 1.0; depth < MAX_DIST;) {
        float dist = sdScene(p + depth * sunDir).a;
        if (dist < EPSILON) {
            return 0.0;
        }
        opacity = min(opacity, k * dist / depth);
        depth += dist;
    }
    return opacity;
}

vec3 lightning(in vec3 sun, in vec3 p, in vec3 camera, in vec3 material) {
    vec3 n = estimateNormal(p);

    float dotNS = dot(n, sun);
    vec3 sunLight = vec3(0.0);
    if (dotNS > 0) {
        sunLight =
            clamp(SUN_COLOR * dotNS * softShadows(sun, p, 24.0), 0.0, 1.0);
    }

    vec3 skyLight =
        clamp(SUN_COLOR * (0.5 + 0.5 * n.y) * (0.1 * SKY_COLOR), 0.0, 1.0);

    float dotNB = dot(n, -sun);
    vec3 bounceLight = vec3(0.0);
    if (dotNB > 0) {
        bounceLight = clamp(SUN_COLOR * dotNB * (0.4 * SUN_COLOR), 0.0, 1.0);
    }

    return clamp(material * (sunLight + skyLight + bounceLight), 0.0, 1.0);
}

vec3 fog(in vec3 color, float dist) {
    vec3 e = exp2(-dist * 0.010 * COLOR_SHIFT);
    return color * e + (1.0 - e) * FOG_COLOR;
}

vec3 sky(in vec3 camera, in vec3 dir, in vec3 sun) {
    // Deeper blue when looking up
    vec3 color = SKY_COLOR - 0.5 * dir.y;

    // Draw stars behind the clouds that at 5000 height at the end of the demo.
    if (iTime > 75.0) {
        float dist = 5000 / dir.y;
        if (dist > 0.0 && dist < 100000) {
            vec3 p = (camera + dist * dir);
            float stars =
                smoothstep(0.7, 1.0, fbm(vec2(-6.0 + p.x * 0.015, 2.0 + p.z * 0.003), 0.6, 4));
            color = mix(color, vec3(1.0), stars);
        }
    }

    // Draw clouds on a plane at 2500 height
    // "dir" is the normalized vector towards the plane with length of 1.
    // To get the point on the plane figure out how many steps of "dir"s are
    // needed for the y axel delta, and then multiply the whole dir by that.
    float dist = (2500 - camera.y) / dir.y;
    if (dist > 0.0 && dist < 100000) {
        vec3 p = (camera + dist * dir);
        float clouds =
            smoothstep(-0.1, 0.8, fbm(0.0002 * p.xz + vec2(-3.0, 2.0), 0.9, 8));
        color = mix(color, vec3(1.0), 0.4 * clouds);
    }

    // Fade to fog further away
    vec3 e = exp2(-abs(dist) * 0.00001 * COLOR_SHIFT);
    color = color * e + (1.0 - e) * FOG_COLOR;

    // Sun
    float dotSun = dot(sun, dir);
    if (dotSun > 0.996) {
        float h = dir.y - sun.y;
        // Stripes
        if (h > -0.02) {
            color = vec3(1, 1, 0.5);
        } else if (h < -0.025 && h > -0.03) {
            color = vec3(1, 0.75, 0.6);
        } else if (h < -0.035 && h > -0.04) {
            color = vec3(1, 0.65, 0.7);
        } else if (h < -0.045 && h > -0.05) {
            color = vec3(1, 0.5, 0.82);
        } else if (h < -0.055 && h > -0.06) {
            color = vec3(1, 0.5, 0.82);
        } else if (h < -0.065 && h > -0.07) {
            color = vec3(1, 0.5, 0.92);
        } else if (h < -0.075 && h > -0.08) {
            color = vec3(1, 0.5, 1.00);
        } else if (h < -0.085 && h > -0.09) {
            color = vec3(1, 0.5, 1.00);
        }
    }

    // Sun glare
    if (dotSun > 0.995) {
        color = mix(color, vec3(1.0, 1.0, 0.5), (dotSun - 0.995) / (1 - 0.995));
    }

    return color;
}

void main() {
    vec3 viewDir = rayDirection(FOV, iResolution, gl_FragCoord.xy);

    vec3 camera = iCamera;
    vec3 target = iTarget;

    mat4 viewToWorld = lookAt(camera, target, vec3(0.0, 1.0, 0.0));
    vec3 worldDir = (viewToWorld * vec4(viewDir, 0.0)).xyz;

    vec4 r = rayMarch(camera, worldDir, MIN_DIST, MAX_DIST);
    float dist = r.a;

    vec3 sun = normalize(vec3(-97.0 + 100.0 * cos(PROGRESS - 0.2), 100.0 * sin(PROGRESS - 0.2), -100.0));

    if (dist < 0.0) {
        FragColor = vec4(sky(camera, worldDir, sun), 1.0);
    } else {
        vec3 material = r.xyz;

        // The closest point on the surface to the eyepoint along the view ray
        vec3 p = camera + dist * worldDir;

        vec3 color = lightning(sun, p, camera, material);
        color = fog(color, dist);

        color = pow(color, vec3(1.0, 0.92, 1.0));
        color *= vec3(1.02, 0.99, 0.9);
        color.z = color.z + 0.1;

        color = smoothstep(0.0, 1.0, color);

        FragColor = vec4(color, 1.0);
    }

    if (iTime > TOTAL_DURATION) {
        // Fade to black at the end
        FragColor = mix(FragColor, vec4(0.0), (iTime - TOTAL_DURATION) / 5.0);
    } else if (iTime < 2.0) {
        // Fade in at the beginning
        FragColor = mix(FragColor, vec4(0.0), (2.0 - iTime) / 2.0);
    }
}