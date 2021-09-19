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

in vec4 vs_Pos;             // The array of vertex positions passed to the shader

in vec4 vs_Nor;             // The array of vertex normals passed to the shader

in vec4 vs_Col;             // The array of vertex colors passed to the shader.

out vec4 fs_Pos;
out vec4 fs_Nor;            // The array of normals that has been transformed by u_ModelInvTr. This is implicitly passed to the fragment shader.
out vec4 fs_LightVec;       // The direction in which our virtual light lies, relative to each vertex. This is implicitly passed to the fragment shader.
out vec4 fs_Col;            // The color of each vertex. This is implicitly passed to the fragment shader.

const vec4 lightPos = vec4(5, 5, 3, 1); //The position of our virtual light, which is used to compute the shading of
                                        //the geometry in the fragment shader.

// Returns random vec3 in range [0, 1]
vec3 random3(vec3 p) {
 return fract(sin(vec3(dot(p,vec3(127.1, 311.7, 191.999)),
                        dot(p,vec3(269.5, 183.3, 765.54)),
                        dot(p, vec3(420.69, 631.2,109.21))))
                *43758.5453);
}

vec3 bias(vec3 b, float t) {
  return vec3(pow(t, log(b.x) / log(0.5)), pow(t, log(b.y) / log(0.5)), pow(t, log(b.z) / log(0.5)));
}

vec3 gain(vec3 g, float t) {
  if (t < 0.5) {
    return bias(vec3(1.0) - g, 2.0 * t) / 2.0;
  } else {
    return vec3(1.0) - bias(vec3(1.0) - g, 2.0 - 2.0 * t) / 2.0;
  }
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
  p *= 3.5;
  vec3 pInt = floor(p);
  vec3 pFract = fract(p);
  float minDist = 1.0;
  float secondDist = 1.0;
  for (int x = -1; x <= 1; x++) {
    for (int y = -1; y <= 1; y++) {
      for (int z = -1; z <= 1; z++) {
        vec3 neighbor = vec3(float(x), float(y), float(z));
        vec3 voronoi = random3(pInt + neighbor);
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
  return -1. * minDist + 1. * secondDist;
}

vec4 offsetPos(vec4 pos) {
  vec3 offset = vec3(worley(vec3(pos))) / vec3(2.0); // Can divide by different factors or not at all for plateus!!!!!!!!!!!!!!
    
  offset.x = clamp(offset.x, 0.1, .4); // Can change these values!!!!!!!!!!!!!!!!!! 
  offset.y = clamp(offset.y, 0.1, .4);
  offset.z = clamp(offset.z, 0.1, .4);
  vec4 noise = pos + vs_Nor * vec4(offset + random3(offset) / vec3(50.0), 0); 
                      // Can try subtracting offset!!!!!!!!!!!!!!!!!!!!!!!
                      // make sure the clamp min is 0 so sphere doesn't shrink
  return noise;
}

void main()
{
    fs_Col = vs_Col;                        
    mat3 invTranspose = mat3(u_ModelInvTr);
    fs_Nor = vec4(invTranspose * vec3(vs_Nor), 0);  

    vec4 noise = offsetPos(vs_Pos);
    float perlin = perlin(vec3(vs_Pos)) + .5 * perlin(2.f * vec3(vs_Pos)) + 0.25 * perlin(4.f * vec3(vs_Pos));
    
    //perlin = perlin / (1.f + .5 + .25); // this and next line for valleys
    //perlin = pow(perlin, .2);
    
    vec4 perlinNoise = vs_Pos + vs_Nor * perlin;

    vec4 modelposition = u_Model * perlinNoise;   // Temporarily store the transformed vertex positions for use below
    fs_Pos = modelposition;

    vec4 xNeg = offsetPos(vs_Pos + vec4(-.0000001, 0, 0, 0));
    vec4 xPos = offsetPos(vs_Pos + vec4(.0000001, 0, 0, 0));
    vec4 xDiff = xPos - xNeg;
    vec4 yNeg = offsetPos(vs_Pos + vec4(0, -.0000001, 0, 0));
    vec4 yPos = offsetPos(vs_Pos + vec4(0, .0000001, 0, 0));
    vec4 yDiff = yPos - yNeg;
    vec4 zNeg = offsetPos(vs_Pos + vec4(0, 0, -.0000001, 0));
    vec4 zPos = offsetPos(vs_Pos + vec4(0, 0, .0000001, 0));
    vec4 zDiff = zPos - zNeg;
    //fs_Nor = normalize(vec4(vec3(xDiff.x, yDiff.y, zDiff.z), 0));

    vec3 normal = normalize(vec3(xDiff.x, yDiff.y, zDiff.z));
    vec3 tangent = normalize(cross(vec3(0.0, 1.0, 0.0), normal));
    vec3 bitangent = normalize(cross(normal, tangent));
    mat4 transform;
    transform[0] = vec4(tangent, 0.0);
    transform[1] = vec4(bitangent, 0.0);
    transform[2] = vec4(normal, 0.0);
    transform[3] = vec4(0.0, 0.0, 0.0, 1.0);
    //fs_Nor = vec4(normalize(vec3(transform * vec4(normal, 0.0))), 0.0); 

    fs_LightVec = lightPos - modelposition;  // Compute the direction in which the light source lies

    gl_Position = u_ViewProj * modelposition;// gl_Position is a built-in variable of OpenGL which is
                                             // used to render the final positions of the geometry's vertices
}
