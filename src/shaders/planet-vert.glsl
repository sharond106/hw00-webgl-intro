#version 300 es

//This is a vertex shader. While it is called a "shader" due to outdated conventions, this file
//is used to apply matrix transformations to the arrays of vertex data passed to it.
//Since this code is run on your GPU, each vertex is transformed simultaneously.
//If it were run on your CPU, each vertex would have to be processed in a FOR loop, one at a time.
//This simultaneous transformation allows your program to run much faster, especially when rendering
//geometry with millions of vertices.

uniform mat4 u_Model;       // The matrix that defines the transformation of the
                            // object we're rendering. In this assignment,
                            // this will be the result of traversing your scene graph.

uniform mat4 u_ModelInvTr;  // The inverse transpose of the model matrix.
                            // This allows us to transform the object's normals properly
                            // if the object has been non-uniformly scaled.

uniform mat4 u_ViewProj;    // The matrix that defines the camera's transformation.
                            // We've written a static matrix for you to use for HW2,
                            // but in HW3 you'll have to generate one yourself
uniform int u_Time;
uniform vec4 u_CameraPos;
uniform float u_Sea;
uniform float u_Mountains;
uniform float u_Fragments;
uniform float u_PlanetAndMoon;

in vec4 vs_Pos;             // The array of vertex positions passed to the shader

in vec4 vs_Nor;             // The array of vertex normals passed to the shader

in vec4 vs_Col;             // The array of vertex colors passed to the shader.

out float noise;
out vec4 fs_Pos;
out vec4 fs_Nor;            // The array of normals that has been transformed by u_ModelInvTr. This is implicitly passed to the fragment shader.
out vec4 fs_LightVec;       // The direction in which our virtual light lies, relative to each vertex. This is implicitly passed to the fragment shader.
out vec4 fs_Col;            // The color of each vertex. This is implicitly passed to the fragment shader.
out float terrain_Type;
out vec4 fs_LightPos;

float random1( vec3 p ) {
  return fract(sin((dot(p, vec3(127.1,
  311.7,
  191.999)))) *
  18.5453);
}

// Returns random vec3 in range [0, 1]
vec3 random3(vec3 p) {
 return fract(sin(vec3(dot(p,vec3(127.1, 311.7, 191.999)),
                        dot(p,vec3(269.5, 183.3, 765.54)),
                        dot(p, vec3(420.69, 631.2,109.21))))
                *43758.5453);
}

// Returns a surflet 
float surflet(vec3 p, vec3 corner) {
  vec3 t = abs(p - corner);
  vec3 falloff = vec3(1.f) - 6.f * vec3(pow(t.x, 5.f),pow(t.y, 5.f), pow(t.z, 5.f)) 
                        + 15.f * vec3(pow(t.x, 4.f), pow(t.y, 4.f),pow(t.z, 4.f)) 
                        - 10.f * vec3(pow(t.x, 3.f), pow(t.y, 3.f),pow(t.z, 3.f));
  falloff = vec3(1.0) - 3.f * vec3(pow(t.x, 2.f),pow(t.y, 2.f), pow(t.z, 2.f)) 
                        + 2.f * vec3(pow(t.x, 3.f), pow(t.y, 3.f),pow(t.z, 3.f));
  falloff = vec3(1.0) - t;
  //falloff = vec3(1.f) - gain(t, .5);
  vec3 gradient = random3(corner);
  vec3 dist = p - corner;
  float dotProd = dot(dist, gradient);
  return dotProd * falloff.x * falloff.y * falloff.z;
}

float perlin(vec3 p) {
  p = p * 4.5;
  float surfletSum = 0.f;
  for (int dx = 0; dx <= 1; dx++) {
    for (int dy = 0; dy <= 1; dy++) {
      for (int dz = 0; dz <= 1; dz++) {
        surfletSum += surflet(p, vec3(floor(p.x), floor(p.y), floor(p.z)) + vec3(dx, dy, dz));
      }
    }
  }
  // float sum = surfletSum / 4.;
  // return (sum + 1. )/2.; // kinda creates cool earth like land masses
  return surfletSum / 4.;
}

