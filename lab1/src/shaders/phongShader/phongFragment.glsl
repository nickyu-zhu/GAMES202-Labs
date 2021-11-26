#ifdef GL_ES
precision mediump float;
#endif

// Phong related variables
uniform sampler2D uSampler;
uniform vec3 uKd;
uniform vec3 uKs;
uniform vec3 uLightPos;
uniform vec3 uCameraPos;
uniform vec3 uLightIntensity;
uniform vec3 uLightIntensity_2;

varying highp vec2 vTextureCoord;
varying highp vec3 vFragPos;
varying highp vec3 vNormal;

// Shadow map related variables
#define NUM_SAMPLES 20
#define BLOCKER_SEARCH_NUM_SAMPLES NUM_SAMPLES
#define PCF_NUM_SAMPLES NUM_SAMPLES
#define NUM_RINGS 10

#define BLOCKER_SAMPLE_RANGE 0.001
#define FILTER_SIZE 0.005
#define EPS 1e-3
#define PI 3.141592653589793
#define PI2 6.283185307179586

uniform sampler2D uShadowMap;
uniform sampler2D uShadowMap_2;

varying vec4 vPositionFromLight;
varying vec4 vPositionFromLight_2;

highp float rand_1to1(highp float x ) { 
  // -1 -1
  return fract(sin(x)*10000.0);
}

highp float rand_2to1(vec2 uv ) { 
  // 0 - 1
	const highp float a = 12.9898, b = 78.233, c = 43758.5453;
	highp float dt = dot( uv.xy, vec2( a,b ) ), sn = mod( dt, PI );
	return fract(sin(sn) * c);
}


float CalShadowBias(vec3 normal, vec3 lightDir)
{
  return max(0.01 * (1.0 - max(dot(normal,lightDir),0.0)),0.03);
}


float unpack(vec4 rgbaDepth) {
    const vec4 bitShift = vec4(1.0, 1.0/256.0, 1.0/(256.0*256.0), 1.0/(256.0*256.0*256.0));
    return dot(rgbaDepth, bitShift);
}

vec2 poissonDisk[NUM_SAMPLES];

void poissonDiskSamples( const in vec2 randomSeed ) {

  float ANGLE_STEP = PI2 * float( NUM_RINGS ) / float( NUM_SAMPLES );
  float INV_NUM_SAMPLES = 1.0 / float( NUM_SAMPLES );

  float angle = rand_2to1( randomSeed ) * PI2;
  float radius = INV_NUM_SAMPLES;
  float radiusStep = radius;

  for( int i = 0; i < NUM_SAMPLES; i ++ ) {
    poissonDisk[i] = vec2( cos( angle ), sin( angle ) ) * pow( radius, 0.75 );
    radius += radiusStep;
    angle += ANGLE_STEP;
  }
}

void uniformDiskSamples( const in vec2 randomSeed ) {

  float randNum = rand_2to1(randomSeed);
  float sampleX = rand_1to1( randNum ) ;
  float sampleY = rand_1to1( sampleX ) ;

  float angle = sampleX * PI2;
  float radius = sqrt(sampleY);

  for( int i = 0; i < NUM_SAMPLES; i ++ ) {
    poissonDisk[i] = vec2( radius * cos(angle) , radius * sin(angle)  );

    sampleX = rand_1to1( sampleY ) ;
    sampleY = rand_1to1( sampleX ) ;

    angle = sampleX * PI2;
    radius = sqrt(sampleY);
  }
}

float findBlocker( sampler2D shadowMap,  vec2 uv, float zReceiver )
{
  
  float blocker_Sum = 0.0;
  float bias = CalShadowBias(vNormal,normalize(uLightPos));
  float blocker_Count = 0.0;
  

  for(int i = 0; i < BLOCKER_SEARCH_NUM_SAMPLES; i++)
  {
    float ShadowDepth_blocker = unpack(texture2D(shadowMap, uv + BLOCKER_SAMPLE_RANGE * poissonDisk[i]));
    if(ShadowDepth_blocker < zReceiver - bias)
    {
      blocker_Sum += ShadowDepth_blocker;
      blocker_Count += 1.0;
    }
  }

  if(blocker_Count == 0.0)
     return 0.0;
  else  
     return blocker_Sum / blocker_Count;
     
   
}




