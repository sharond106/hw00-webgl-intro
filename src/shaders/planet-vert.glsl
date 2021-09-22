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

in vec4 vs_Pos;             // The array of vertex positions passed to the shader

in vec4 vs_Nor;             // The array of vertex normals passed to the shader

in vec4 vs_Col;             // The array of vertex colors passed to the shader.

out vec4 fs_Pos;
out vec4 fs_Nor;            // The array of normals that has been transformed by u_ModelInvTr. This is implicitly passed to the fragment shader.
out vec4 fs_LightVec;       // The direction in which our virtual light lies, relative to each vertex. This is implicitly passed to the fragment shader.
out vec4 fs_Col;            // The color of each vertex. This is implicitly passed to the fragment shader.

const vec4 lightPos = vec4(4, 7, 7, 1); //The position of our virtual light, which is used to compute the shading of
                                        //the geometry in the fragment shader.

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
  p = p * 4.5;
  float surfletSum = 0.f;
  for (int dx = 0; dx <= 1; dx++) {
    for (int dy = 0; dy <= 1; dy++) {
      for (int dz = 0; dz <= 1; dz++) {
        surfletSum += surflet(p, vec3(floor(p.x), floor(p.y), floor(p.z)) + vec3(dx, dy, dz));
      }
    }
  }
  return surfletSum / 4.;
}

float perlinTerrace(vec4 p) {
  float noise = perlin(vec3(p)) + .5 * perlin(2.f * vec3(p)) + 0.25 * perlin(4.f * vec3(p));
  float rounded = (round(noise * 30.f) / 30.f);
  float terrace = (noise + sin(190.*noise + 4.)*.008);
  //terrace = rounded;
  //terrace *= random1(vec3(terrace));
  //noise = mix(noise, terrace, random1(vec3(terrace)));
  return terrace;
}

float perlinMountains(vec4 p) {
  float noise = perlin(vec3(p)) * 4. + .5 * perlin(2.f * vec3(p)) * 4. + 0.25 * perlin(4.f * vec3(p)) * 4.;
  //noise = noise / (1.f + .5 + .25); // this and next line for valleys
  //noise = pow(noise, .2);
  return noise;
}

vec4 perlinNormal(vec4 p) {
  float xNeg = perlinTerrace((p + vec4(-.00001, 0, 0, 0)));
  float xPos = perlinTerrace((p + vec4(.00001, 0, 0, 0)));
  float xDiff = xPos - xNeg;
  float yNeg = perlinTerrace((p + vec4(0, -.00001, 0, 0)));
  float yPos = perlinTerrace((p + vec4(0, .00001, 0, 0)));
  float yDiff = yPos - yNeg;
  float zNeg = perlinTerrace((p + vec4(0, 0, -.00001, 0)));
  float zPos = perlinTerrace((p + vec4(0, 0, .00001, 0)));
  float zDiff = zPos - zNeg;
  return vec4(vec3(xDiff, yDiff, zDiff), 0);
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
  p *= 1.5;
  vec3 pInt = floor(p);
  vec3 pFract = fract(p);
  float minDist = 1.0;
  float secondDist = 1.0;
  for (int x = -1; x <= 1; x++) {
    for (int y = -1; y <= 1; y++) {
      for (int z = -1; z <= 1; z++) {
        // if (random1(vec3(x, y, z)) < .6) {
        //   continue;
        // }
        vec3 neighbor = vec3(float(x), float(y), float(z));
        vec3 voronoi = random3(pInt + neighbor);
        //voronoi = 0.5 + 0.5 * sin(0.01 * float(u_Time) + 13.2831 * voronoi);
        vec3 diff = neighbor + voronoi - pFract;
        float dist = length(diff);
        if (dist < minDist) {
          secondDist = minDist;
          minDist = dist;
        } else if (dist < secondDist) {
            secondDist = dist;
        }
      }
    }
  }
  //return 1.0 - minDist;
  return (-1. * minDist + 1. * secondDist);
}

float worley2(vec3 p) {
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
      }
    }
  }
  return 1.0 - minDist;
}

vec4 worleyAdded(vec4 pos) {
  vec3 offset = vec3((worley(vec3(pos * 6.)))) / .5; // Can divide by different factors or not at all for plateus!!!!!!!!!!!!!!
  offset.x = clamp(offset.x, .1, .15); 
  offset.y = clamp(offset.y, .1, .15);
  offset.z = clamp(offset.z, .1, .15);

  // if (offset.x > 0. && offset.y > 0. && offset.z > 0.) {
  //   offset = vec3(mix(vec3(fbm2(pos)), offset, .85));
  // }
  offset/=5.;
  return vec4(offset, 0.);
}

vec4 worleyNormal(vec4 p) {
  float xNeg = worleyAdded((p + vec4(-.00001, 0, 0, 0))).x;
  float xPos = worleyAdded((p + vec4(.00001, 0, 0, 0))).x;
  float xDiff = (xPos - xNeg);
  
  float yNeg = worleyAdded((p + vec4(0, -.00001, 0, 0))).y;
  float yPos = worleyAdded((p + vec4(0, .00001, 0, 0))).y;
  float yDiff = (yPos - yNeg);

  float zNeg = worleyAdded((p + vec4(0, 0, -.00001, 0))).z;
  float zPos = worleyAdded((p + vec4(0, 0, .00001, 0))).z;
  float zDiff = (zPos - zNeg);
  
  return (vec4(vec3(xDiff, yDiff, zDiff), 0));
}