float perlinTerrace(vec4 p) {
  p *= 1.5;
  float noise = perlin(vec3(p)) + .5 * perlin(2.f * vec3(p)) + 0.25 * perlin(4.f * vec3(p));
  float rounded = (round(noise * 30.f) / 30.f);
  float terrace = (noise + sin(290.*noise + 3.)*.004) *.8;
  return terrace + .005;
}

float perlinMountains(vec4 p, float factor) {
  p *= 2.;
  float noise = perlin(vec3(p)) + .5 * perlin(2.f * vec3(p)) + 0.25 * perlin(4.f * vec3(p));
  //noise = noise / (1.f + .5 + .25); // this and next line for valleys
  //noise = pow(noise, .2);
  noise *= factor;
  return noise + .02;
}

vec4 cartesian(float r, float theta, float phi) {
  return vec4(r * sin(phi) * cos(theta), 
              r * sin(phi) * sin(theta),
              r * cos(phi), 1.);
}

// output is vec3(radius, theta, phi)
vec3 polar(vec4 p) {
  float r = sqrt(p.x * p.x + p.y * p.y + p.z * p.z);
  float theta = atan(p.y / p.x);
  // float phi = atan(sqrt(p.x * p.x + p.y * p.y) / p.z);
  float phi = acos(p.z / sqrt(p.x * p.x + p.y * p.y + p.z * p.z));
  return vec3(r, theta, phi);
}

vec4 transformToWorld(vec4 nor) {
  vec3 normal = normalize(vec3(vs_Nor));
  vec3 tangent = normalize(cross(vec3(0.0, 1.0, 0.0), normal));
  vec3 bitangent = normalize(cross(normal, tangent));
  mat4 transform;
  transform[0] = vec4(tangent, 0.0);
  transform[1] = vec4(bitangent, 0.0);
  transform[2] = vec4(normal, 0.0);
  transform[3] = vec4(0.0, 0.0, 0.0, 1.0);
  return vec4(normalize(vec3(transform * nor)), 0.0); 
  // return nor;
} 

vec4 perlinTerraceNormal(vec4 p) {
  vec3 polars = polar(p);
  float offset = .0001;
  vec4 xNeg = cartesian(polars.x, polars.y - offset, polars.z);
  vec4 xPos = cartesian(polars.x, polars.y + offset, polars.z);
  vec4 yNeg = cartesian(polars.x, polars.y, polars.z - offset);
  vec4 yPos = cartesian(polars.x, polars.y, polars.z + offset);
  float xNegNoise = perlinTerrace(xNeg);
  float xPosNoise = perlinTerrace(xPos);
  float yNegNoise = perlinTerrace(yNeg);
  float yPosNoise = perlinTerrace(yPos);

  float xDiff = (xPosNoise - xNegNoise) * 1000.;
  float yDiff = (yPosNoise - yNegNoise) * 1000.;
  p.z = sqrt(1. - xDiff * xDiff - yDiff * yDiff);
  return vec4(vec3(xDiff, yDiff, p.z), 0);
  // vec3 normal = vec3(vs_Nor);
  // vec3 tangent = cross(vec3(0, 1, 0), normal);
  // vec3 bitangent = cross(normal, tangent);
  // vec3 p1 = vec3(vs_Pos) + .0001 * tangent + tangent * perlinTerrace(p + vec4(.0001*tangent, 0.));
  // vec3 p2 = vec3(vs_Pos) + .0001 * bitangent + bitangent * perlinTerrace(p + vec4(.0001*bitangent, 0.));
  // vec3 p3 = vec3(vs_Pos) + normal * perlinTerrace(p);
  // return vec4(cross(p3 - p1, p3 - p2), 0);
}

