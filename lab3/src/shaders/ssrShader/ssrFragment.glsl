#ifdef GL_ES
precision highp float;
#endif

uniform vec3 uLightDir;
uniform vec3 uCameraPos;
uniform vec3 uLightRadiance;
uniform sampler2D uGDiffuse;
uniform sampler2D uGDepth;
uniform sampler2D uGNormalWorld;
uniform sampler2D uGShadow;
uniform sampler2D uGPosWorld;

varying mat4 vWorldToScreen;
varying highp vec4 vPosWorld;

#define M_PI 3.1415926535897932384626433832795
#define TWO_PI 6.283185307
#define INV_PI 0.31830988618
#define INV_TWO_PI 0.15915494309
#define EPSLON 0.001

#define SSR_STEPSIZE_NUM 600

float Rand1(inout float p) {
  p = fract(p * .1031);
  p *= p + 33.33;
  p *= p + p;
  return fract(p);
}

vec2 Rand2(inout float p) {
  return vec2(Rand1(p), Rand1(p));
}

float InitRand(vec2 uv) {
	vec3 p3  = fract(vec3(uv.xyx) * .1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

vec3 SampleHemisphereUniform(inout float s, out float pdf) {
  vec2 uv = Rand2(s);
  float z = uv.x;
  float phi = uv.y * TWO_PI;
  float sinTheta = sqrt(1.0 - z*z);
  vec3 dir = vec3(sinTheta * cos(phi), sinTheta * sin(phi), z);
  pdf = INV_TWO_PI;
  return dir;
}

vec3 SampleHemisphereCos(inout float s, out float pdf) {
  vec2 uv = Rand2(s);
  float z = sqrt(1.0 - uv.x);
  float phi = uv.y * TWO_PI;
  float sinTheta = sqrt(uv.x);
  vec3 dir = vec3(sinTheta * cos(phi), sinTheta * sin(phi), z);
  pdf = z * INV_PI;
  return dir;
}

void LocalBasis(vec3 n, out vec3 b1, out vec3 b2) {
  float sign_ = sign(n.z);
  if (n.z == 0.0) {
    sign_ = 1.0;
  }
  float a = -1.0 / (sign_ + n.z);
  float b = n.x * n.y * a;
  b1 = vec3(1.0 + sign_ * n.x * n.x * a, sign_ * b, -sign_ * n.x);
  b2 = vec3(b, sign_ + n.y * n.y * a, -n.y);
}

vec4 Project(vec4 a) {
  return a / a.w;
}

float GetDepth(vec3 posWorld) {
  float depth = (vWorldToScreen * vec4(posWorld, 1.0)).w;
  return depth;
}

/*
 * Transform point from world space to screen space([0, 1] x [0, 1])
 *
 */
vec2 GetScreenCoordinate(vec3 posWorld) {
  vec2 uv = Project(vWorldToScreen * vec4(posWorld, 1.0)).xy * 0.5 + 0.5;
  return uv;
}

float GetGBufferDepth(vec2 uv) {
  float depth = texture2D(uGDepth, uv).x;
  if (depth < 1e-2) {
    depth = 1000.0;
  }
  return depth;
}

vec3 GetGBufferNormalWorld(vec2 uv) {
  vec3 normal = texture2D(uGNormalWorld, uv).xyz;
  return normal;
}

vec3 GetGBufferPosWorld(vec2 uv) {
  vec3 posWorld = texture2D(uGPosWorld, uv).xyz;
  return posWorld;
}

float GetGBufferuShadow(vec2 uv) {
  float visibility = texture2D(uGShadow, uv).x;
  return visibility;
}

vec3 GetGBufferDiffuse(vec2 uv) {
  vec3 diffuse = texture2D(uGDiffuse, uv).xyz;
  diffuse = pow(diffuse, vec3(2.2));
  return diffuse;
}

/*
 * Evaluate diffuse bsdf value.
 *
 * wi, wo are all in world space.
 * uv is in screen space, [0, 1] x [0, 1].
 *
 */
vec3 EvalDiffuse(vec3 wi, vec3 wo, vec2 uv) {
  vec3 L = vec3(0.0);
  vec3 n = GetGBufferNormalWorld(uv);
  float wi_dot_n = dot(normalize(n),normalize(wi));
  
  float wo_dot_n = dot(normalize(n),normalize(wo));
  
  L = GetGBufferDiffuse(uv) * INV_PI * max(0.0, wi_dot_n);
  
  return L;
}

/*
 * Evaluate directional light with shadow map
 * uv is in screen space, [0, 1] x [0, 1].
 *
 */
vec3 EvalDirectionalLight(vec2 uv) {
  vec3 Le = vec3(0.0);
  float visibilty = GetGBufferuShadow(uv); 
  Le = uLightRadiance * visibilty;
  return Le;
}

bool RayMarch(vec3 ori, vec3 dir, out vec3 hitPos) {
  
  vec2 ori_screenspace = GetScreenCoordinate(ori);
  vec2 dir_screenspace = GetScreenCoordinate(dir);
  vec3 step_pos;
  vec2 step_pos_screenspace;

  
  float stepSize = 2.0 / float(SSR_STEPSIZE_NUM) / length(dir_screenspace);
  for(int i = 400; i <= SSR_STEPSIZE_NUM; i++){
  
    step_pos = ori + dir * stepSize * float(i);
    step_pos_screenspace = GetScreenCoordinate(step_pos);
    if(GetGBufferDepth(step_pos_screenspace) < GetDepth(step_pos)){
         
         hitPos = step_pos;
         return true;
    }
   
  }

  //hitPos = vec3(0.0);
  return false;
}

#define SAMPLE_NUM 10

void main() {
  float s = InitRand(gl_FragCoord.xy);

  //indirectional light
  vec3 L_indirect = vec3(0.0);
  vec3 hitPos;
  vec3 vPosWorld_xyz = vPosWorld.xyz;
  vec3 normal = GetGBufferNormalWorld(GetScreenCoordinate(vPosWorld_xyz));
  float pdf;
  vec3 sample_direction = vec3(0.0);
  
  for(int i = 0; i < SAMPLE_NUM; i++){
    
    s = Rand1(s);
    pdf = Rand1(s);
    sample_direction = SampleHemisphereUniform(s, pdf);
    vec3 b1;
    vec3 b2;
  
    LocalBasis(normal,b1,b2);
    
    sample_direction = mat3(b1, b2, normal) * sample_direction;
    sample_direction = normalize(sample_direction);

    if(RayMarch(vPosWorld_xyz, sample_direction, hitPos)){
      L_indirect += EvalDiffuse( normalize(hitPos - vPosWorld_xyz), normalize(uCameraPos - vPosWorld_xyz) , 
                                GetScreenCoordinate(vPosWorld_xyz)) * EvalDiffuse(normalize(uLightDir) , normalize(vPosWorld_xyz - hitPos), 
                                GetScreenCoordinate(hitPos)) * EvalDirectionalLight(GetScreenCoordinate(hitPos)) / pdf;  
        
    }


  }
  L_indirect /= float(SAMPLE_NUM); 

  

  //directional light
  vec3 L = vec3(0.0);
  vec3 bsdf = EvalDiffuse(normalize(uLightDir), normalize(uCameraPos - vPosWorld_xyz), GetScreenCoordinate(vPosWorld_xyz));
  //vec3 bsdf = GetGBufferDiffuse(GetScreenCoordinate(vPosWorld_xyz));
  vec3 Le_directional = EvalDirectionalLight(GetScreenCoordinate(vPosWorld_xyz));

  L = bsdf * Le_directional;
  L = L + L_indirect;
  vec3 color = pow(clamp(L, vec3(0.0), vec3(1.0)), vec3(1.0 / 2.2));
  gl_FragColor = vec4(vec3(color.rgb), 1.0);
}