float PCF(sampler2D shadowMap, vec4 coords) {
  
  
  float bias = CalShadowBias(vNormal,normalize(uLightPos));
  
  float block_Count = 0.0;
  vec3 position = coords.xyz;
  position = position * 0.5 + 0.5;
  float shadowDepth;
  poissonDiskSamples(position.xy);

  
  for(int i = 0; i < NUM_SAMPLES; i++)
  {
    shadowDepth = unpack(texture2D(shadowMap,position.xy + poissonDisk[i] * FILTER_SIZE));
    if(shadowDepth < position.z - bias)
       block_Count += 1.0;
  }
  float shadow = 1.0;
  float shadow_test = block_Count/20.0;
  shadow = shadow - shadow_test;
  return shadow;
  
  
}

float PCSS(sampler2D shadowMap, vec4 coords){

  // STEP 1: avgblocker depth
  vec3 position = coords.xyz;
  position = position * 0.5 + 0.5;
  poissonDiskSamples(position.xy);
  float avgblocker = findBlocker(shadowMap,position.xy,position.z);
  // STEP 2: penumbra size
  if(avgblocker != 0.0)
   {
    float ratio = (position.z - avgblocker) / avgblocker ;
     float light_size = 0.5;
     float w_penum = light_size * ratio;
  // STEP 3: filtering
     float bias_pcss = CalShadowBias(vNormal,normalize(uLightPos));
     float pcssSampRange = 0.05 * w_penum + 0.025;
     if(avgblocker < 0.08)
        pcssSampRange = 0.03;
     float block_Count = 0.0;
     float shadowDepth_pcss;
     poissonDiskSamples(position.xy);

  
     for(int i = 0; i < PCF_NUM_SAMPLES; i++)
      {
            shadowDepth_pcss = unpack(texture2D(shadowMap,position.xy + poissonDisk[i] * pcssSampRange));
            if(shadowDepth_pcss < position.z - bias_pcss)
            block_Count += 1.0;
      }
      float shadow_pcss = 1.0;
      float shadow_test_pcss = block_Count/20.0;
      shadow_pcss = shadow_pcss - shadow_test_pcss;
      return shadow_pcss;
   }
  else 
      return 1.0;

}


float useShadowMap(sampler2D shadowMap, vec4 shadowCoord){

  float bias = CalShadowBias(vNormal,normalize(uLightPos));
  vec3 projCoord = shadowCoord.xyz;
  projCoord = projCoord * 0.5 + 0.5;
  float test_depth = unpack(texture2D(shadowMap,projCoord.xy));
  if(test_depth < (projCoord.z - bias))
    return 0.0;
  else
    return 1.0;
}

vec3 blinnPhong() {
  vec3 color = texture2D(uSampler, vTextureCoord).rgb;
  color = pow(color, vec3(2.2));

  vec3 ambient = 0.05 * color;

  vec3 lightDir = normalize(uLightPos);
  vec3 normal = normalize(vNormal);
  float diff = max(dot(lightDir, normal), 0.0);
  vec3 light_atten_coff =
      uLightIntensity / pow(length(uLightPos - vFragPos), 2.0);
  vec3 diffuse = diff * light_atten_coff * color;

  vec3 viewDir = normalize(uCameraPos - vFragPos);
  vec3 halfDir = normalize((lightDir + viewDir));
  float spec = pow(max(dot(halfDir, normal), 0.0), 32.0);
  vec3 specular = uKs * light_atten_coff * spec;

  vec3 radiance = (ambient + diffuse + specular);
  vec3 phongColor = pow(radiance, vec3(1.0 / 2.2));
  return phongColor;
}

void main(void) {

  float visibility_1,visibility_2;
  //visibility = useShadowMap(uShadowMap, vPositionFromLight);
  //visibility = PCF(uShadowMap,vPositionFromLight);
  visibility_1 = PCSS(uShadowMap, vPositionFromLight);
  visibility_2 = PCSS(uShadowMap_2,vPositionFromLight_2);
  vec3 phongColor = blinnPhong();

  gl_FragColor = vec4(phongColor * visibility_1 + phongColor * visibility_2, 1.0);
  //gl_FragColor = vec4(phongColor, 1.0);
}