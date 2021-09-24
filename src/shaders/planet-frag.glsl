#version 300 es

// This is a fragment shader. If you've opened this file first, please
// open and read lambert.vert.glsl before reading on.
// Unlike the vertex shader, the fragment shader actually does compute
// the shading of geometry. For every pixel in your program's output
// screen, the fragment shader is run for every bit of geometry that
// particular pixel overlaps. By implicitly interpolating the position
// data passed into the fragment shader by the vertex shader, the fragment shader
// can compute what color to apply to its pixel based on things like vertex
// position, light position, and vertex color.
precision highp float;

uniform highp int u_Time;
uniform vec4 u_Color; // The color with which to render this instance of geometry.

// These are the interpolated values out of the rasterizer, so you can't know
// their specific values without knowing the vertices that contributed to them
in vec4 fs_Pos;
in vec4 fs_Nor;
in vec4 fs_LightVec;
in vec4 fs_Col;
in float noise;
in float terrain_Type;

out vec4 out_Col; // This is the final output color that you will see on your
                  // screen for the pixel that is currently being processed.

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

float worley(vec3 p) {
  vec3 pInt = floor(p);
  vec3 pFract = fract(p);
  float minDist = 1.0;
  for (int x = -1; x <= 1; x++) {
    for (int y = -1; y <= 1; y++) {
      for (int z = -1; z <= 1; z++) {
        vec3 neighbor = vec3(float(x), float(y), float(z));
        vec3 voronoi = random3(pInt + neighbor);
        //voronoi = 0.5 + 0.5 * sin(0.1 * float(u_Time) + 13.2831 * voronoi);
        vec3 diff = neighbor + voronoi - pFract;
        float dist = length(diff);
        minDist = min(minDist, dist);
      }
    }
  }
  return 1.0 - minDist;
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
  float v1 = random1(vec3(intX, intY, intZ));
  float v2 = random1(vec3(intX + 1., intY, intZ));
  float v3 = random1(vec3(intX, intY + 1., intZ));
  float v4 = random1(vec3(intX + 1., intY + 1., intZ));

  float v5 = random1(vec3(intX, intY, intZ + 1.));
  float v6 = random1(vec3(intX + 1., intY, intZ + 1.));
  float v7 = random1(vec3(intX, intY + 1., intZ + 1.));
  float v8 = random1(vec3(intX + 1., intY + 1., intZ + 1.));

  float i1 = smootherStep(v1, v2, fractX);
  float i2 = smootherStep(v3, v4, fractX);
  float result1 = smootherStep(i1, i2, fractY);
  float i3 = smootherStep(v5, v6, fractX);
  float i4 = smootherStep(v7, v8, fractX);
  float result2 = smootherStep(i3, i4, fractY);
  return smootherStep(result1, result2, fractZ);
}

float fbm(float x, float y, float z, float octaves) {
  float total = 0.;
  float persistence = 0.5f;
  for(float i = 1.; i <= octaves; i++) {
    float freq = pow(2., i);
    float amp = pow(persistence, i);
    total += interpNoise3D(x * freq, y * freq, z * freq) * amp;
  }
  return total;
}

void main()
{
    // Material base color (before shading)
    vec4 diffuseColor = u_Color;

    // Calculate the diffuse term for Lambert shading
    float diffuseTerm = dot(normalize(fs_Nor), normalize(fs_LightVec));
    // Avoid negative lighting values
    diffuseTerm = clamp(diffuseTerm, 0.f, 1.f);

    float ambientTerm = 0.3;

    float lightIntensity = diffuseTerm + ambientTerm;   //Add a small float value to the color multiplier
                                                        //to simulate ambient lighting. This ensures that faces that are not
                                                        //lit by our point light are not completely black.
    vec3 color;
    // Compute final shaded color
    if (terrain_Type < 0.5) { // ocean color
        float f = fbm(fs_Pos.x, fs_Pos.y, fs_Pos.z, 6.);
        vec4 pos = fs_Pos;
        pos = fs_Pos + f; 
        f = fbm(pos.x + .008*float(u_Time), pos.y, pos.z, 6.);
        vec3 a = vec3(0.040, 0.50, 0.60);
        vec3 b = vec3(0.00 ,0.4, 0.3);
        vec3 c = vec3(0.00 , .8, .8);
        vec3 d = vec3(0.050 ,0.1, 0.08);
        color = a + b * cos(6.28 * (f * c + d));
    } else if (terrain_Type < 1.5) {  // mountains
        float f = fbm(fs_Pos.x * 2., fs_Pos.y * 2., fs_Pos.z * 2., 16.);
        vec3 a = vec3(0.68, .66, .6);
        vec3 b = vec3(0.250);
        vec3 c = vec3(1.000);
        vec3 d = vec3(0);
        color = a + b * cos(6.28 * (worley(vec3(f)) * c + d));  
    } else  { // terrace tops
        float f = fbm(fs_Pos.x*1.5, fs_Pos.y*1.5, fs_Pos.z*1.5, 16.);
        vec3 a = vec3(0.350, 0.658, 0.000);
        vec3 b = vec3(.25);
        vec3 c = vec3(.9);
        vec3 d = vec3(0);
        color = a + b * cos(6.28 * (f * c + d));
    } 
    // else {  // terrace sides 
    //     float f = fbm(fs_Pos.x*1.5, fs_Pos.y*1.5, fs_Pos.z*1.5, 16.);
    //     vec3 a = vec3(0.38, .36, .3);
    //     vec3 b = vec3(0.150);
    //     vec3 c = vec3(1.000);
    //     vec3 d = vec3(0);
    //     color = a + b * cos(6.28 * (f * c + d));
    // }
    out_Col = vec4(color * lightIntensity, 1.); 

    vec3 height = vec3(noise);
    height = (height + vec3(1.)) / 2.;
    // out_Col = vec4(height, diffuseColor.a);
    //out_Col = vec4(abs(fs_Nor.rgb), 1);
    // out_Col = vec4(diffuseColor.rgb * lightIntensity, diffuseColor.a);

    // out_Col = vec4((fs_Nor.xyz + vec3(1.)) * 0.5, 1.);
}
