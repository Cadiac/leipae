#version 330 core

in vec4 gl_FragCoord;
out vec4 FragColor;

uniform vec2 iResolution;
uniform float iTime;

const int MAX_MARCHING_STEPS = 255;
const float MIN_DIST = 0.0;
const float MAX_DIST = 250.0;
const float FOV = 45.0;
const float EPSILON = 0.00001;
const float PI = 3.14159265;

const vec3 SUN_COLOR = vec3(0.87, 0.65, 0.59);
const vec3 SKY_COLOR = vec3(0.30, 0.45, 0.68);

float dot2(in vec2 v) {
    return dot(v, v);
}

float dot2(in vec3 v) {
    return dot(v, v);
}

float ndot(in vec2 a, in vec2 b) {
    return a.x * b.x - a.y * b.y;
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

// http://en.wikipedia.org/wiki/Rotation_matrix#Basic_rotations
mat4 tRotateX(float theta) {
    float s = sin(theta);
    float c = cos(theta);

    return mat4(vec4(1, 0, 0, 0), vec4(0, c, -s, 0), vec4(0, s, c, 0),
                vec4(0, 0, 0, 1));
}

mat4 tRotateY(float theta) {
    float s = sin(theta);
    float c = cos(theta);

    return mat4(vec4(c, 0, s, 0), vec4(0, 1, 0, 0), vec4(-s, 0, c, 0),
                vec4(0, 0, 0, 1));
}

mat4 tRotateZ(float theta) {
    float s = sin(theta);
    float c = cos(theta);

    return mat4(vec4(c, -s, 0, 0), vec4(s, c, 0, 0), vec4(0, 0, 1, 0),
                vec4(0, 0, 0, 1));
}

float opIntersect(float distA, float distB) {
    return max(distA, distB);
}

float opUnion(float distA, float distB) {
    return min(distA, distB);
}

float opDifference(float distA, float distB) {
    return max(distA, -distB);
}

vec3 opTwist(vec3 p, float k) {
    float c = cos(k * p.y);
    float s = sin(k * p.y);
    mat2 m = mat2(c, -s, s, c);
    return vec3(m * p.xz, p.y);
}

vec3 opBend(vec3 p, float k) {
    float c = cos(k * p.x);
    float s = sin(k * p.x);
    mat2 m = mat2(c, -s, s, c);
    return vec3(m * p.xy, p.z);
}

vec3 opRep(vec3 p, float c) {
    return mod(p + 0.5 * c, c) - 0.5 * c;
}

vec3 opRepLim(vec3 p, float c, vec3 l) {
    return p - c * clamp(round(p / c), -l, l);
}

/**
 * Derived from: https://iquilezles.org/articles/distfunctions/
 * SDF primitive distance functions
 */

float sdRoundBox(vec3 p, vec3 b, float r) {
    vec3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0) - r;
}

float sdBox(vec3 p, vec3 b) {
    vec3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

float sdBoxFrame(vec3 p, vec3 b, float e) {
    p = abs(p) - b;
    vec3 q = abs(p + e) - e;
    return min(min(length(max(vec3(p.x, q.y, q.z), 0.0)) +
                       min(max(p.x, max(q.y, q.z)), 0.0),
                   length(max(vec3(q.x, p.y, q.z), 0.0)) +
                       min(max(q.x, max(p.y, q.z)), 0.0)),
               length(max(vec3(q.x, q.y, p.z), 0.0)) +
                   min(max(q.x, max(q.y, p.z)), 0.0));
}

float sdTorus(vec3 p, vec2 t) {
    vec2 q = vec2(length(p.xz) - t.x, p.y);
    return length(q) - t.y;
}

float sdSphere(vec3 p, float s) {
    return length(p) - s;
}

float sdPlane(vec3 p, float y) {
    return p.y - y;
}

float sdEllipsoid(vec3 p, vec3 r) {
    float k0 = length(p / r);
    float k1 = length(p / (r * r));
    return k0 * (k0 - 1.0) / k1;
}

float sdCapsule(vec3 p, vec3 a, vec3 b, float r) {
    vec3 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h) - r;
}