vec4 perlinMoutainNormal(vec4 p, float factor) {
  vec3 polars = polar(p);
  float offset = .01;
  vec4 xNeg = cartesian(polars.x, polars.y - offset, polars.z);
  vec4 xPos = cartesian(polars.x, polars.y + offset, polars.z);
  vec4 yNeg = cartesian(polars.x, polars.y, polars.z - offset);
  vec4 yPos = cartesian(polars.x, polars.y, polars.z + offset);
  float xNegNoise = perlinMountains(xNeg, factor);
  float xPosNoise = perlinMountains(xPos, factor);
  float yNegNoise = perlinMountains(yNeg, factor);
  float yPosNoise = perlinMountains(yPos, factor);

  float xDiff = (xPosNoise - xNegNoise) * 10.;
  float yDiff = (yPosNoise - yNegNoise) * 10.;
  p.z = sqrt(1. - xDiff * xDiff - yDiff * yDiff);
  return vec4(vec3(xDiff, yDiff, p.z), 0);
}


float fbmRandom( vec3 p ) {
  return fract(sin((dot(p, vec3(127.1,
  311.7,
  191.999)))) *
  18.5453);
}

float smootherStep(float a, float b, float t) {
    t = t*t*t*(t*(t*6.0 - 15.0) + 10.0);
    return mix(a, b, t);
}

float interpNoise3D(float x, float y, float z) {
  x *= 2.;
  y *= 2.;
  z *= 2.;
  float intX = floor(x);
  float fractX = fract(x);
  float intY = floor(y);
  float fractY = fract(y);
  float intZ = floor(z);
  float fractZ = fract(z);
  float v1 = fbmRandom(vec3(intX, intY, intZ));
  float v2 = fbmRandom(vec3(intX + 1., intY, intZ));
  float v3 = fbmRandom(vec3(intX, intY + 1., intZ));
  float v4 = fbmRandom(vec3(intX + 1., intY + 1., intZ));

  float v5 = fbmRandom(vec3(intX, intY, intZ + 1.));
  float v6 = fbmRandom(vec3(intX + 1., intY, intZ + 1.));
  float v7 = fbmRandom(vec3(intX, intY + 1., intZ + 1.));
  float v8 = fbmRandom(vec3(intX + 1., intY + 1., intZ + 1.));

  float i1 = smootherStep(v1, v2, fractX);
  float i2 = smootherStep(v3, v4, fractX);
  float result1 = smootherStep(i1, i2, fractY);
  float i3 = smootherStep(v5, v6, fractX);
  float i4 = smootherStep(v7, v8, fractX);
  float result2 = smootherStep(i3, i4, fractY);
  return smootherStep(result1, result2, fractZ);
}

float fbm(vec4 p, float oct, float freq) {
  float total = 0.;
  float persistence = 0.5f;
  float octaves = oct;
  for(float i = 1.; i <= octaves; i++) {
    float freq = pow(freq, i);
    float amp = pow(persistence, i);
    total += interpNoise3D(p.x * freq, p.y * freq, p.z * freq) * amp;
  }
  return total;
}

float fbm2(vec4 p) {
  float total = 0.;
  float persistence = 0.5f;
  float octaves = 4.;
  for(float i = 1.; i <= octaves; i++) {
    float freq = pow(2.f, i);
    float amp = pow(persistence, i);
    total += interpNoise3D(p.x * freq, p.y * freq, p.z * freq) * amp;
  }
  return total;
}

vec4 fbmNormal(vec4 p, float oct, float freq) {
  float xNeg = fbm((p + vec4(-.00001, 0, 0, 0)), oct, freq);
  float xPos = fbm((p + vec4(.00001, 0, 0, 0)), oct, freq);
  float xDiff = xPos - xNeg;
  float yNeg = fbm((p + vec4(0, -.00001, 0, 0)), oct, freq);
  float yPos = fbm((p + vec4(0, .00001, 0, 0)), oct, freq);
  float yDiff = yPos - yNeg;
  float zNeg = fbm((p + vec4(0, 0, -.00001, 0)), oct, freq);
  float zPos = fbm((p + vec4(0, 0, .00001, 0)), oct, freq);
  float zDiff = zPos - zNeg;
  return vec4(vec3(xDiff, yDiff, zDiff), 0);
}

