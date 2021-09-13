#version 300 es

precision highp float;

uniform vec4 u_Color; 

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
  vec3 gradient = random3(corner) * 2.f - vec3(1.f);
  vec3 dist = p - corner;
  float dotProd = dot(dist, gradient);
  return dotProd * falloff.x * falloff.y * falloff.z;
}

float perlin(vec3 p) {
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

void main()
{
  vec4 diffuseColor = u_Color;

  // Calculate the diffuse term for Lambert shading
  float diffuseTerm = dot(normalize(fs_Nor), normalize(fs_LightVec));
  // Avoid negative lighting values
  diffuseTerm = clamp(diffuseTerm, 0.f, 1.f);
  
  float ambientTerm = 0.2;

  float lightIntensity = diffuseTerm + ambientTerm;   //Add a small float value to the color multiplier
                                                      //to simulate ambient lighting. This ensures that faces that are not
                                                      //lit by our point light are not completely black.
  float perlinNoise = perlin(vec3(fs_Pos.x, fs_Pos.y, fs_Pos.z));
  vec3 a = vec3(1.000, 0.500, 0.500);
	vec3 b = vec3(0.5);
	vec3 d = vec3(0.750, 1.000, 0.667);
	vec3 c = vec3(0.800, 1.000, 0.333);
  vec3 perlinColor = a + b * cos(6.28 * (perlinNoise * 2. * c * diffuseTerm + d));

  // Compute final shaded color
  // out_Col = vec4(diffuseColor.rgb * lightIntensity, diffuseColor.a);
  out_Col = vec4(perlinColor.rgb * lightIntensity, diffuseColor.a);;
}
