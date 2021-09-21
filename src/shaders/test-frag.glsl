#version 300 es

precision highp float;

uniform vec4 u_Color;
uniform highp int u_Time;

in vec4 fs_Pos;
in vec4 fs_Nor;
in vec4 fs_LightVec;
in vec4 fs_Col;

out vec4 out_Col;

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
  vec3 gradient = random3(corner);
  vec3 dist = p - corner;
  float dotProd = dot(dist, gradient);
  return dotProd * falloff.x * falloff.y * falloff.z;
}

float perlin(vec3 p) {
  p = p * 2.5;
  float surfletSum = 0.f;
  for (int dx = 0; dx <= 1; dx++) {
    for (int dy = 0; dy <= 1; dy++) {
      for (int dz = 0; dz <= 1; dz++) {
        surfletSum += surflet(p, vec3(floor(p.x), floor(p.y), floor(p.z)) + vec3(dx, dy, dz));
      }
    }
  }
  return surfletSum;
}

float worley(vec3 p) {
  p *= 1.;
  vec3 pInt = floor(p);
  vec3 pFract = fract(p);
  float minDist = 1.0;
  float secondDist = 1.0;
  for (int x = -1; x <= 1; x++) {
    for (int y = -1; y <= 1; y++) {
      for (int z = -1; z <= 1; z++) {
        vec3 neighbor = vec3(float(x), float(y), float(z));
        vec3 voronoi = random3(pInt + neighbor);
        //voronoi = 0.5 + 0.5 * sin(0.1 * float(u_Time) + 13.2831 * voronoi);
        vec3 diff = neighbor + voronoi - pFract;
        float dist = length(diff);
        if (dist < minDist) {
          secondDist = minDist;
          minDist = dist;
        } else if (dist < secondDist) {
            secondDist = dist;
        } 
        //minDist = min(minDist, dist);
      }
    }
  }
  return 1.0 - minDist;
  //return -1. * minDist + 1. * secondDist;
}

float random1( vec3 p ) {
  return fract(sin((dot(p, vec3(127.1,
  311.7,
  191.999)))) *
  28.5453);
}

float mySmootherStep(float a, float b, float t) {
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
  float v1 = random1(vec3(intX, intY, intZ));
  float v2 = random1(vec3(intX + 1., intY, intZ));
  float v3 = random1(vec3(intX, intY + 1., intZ));
  float v4 = random1(vec3(intX + 1., intY + 1., intZ));

  float v5 = random1(vec3(intX, intY, intZ + 1.));
  float v6 = random1(vec3(intX + 1., intY, intZ + 1.));
  float v7 = random1(vec3(intX, intY + 1., intZ + 1.));
  float v8 = random1(vec3(intX + 1., intY + 1., intZ + 1.));

  float i1 = mySmootherStep(v1, v2, fractX);
  float i2 = mySmootherStep(v3, v4, fractX);
  float result1 = mySmootherStep(i1, i2, fractY);
  float i3 = mySmootherStep(v5, v6, fractX);
  float i4 = mySmootherStep(v7, v8, fractX);
  float result2 = mySmootherStep(i3, i4, fractY);
  return mySmootherStep(result1, result2, fractZ);
}

float fbm(float x, float y, float z) {
  float total = 0.;
  float persistence = 0.5f;
  float octaves = 4.;
  for(float i = 1.; i <= octaves; i++) {
    float freq = pow(2.f, i);
    float amp = pow(persistence, i);
    total += interpNoise3D(x * freq, y * freq, z * freq) * amp;
  }
  return total;
}

void main()
{
  vec4 diffuseColor = u_Color;

  // Calculate the diffuse term for Lambert shading
  float diffuseTerm = dot(normalize(fs_Nor), normalize(fs_LightVec));
  // Avoid negative lighting values
  diffuseTerm = clamp(diffuseTerm, 0.f, 1.f);
  
  float ambientTerm = 0.4;

  float lightIntensity = diffuseTerm + ambientTerm;   //Add a small float value to the color multiplier
                                                      //to simulate ambient lighting. This ensures that faces that are not
                                                      //lit by our point light are not completely black.
  float perlinNoise = perlin(vec3(fs_Pos));
  vec3 a = vec3(u_Color);
	vec3 b = vec3(0.688, 0.558, 0.500);
	vec3 c = vec3(255.0 / 255.0, 244.0 / 255.0, 224.0 / 255.0);
	vec3 d = vec3(0.588, -0.342, 0.048);
  vec3 perlinColor = a + b * cos(6.28 * worley(vec3(fs_Pos)) * perlinNoise * 4. * c + d);

  // Compute final shaded color
  float f = fbm(fs_Pos.x, fs_Pos.y, fs_Pos.z);
  vec4 pos = fs_Pos;
  pos = fs_Pos + f;  // THIS IS COOL!!!!!!!!!!!!
  out_Col = vec4(vec3(fbm(pos.x, pos.y, pos.z)), diffuseColor.a); // swirly fbm
  out_Col = vec4(vec3(worley(vec3(f))), diffuseColor.a); //
  //out_Col = vec4(vec3(perlin(vec3(pos))) * lightIntensity, diffuseColor.a);
}
