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
uniform float u_PlanetAndMoon;

in vec4 vs_Pos;             // The array of vertex positions passed to the shader

in vec4 vs_Nor;             // The array of vertex normals passed to the shader

in vec4 vs_Col;             // The array of vertex colors passed to the shader.

out vec4 fs_Nor;            // The array of normals that has been transformed by u_ModelInvTr. This is implicitly passed to the fragment shader.
out vec4 fs_LightVec;       // The direction in which our virtual light lies, relative to each vertex. This is implicitly passed to the fragment shader.
out vec4 fs_Col;            // The color of each vertex. This is implicitly passed to the fragment shader.
out vec4 fs_Pos;


vec3 random3(vec3 p) {
 return fract(sin(vec3(dot(p,vec3(127.1, 311.7, 191.999)),
                        dot(p,vec3(269.5, 183.3, 765.54)),
                        dot(p, vec3(420.69, 631.2,109.21))))
                *43758.5453);
}

float worley(vec3 p) {
  p *= 20.;
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
        minDist = min(minDist, dist*minDist);
      }
    }
  }
  return minDist;
}


vec3 cartesian(float r, float theta, float phi) {
  return vec3(r * sin(phi) * cos(theta), 
              r * sin(phi) * sin(theta),
              r * cos(phi));
}

// output is vec3(radius, theta, phi)
vec3 polar(vec4 p) {
  float r = sqrt(p.x * p.x + p.y * p.y + p.z * p.z);
  float theta = atan(p.y / p.x);
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
} 

vec4 worleyNormal(vec4 p) {
  vec3 polars = polar(p);
  float offset = .01;
  vec3 xNeg = cartesian(polars.x, polars.y - offset, polars.z);
  vec3 xPos = cartesian(polars.x, polars.y + offset, polars.z);
  vec3 yNeg = cartesian(polars.x, polars.y, polars.z - offset);
  vec3 yPos = cartesian(polars.x, polars.y, polars.z + offset);
  float xNegNoise = step(.12, worley(xNeg)) * .02;
  float xPosNoise = step(.12, worley(xPos)) * .02;
  float yNegNoise = step(.12, worley(yNeg)) * .02;
  float yPosNoise = step(.12, worley(yPos)) * .02;

  float xDiff = (xPosNoise - xNegNoise) * 10.;
  float yDiff = (yPosNoise - yNegNoise) * 10.;
  p.z = sqrt(1. - xDiff * xDiff - yDiff * yDiff);
  return vec4(vec3(xDiff, yDiff, p.z), 0);
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
    fs_Col = vs_Col;                         // Pass the vertex colors to the fragment shader for interpolation

    mat3 invTranspose = mat3(u_ModelInvTr);

    vec4 pos;
    vec4 lightPos;
    if (u_PlanetAndMoon > 0.) {
      float angle = .01 * float(u_Time);
      vec4 col0 = vec4(cos(angle), 0, -1.*sin(angle), 0);
      vec4 col1 = vec4(0, 1, 0, 0);
      vec4 col2 = vec4(sin(angle), 0, cos(angle), 0);
      vec4 col3 = vec4(0, 0, 0, 1);
      mat4 rotate = mat4(col0, col1, col2, col3);
      pos = rotate * (vs_Pos + vec4(2., 0., 0., 0.));
      lightPos = rotate * vec4(10, 0, 0, 1);
    } else {
      pos = vs_Pos;
      lightPos = mix(vec4(10., 4., 10., 1.), vec4(-10., 4., 10., 1.), GetGain((sin(float(u_Time)*.01) + 1.)/2., .75));
    }
    
    vec4 modelposition = u_Model * pos;   
    fs_Pos = vs_Pos;
    fs_Nor = transformToWorld(normalize(worleyNormal(vs_Pos)));
 
    fs_LightVec = lightPos - modelposition;  // Compute the direction in which the light source lies

    gl_Position = u_ViewProj * modelposition;// gl_Position is a built-in variable of OpenGL which is
                                             // used to render the final positions of the geometry's vertices
}