float sdTriPrism(vec3 p, vec2 h) {
    vec3 q = abs(p);
    return max(q.z - h.y, max(q.x * 0.866025 + p.y * 0.5, -p.y) - h.x * 0.5);
}

/**
 * Derived from: https://iquilezles.org/articles/morenoise/
 * Vector hash function, unsafe for security use
 */
float hash(vec2 x) {
    vec2 integer = floor(x);
    vec2 fractional = fract(x);

    vec2 u =
        3 * fractional * fractional - 2 * fractional * fractional * fractional;

    vec2 ua = 50.0 * fract(x / PI);
    return 2.0 * fract(ua.x * ua.y * (ua.x + ua.y)) - 1.0;
}

/**
 * Derived from: https://iquilezles.org/articles/morenoise/
 * Value noise generator
 */
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

/**
 * Derived from: https://iquilezles.org/articles/fbm/
 * Fractional Brownian Motion from noise
 */
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

float sdLeipae(in vec3 p) {
    float ellipsoidDist = sdEllipsoid(opBend(p, -0.03), vec3(5.0, 1.0, 1.5)) -
                          0.25 + (0.05 * noise(p.xz * 5)) +
                          (0.01 * noise(p.xz * 30));

    float dist = ellipsoidDist;
    for (int i = -3; i <= 3; i++) {
        float offsetY = 1.9;
        if (i == -2 || i == 2) {
            offsetY = 1.7;
        } else if (i == -3 || i == 3) {
            offsetY = 1.4;
        }

        float wedge = sdTriPrism((tRotateZ(1.0) * tRotateY(0.3) *
                                  vec4(p.x + i * 1.1, p.y - offsetY, p.z, 1.0))
                                     .xyz,
                                 vec2(1.0, 2.0)) +
                      (0.03 * noise(p.xz * 10));

        dist = opDifference(dist, wedge);
    }

    return dist;
}

float sdTerrain(in vec3 p) {
    return p.y - fbm(p.xz + vec2(-1.0, 2.0), 1.5, 8) + 4;
}

float sdScene(in vec3 p) {
    float terrain = sdTerrain(p);
    float water = sdPlane(p, -3.9);
    float leipae = sdLeipae(vec3(p.x, p.y + 2.0, p.z));

    return opUnion(opUnion(terrain, leipae), water);
}

