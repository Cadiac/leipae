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

float sdSphere(vec3 p, float s) {
    return length(p) - s;
}

float sdScene(vec3 p) {
    return sdSphere(p, 1.0);
}

vec3 estimateNormal(vec3 p) {
    return normalize(vec3(sdScene(vec3(p.x + EPSILON, p.y, p.z)) -
                              sdScene(vec3(p.x - EPSILON, p.y, p.z)),
                          sdScene(vec3(p.x, p.y + EPSILON, p.z)) -
                              sdScene(vec3(p.x, p.y - EPSILON, p.z)),
                          sdScene(vec3(p.x, p.y, p.z + EPSILON)) -
                              sdScene(vec3(p.x, p.y, p.z - EPSILON))));
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

    // TODO: Why are these skipped?
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
    vec3 dir = rayDirection(FOV, iResolution, gl_FragCoord.xy);
    vec3 camera = vec3(0.0, 0.0, 10.0);
    float dist = shortestDistanceToSurface(camera, dir, MIN_DIST, MAX_DIST);

    if (dist > MAX_DIST - EPSILON) {
        FragColor = vec4(0.0, 0.0, 0.0, 0.0);
        return;
    }

    // The closest point on the surface to the eyepoint along the view ray
    vec3 p = camera + dist * dir;

    vec3 K_a = vec3(0.2, 0.2, 0.2);
    vec3 K_d = vec3(1.0, 1.0, 1.0);
    vec3 K_s = vec3(1.0, 1.0, 1.0);
    float shininess = 10.0;

    vec3 color = phongIllumination(K_a, K_d, K_s, shininess, p, camera);

    FragColor = vec4(color, 1.0);
}