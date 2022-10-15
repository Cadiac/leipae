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

// http://en.wikipedia.org/wiki/Rotation_matrix#Basic_rotations
mat4 rotateX(float theta) {
    float s = sin(theta);
    float c = cos(theta);

    return mat4(vec4(1, 0, 0, 0), vec4(0, c, -s, 0), vec4(0, s, c, 0),
                vec4(0, 0, 0, 1));
}

mat4 rotateY(float theta) {
    float s = sin(theta);
    float c = cos(theta);

    return mat4(vec4(c, 0, s, 0), vec4(0, 1, 0, 0), vec4(-s, 0, c, 0),
                vec4(0, 0, 0, 1));
}

mat4 rotateZ(float theta) {
    float s = sin(theta);
    float c = cos(theta);

    return mat4(vec4(c, -s, 0, 0), vec4(s, c, 0, 0), vec4(0, 0, 1, 0),
                vec4(0, 0, 0, 1));
}

float sdIntersect(float distA, float distB) {
    return max(distA, distB);
}

float sdUnion(float distA, float distB) {
    return min(distA, distB);
}

float sdDifference(float distA, float distB) {
    return max(distA, -distB);
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

float sdScene(vec3 p) {
    float sphereDist = sdSphere(p / 1.2, 1.0) * 1.2;
    vec3 cubePoint =
        (rotateY(sin(iTime)) * rotateX(cos(iTime)) * rotateZ(sin(iTime)) *
         vec4(p.x, p.y + sin(iTime), p.z, 1.0))
            .xyz;

    float cubeDist = sdBoxFrame(cubePoint, vec3(1.0), 0.25);
    return sdIntersect(cubeDist, sphereDist);
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

    vec3 light1Pos = vec3(4.0 * sin(iTime), 2.0, 4.0 * cos(iTime));
    vec3 light1Intensity = vec3(0.4, 0.4, 0.4);

    color += phongContribForLight(k_d, k_s, alpha, p, camera, light1Pos,
                                  light1Intensity);

    vec3 light2Pos =
        vec3(2.0 * sin(0.37 * iTime), 2.0 * cos(0.37 * iTime), 2.0);
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

void main() {
    vec3 viewDir = rayDirection(FOV, iResolution, gl_FragCoord.xy);
    // vec3 camera = vec3(8.0 + 4 * sin(iTime), 5.0 + 4 * cos(iTime), 7.0);
    vec3 camera = vec3(8.0, 5.0, 7.0);

    mat4 viewToWorld = lookAt(camera, vec3(0.0, 0.0, 0.0), vec3(0.0, 1.0, 0.0));

    vec3 worldDir = (viewToWorld * vec4(viewDir, 0.0)).xyz;

    float dist =
        shortestDistanceToSurface(camera, worldDir, MIN_DIST, MAX_DIST);

    if (dist > MAX_DIST - EPSILON) {
        FragColor = vec4(0.0, 0.0, 0.0, 0.0);
        return;
    }

    // The closest point on the surface to the eyepoint along the view ray
    vec3 p = camera + dist * worldDir;

    vec3 K_a = vec3(estimateNormal(p) + vec3(1.0)) / 2;
    vec3 K_d = K_a;
    vec3 K_s = vec3(1.0, 1.0, 1.0);
    float shininess = 50.0;

    vec3 color = phongIllumination(K_a, K_d, K_s, shininess, p, camera);

    FragColor = vec4(color, 1.0);
}