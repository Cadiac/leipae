#version 330 core

in vec4 gl_FragCoord;
out vec4 FragColor;

uniform vec2 iResolution;
uniform float iTime;

const int MAX_MARCHING_STEPS = 255;
const float MIN_DIST = 0.0;
const float MAX_DIST = 100.0;
const float FOV = 45.0;
const float EPSILON = 0.0001;

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
    return p.y - y + sin(p.x / 4) + sin(p.z / 4);
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

float sdLeipae(vec3 p) {
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
                                 vec2(1.0, 2.0)) + (0.03 * noise(p.xz * 10));

        dist = opDifference(dist, wedge);
    }

    return dist;
}

float sdScene(vec3 p) {
    // float sphereDist = sdSphere(p / 1.2, 1.0) * 1.2;
    // vec3 cubePoint =
    //     (rotateY(sin(iTime)) * rotateX(cos(iTime)) * rotateZ(sin(iTime)) *
    //      vec4(p.x, p.y + sin(iTime), p.z, 1.0))
    //         .xyz;

    // float cubeDist = sdBoxFrame(cubePoint, vec3(1.0), 0.25);
    // vec3 cubePoint = (tRotateY(sin(0.5)) * tRotateX(cos(0.5)) *
    //                   tRotateZ(sin(0.5)) * vec4(p, 1.0))
    //                      .xyz;
    // float cubeDist = sdBoxFrame(opTwist(p, sin(iTime) * 3), vec3(1.0), 0.25);
    // float cubeDist = sdBoxFrame(p, vec3(1.0), 0.1);
    float leipaeDist = sdLeipae(p);

    return opUnion(sdPlane(p, -3.0), leipaeDist);
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

float shortestDistanceToSurface(vec3 camera, vec3 marchingDirection,
                                float start, float end) {
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

float shadows(vec3 sunDir, vec3 p) {
    // We don't really know where sun is, but lets say its 100 units away in sunDir.
    // March p towards the sun, and see if we get far enough
    float sunDist = MAX_DIST;

    float depth = 0.1;
    for (int i = 0; i < 32; i++) {
        float dist = sdScene(p + depth * sunDir);
        if (dist < EPSILON) {
            return 0.0;
        }
        depth += dist;
        if (depth >= sunDist) {
            return 1.0;
        }
    }
    return 1.0;
}

vec3 illumination(vec3 sun, vec3 p, vec3 camera) {
    vec3 n = estimateNormal(p);

    float dotSN = dot(n, sun);
    if (dotSN < 0) {
        return vec3(0.0);
    }

    vec3 sunColor = vec3(0.87, 0.65, 0.59);
    return sunColor * dotSN * shadows(sun, p);
}

void main() {
    vec3 viewDir = rayDirection(FOV, iResolution, gl_FragCoord.xy);
    vec3 camera = vec3(30 * cos(iTime / 10), 15.0, 30 * sin(iTime / 10));
    vec3 target = vec3(0);

    // vec3 camera = vec3(0.0, 10 + 10 * cos(iTime / 10), iTime);
    // vec3 target = vec3(
    //     camera.x + 20 * cos(iTime / 10),
    //     camera.y + 0.0,
    //     camera.z + 20 * sin(iTime / 10)
    // );

    mat4 viewToWorld = lookAt(camera, target, vec3(0.0, 1.0, 0.0));

    vec3 worldDir = (viewToWorld * vec4(viewDir, 0.0)).xyz;

    float dist =
        shortestDistanceToSurface(camera, worldDir, MIN_DIST, MAX_DIST);

    if (dist > MAX_DIST - EPSILON) {
        FragColor = vec4(0.0, 0.0, 0.0, 0.0);
        return;
    }

    // The closest point on the surface to the eyepoint along the view ray
    vec3 p = camera + dist * worldDir;
    
    // vec3 n = estimateNormal(p);
    // vec3 K_a = n;
    // vec3 K_d = smoothstep(0.6, 0.7, n.y) * vec3(1.0, 1.0, 1.0);
    // vec3 K_s = smoothstep(0.6, 0.7, n.y) * vec3(1.0, 1.0, 1.0);
    // vec3 K_d = K_a;
    // vec3 K_s = vec3(1.0);
    // float shininess = 100.0;
    // vec3 color = phongIllumination(K_a, K_d, K_s, shininess, p, camera);

    vec3 sun = normalize(vec3(2.0, 4.0, 3.0));
    vec3 color = illumination(sun, p, camera);

    FragColor = vec4(color, 1.0);
}