void main()
{
    fs_Col = vs_Col;                        
    mat3 invTranspose = mat3(u_ModelInvTr);
    fs_Nor = vec4(invTranspose * vec3(vs_Nor), 0);  
    
    float terrainMap = worley2(vec3(fbm(vs_Pos, 1., 1.2))) * 2. - .5;
    vec4 noisePos = vs_Pos;
    if (terrainMap < .02 || terrainMap > .97) {
      // interpolate between 1 and 4
      // terraces
      noisePos = vs_Pos + vs_Nor * perlinTerrace(vs_Pos); 
    } else if (terrainMap < .27) {
      // terrain 1
      // terraces
      noisePos = vs_Pos + vs_Nor * perlinTerrace(vs_Pos); 
    } else if (terrainMap < .32) {
      // interpolate between 1 and 2
      // big mountains2
      noisePos = vs_Pos + vs_Nor * fbm(vs_Pos, 6., 2.) / 5.; 
    } else if (terrainMap < .52) {
      // terrain 2
      // big mountains2
      noisePos = vs_Pos + vs_Nor * fbm(vs_Pos, 6., 2.) / 5.; 
    } else if (terrainMap < .55) {
      // interpolate between 2 and 3
      // big mountains
      noisePos = vs_Pos + vs_Nor * (perlinMountains(vs_Pos * 2.) + fbm(vs_Pos * 2., 6., 2.)) / 3.; 
    } else if (terrainMap < .7) {
      // terrain 3
      // big mountains
      noisePos = vs_Pos + vs_Nor * (perlinMountains(vs_Pos * 2.) + fbm(vs_Pos * 2., 6., 2.)) / 3.; 
    } else if (terrainMap < .75) {
      // interpolate between 3 and 4
      // cracked floor
      vec4 worl = worleyAdded(vs_Pos);  
      noisePos = vs_Pos + vs_Nor * worl;
    } else {
      // terain 4
      // cracked floor
      vec4 worl = worleyAdded(vs_Pos);  
      noisePos = vs_Pos + vs_Nor * worl;
    }
    // // cracked floor
    // vec4 worl = worleyAdded(vs_Pos);  
    // vec4 worleyNoise = vs_Pos + vs_Nor * worl;

    // // terraces
    // vec4 perlinTerrace = vs_Pos + vs_Nor * perlinTerrace(vs_Pos);   
    
    // // big mountains
    // vec4 perlinMountains = vs_Pos + vs_Nor * (perlinMountains(vs_Pos * 2.) + fbm(vs_Pos * 2., 6.)) / 2.; 
    // // big mountains2
    // vec4 fbmNoise = vs_Pos + vs_Nor * fbm(vs_Pos, 6.);  
  
    // // hills
    // vec4 hills = vs_Pos + vs_Nor * mix(fbm2(vs_Pos), worley(vec3(worley(vec3(vs_Pos)))) / 4., .9);

    vec4 modelposition = u_Model * noisePos; 
    //vec4 modelposition = u_Model * perlinTerrace; 
    //vec4 modelposition = u_Model * perlinMountains;   
    //vec4 modelposition = u_Model * (fbmNoise); 
    fs_Pos = modelposition;

    //fs_Nor = normalize(worleyNormal(vs_Pos));
    //fs_Nor = normalize(perlinNormal(vs_Pos));
    //fs_Nor = normalize(fbmNormal(vs_Pos, 6.));
    //fs_Nor = vec4(invTranspose * vec3(fs_Nor), 0); 
    vec3 normal = normalize(normalize(vec3(vs_Nor)));
    vec3 tangent = normalize(cross(vec3(0.0, 1.0, 0.0), normal));
    vec3 bitangent = normalize(cross(normal, tangent));

    float xNeg = worleyAdded((vs_Pos + vec4(tangent, 0) * vec4(-.00001, 0, 0, 0))).x;
    float xPos = worleyAdded((vs_Pos + vec4(tangent, 0) * vec4(.00001, 0, 0, 0))).x;
    float xDiff = (xPos - xNeg);
    
    float yNeg = worleyAdded((vs_Pos + vec4(bitangent, 0) * vec4(0, -.00001, 0, 0))).y;
    float yPos = worleyAdded((vs_Pos + vec4(bitangent, 0) * vec4(0, .00001, 0, 0))).y;
    float yDiff = (yPos - yNeg);

    float zNeg = worleyAdded((vs_Pos + vs_Nor * vec4(0, 0, -.00001, 0))).z;
    float zPos = worleyAdded((vs_Pos + vs_Nor * vec4(0, 0, .00001, 0))).z;
    float zDiff = (zPos - zNeg);
    
    //fs_Nor = (vec4(vec3(xDiff, yDiff, zDiff), 0));

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