float worley(vec3 p) {
  vec3 pInt = floor(p);
  vec3 pFract = fract(p);
  float minDist = 1.0;
  for (int x = -1; x <= 1; x++) {
    for (int y = -1; y <= 1; y++) {
      for (int z = -1; z <= 1; z++) {
        vec3 neighbor = vec3(float(x), float(y), float(z));
        vec3 voronoi = random3(pInt + neighbor);
        vec3 diff = neighbor + voronoi - pFract;
        float dist = length(diff);
        minDist = min(minDist, dist);
      }
    }
  }
  return 1.0 - minDist;
}

vec4 getTerrain() {
  // biomes = water, terraces, mountains, sand
  // toolbox = smooth step (fbm and perlin), sin wave (terraces), jitter scattering (worley), gain to animate light
  // gui = modify boundaries of terrains, modify fbm octaves or freq, 
  float terrainMap = worley(vec3(fbm(vs_Pos, 6., 1.2 + u_Fragments * .1)));
  vec4 noisePos = vs_Pos;
  if (terrainMap < .28 + (u_Sea * .06)) {
    // water (use worley to animate?) and use blinn phong?
    fs_Nor = vs_Nor;
    terrain_Type = 0.;
  } else if (terrainMap < .3) {
    fs_Nor = vs_Nor;
    terrain_Type = 3.;
  } else if (terrainMap < .94 - (u_Mountains * .05)) {
    // terraces
    noisePos = vs_Pos + vs_Nor * perlinTerrace(vs_Pos); 
    fs_Nor = transformToWorld(normalize(perlinTerraceNormal(vs_Pos)));
    terrain_Type = 2.;
  } else if (terrainMap < .98 - (u_Mountains * .05)) {
    // smaller mountains 
    noisePos = vs_Pos + vs_Nor * perlinMountains(vs_Pos, 1.); 
    fs_Nor = transformToWorld(normalize(perlinMoutainNormal(vs_Pos, .4)));
    terrain_Type = 1.;
  } else {
    // mountains
    noisePos = vs_Pos + vs_Nor * perlinMountains(vs_Pos, 1.7); 
    fs_Nor = transformToWorld(normalize(perlinMoutainNormal(vs_Pos, 1.7)));
    terrain_Type = 1.;
  }
  return noisePos;
}

float GetBias(float time, float bias)
{
  return (time / ((((1.0/bias) - 2.0)*(1.0 - time))+1.0));
}

float GetGain(float time, float gain)
{
  if(time < 0.5)
    return GetBias(time * 2.0,gain)/2.0;
  else
    return GetBias(time * 2.0 - 1.0,1.0 - gain)/2.0 + 0.5;
}

void main()
{
    fs_Col = vs_Col;                        
    mat3 invTranspose = mat3(u_ModelInvTr);
    fs_Nor = vec4(invTranspose * vec3(vs_Nor), 0);  
    
    vec4 noisePos = getTerrain();

    vec4 modelposition = u_Model * noisePos; 
    fs_Pos = modelposition;
    
    fs_Nor = vec4(invTranspose * vec3(fs_Nor), 0);  
    
    vec4 light;
    if (u_PlanetAndMoon > 0.) {
      float angle = .01 * float(u_Time);
      vec4 col0 = vec4(cos(angle), 0, -1.*sin(angle), 0);
      vec4 col1 = vec4(0, 1, 0, 0);
      vec4 col2 = vec4(sin(angle), 0, cos(angle), 0);
      vec4 col3 = vec4(0, 0, 0, 1);
      mat4 rotate = mat4(col0, col1, col2, col3);
      light = rotate * vec4(-2, 0, 0, 1);
    } else {
      light = mix(vec4(10., 4., 10., 1.), vec4(-10., 4., 10., 1.), GetGain((sin(float(u_Time)*.02) + 1.)/2., .75));
    }
    fs_LightPos = light;
    fs_LightVec = light - modelposition;  // Compute the direction in which the light source lies
    gl_Position = u_ViewProj * modelposition;// gl_Position is a built-in variable of OpenGL which is
                                             // used to render the final positions of the geometry's vertices
}