vec3 estimateNormal(vec3 p) {
    float dx = sdScene(vec3(p.x + EPSILON, p.y, p.z)) -
               sdScene(vec3(p.x - EPSILON, p.y, p.z));
    float dy = sdScene(vec3(p.x, p.y + EPSILON, p.z)) -
               sdScene(vec3(p.x, p.y - EPSILON, p.z));
    float dz = sdScene(vec3(p.x, p.y, p.z + EPSILON)) -
               sdScene(vec3(p.x, p.y, p.z - EPSILON));
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

/**
 * Derived from: https://www.shadertoy.com/view/lt33z7
 * Lighting contribution of a single point light source via Phong illumination.
 *
 * The vec3 returned is the RGB color of the light's contribution.
 *
 * k_a: Ambient color
 * k_d: Diffuse color
 * k_s: Specular color
 * alpha: Shininess coefficient
 * p: position of point being lit
 * eye: the position of the camera
 * lightPos: the position of the light
 * i_s: specular color/intensity of the light
 * i_d: diffuse color/intensity of the light
 *
 * See https://en.wikipedia.org/wiki/Phong_reflection_model#Description
 */
vec3 phongContribForLight(vec3 k_d, vec3 k_s, float alpha, vec3 p, vec3 camera,
                          vec3 lightPos, vec3 i) {
    // ^N, which is the normal at this point on the surface
    vec3 N = estimateNormal(p);

    // ^L_m, which is the direction vector from the point on the surface toward
    // each light source
    vec3 L = normalize(lightPos - p);

    // ^V, which is the direction pointing towards the viewer (such as a virtual
    // camera).
    vec3 V = normalize(camera - p);

    // ^R_m, which is the direction that a perfectly reflected ray of light
    // would take from this point on the surface
    vec3 R = normalize(reflect(-L, N));
    // vec3 R = 2 * dot(L, N) * N - L;

    // float dotLN = dot(L, N);
    float dotLN = clamp(dot(L, N), 0.0, 1.0);
    float dotRV = dot(R, V);

    // Why are these skipped?
    // > "Although the above formulation is the common way of presenting
    // the Phong reflection model, each term should only be included if the
    // term's dot product is positive."
    // > "Additionally, the specular term should only be included
    // if the dot product of the diffuse term is positive."

    if (dotLN < 0.0) {
        // Light not visible from this point on the surface
        return vec3(0.0, 0.0, 0.0);
    }

    if (dotRV < 0.0) {
        // Light reflection in opposite direction as viewer, apply only diffuse
        // component
        return i * (k_d * dotLN);
    }
    return k_d * dotLN * i + k_s * pow(dotRV, alpha) * i;
}

/**
 * Derived from: https://www.shadertoy.com/view/lt33z7
 * Lighting via Phong illumination.
 *
 * The vec3 returned is the RGB color of that point after lighting is applied.
 * k_a: Ambient color
 * k_d: Diffuse color
 * k_s: Specular color
 * alpha: Shininess coefficient
 * p: position of point being lit
 * eye: the position of the camera
 *
 * See https://en.wikipedia.org/wiki/Phong_reflection_model#Description
 */
vec3 phongIllumination(vec3 k_a, vec3 k_d, vec3 k_s, float alpha, vec3 p,
                       vec3 camera) {
    const vec3 ambientLight = 0.3 * vec3(1.0, 1.0, 1.0);
    vec3 color = ambientLight * k_a;

    vec3 light1Pos = vec3(camera.x + 4.0 * sin(iTime), camera.y + 2.0,
                          camera.z + 4.0 * cos(iTime));
    vec3 light1Intensity = vec3(0.4, 0.4, 0.4);

    color += phongContribForLight(k_d, k_s, alpha, p, camera, light1Pos,
                                  light1Intensity);

    vec3 light2Pos = vec3(camera.x + 2.0 * sin(0.37 * iTime),
                          camera.y + 2.0 * cos(0.37 * iTime), camera.z + 2.0);
    vec3 light2Intensity = vec3(0.4, 0.4, 0.4);

    color += phongContribForLight(k_d, k_s, alpha, p, camera, light2Pos,
                                  light2Intensity);
    return color;
}

vec3 rayDirection(float fov, vec2 dimensions, vec2 fragCoord) {
    vec2 xy = fragCoord - dimensions / 2.0;
    float z = dimensions.y / tan(radians(fov) / 2.0);
    return normalize(vec3(xy, -z));
}

float rayMarch(vec3 camera, vec3 marchingDirection, float start, float end) {
    float depth = start;
    for (int i = 0; i < MAX_MARCHING_STEPS; i++) {
        float dist = sdScene(camera + depth * marchingDirection);
        if (dist < i * 0.001) {
            return depth;
        }
        depth += dist;
        if (depth >= end) {
            return -1.0;
        }
    }
    return -1.0;
}

float shadows(in vec3 sunDir, in vec3 p) {
    // We don't really know where sun is, but lets say its MAX_DIST units away
    // in sunDir. March p towards the sun, and see if we get far enough
    for (float depth = 1.0; depth < MAX_DIST;) {
        float dist = sdScene(p + depth * sunDir);
        if (dist < EPSILON) {
            return 0.0;
        }
        depth += dist;
    }
    return 1.0;
}

/**
 * Derived from: https://iquilezles.org/articles/rmshadows/
 * Soft shadows, k controls softness
 */
float softShadows(in vec3 sunDir, in vec3 p, float k) {
    float opacity = 1.0;
    for (float depth = 1.0; depth < MAX_DIST;) {
        float dist = sdScene(p + depth * sunDir);
        if (dist < EPSILON) {
            return 0.0;
        }
        opacity = min(opacity, k * dist / depth);
        depth += dist;
    }
    return opacity;
}

vec3 lightning(in vec3 sun, in vec3 p, in vec3 camera) {
    vec3 n = estimateNormal(p);

    float dotNS = dot(n, sun);
    vec3 sunLight = vec3(0.0);
    if (dotNS > 0) {
        sunLight = clamp(SUN_COLOR * dotNS * softShadows(sun, p, 4.0), 0.0, 1.0);
    }

    vec3 skyLight = clamp(SUN_COLOR * (0.5 + 0.5 * n.y) * (0.1 * SKY_COLOR), 0.0, 1.0);

    float dotNB = dot(n, -sun);
    vec3 bounceLight = vec3(0.0);
    if (dotNB > 0) {
        bounceLight = clamp(SUN_COLOR * dotNB * (0.4 * SUN_COLOR), 0.0, 1.0);
    }

    return sunLight + skyLight + bounceLight;
}

vec3 fog(in vec3 color, float dist) {
    vec3 e = exp2(-dist * 0.010 * vec3(1.0, 2.0, 4.0));
    return color * e + (1.0 - e) * vec3(1.0);
}

vec3 sky(in vec3 camera, in vec3 dir) {
    // Deeper blue when looking up
    vec3 color = SKY_COLOR - 0.4 * dir.y;

    // Draw clouds on a plane at 2500 height
    // "dir" is the normalized vector towards the plane with length of 1.
    // To get the point on the plane figure out how many steps of "dir"s are
    // needed for the y axel delta, and then multiply the whole dir by that.
    float dist = (2500 - camera.y) / dir.y;
    if (dist > 0.0 && dist < 100000) {
        vec3 p = (camera + dist * dir);
        float clouds = smoothstep(-0.3, 0.7, fbm(0.0005 * p.xz, 1.1, 9));
        color = mix(color, vec3(1.0), 0.2 * clouds);
    }

    // Fade to white fog further away
    vec3 e = exp2(-abs(dist) * 0.00001 * vec3(1.0, 2.0, 4.0));
    color = color * e + (1.0 - e) * vec3(1.0);

    return color;
}

void main() {
    vec3 viewDir = rayDirection(FOV, iResolution, gl_FragCoord.xy);
    // vec3 camera = vec3(20 * cos(iTime / 10), 4, 20 * sin(iTime / 10));
    vec3 camera =
        vec3(10.0 * cos(iTime / 10.0), -3.4, 10.0 * sin(iTime / 10.0));
    vec3 target = vec3(2.0, -3.8 + 5.0 * sin(iTime / 10.0), 5.0);

    // vec3 camera = vec3(0.0, 10 + 10 * cos(iTime / 10), iTime);
    // vec3 target = vec3(
    //     camera.x + 20 * cos(iTime / 10),
    //     camera.y + 0.0,
    //     camera.z + 20 * sin(iTime / 10)
    // );

    mat4 viewToWorld = lookAt(camera, target, vec3(0.0, 1.0, 0.0));

    vec3 worldDir = (viewToWorld * vec4(viewDir, 0.0)).xyz;

    float dist = rayMarch(camera, worldDir, MIN_DIST, MAX_DIST);
    if (dist < 0.0) {
        FragColor = vec4(sky(camera, worldDir), 1.0);
        return;
    }

    // The closest point on the surface to the eyepoint along the view ray
    vec3 p = camera + dist * worldDir;

    // vec3 n = estimateNormal(p);
    // vec3 K_a = n;
    // vec3 K_d = smoothstep(0.6, 0.7, n.y) * vec3(1.0, 1.0, 1.0);
    // vec3 K_s = smoothstep(0.6, 0.7, n.y) * vec3(1.0, 1.0, 1.0);
    // vec3 K_a = vec3(0.4, 0.3, 0.2);
    // vec3 K_d = K_a;
    // vec3 K_s = vec3(1.0);
    // float shininess = 100.0;
    // vec3 color = phongIllumination(K_a, K_d, K_s, shininess, p, camera);

    vec3 sun = normalize(vec3(4.0, 2.5, 5.0));
    vec3 color = lightning(sun, p, camera);
    color = fog(color, dist);

    color = pow(color, vec3(1.0, 0.92, 1.0));
    color *= vec3(1.02, 0.99, 0.9);
    color.z = color.z + 0.1;

    color = smoothstep(0.0, 1.0, color);

    FragColor = vec4(color, 1.0);
}