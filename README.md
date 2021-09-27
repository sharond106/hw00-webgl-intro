# HW 1: Noisy Planets
Sharon Dong (PennKey: sharondo)

Live demo: https://sharond106.github.io/hw00-webgl-intro/

## Techniques
- Terrain Placement
    - The base noise function that determines where the terrain and ocean lie uses worley noise warped with fbm: `color = worley(fbm(p))`
- Mountains
    - Terrain created with summed perlin noise at different frequencies: `height = perlin(p) + 0.5*perlin(2*p) + .25*perlin(4*p)`
    - Colored with a cosine color palette and worley noise warped with fbm
- Terraces 
    - Terrain created with summed perlin noise at different frequencies
    - Steps created with a modified sin function: `(perlin + A *sin(B*perlin + C))*f`
    - Colored with a cosine color palette and fbm
- Ocean
    - Colored with a cosine color palette and warped fbm: `color = fbm(p + fbm(p))`
    - Animated by displacing the input to my fbm noise with time
    - Blinn phong shading to make white parts look a little snowy
- Sand
    - Colored with a cosine color palette and fbm
    - Blinn phong shading to represent wet sand
- Sun
    - Moves from left to right and animated with a .75 gain function 
- GUI
    - Sea level slider changes the threshold of the terrain placement noise value that determines where ocean lies
    - Mountains slider works similarly
    - Fragmentation slider changes the frequency of the fbm used for terrain placement
- More about the noise functions
    - All noise functions are 3D
    - My perlin noise and fbm functions use a quintic smooth step function for interpolation
    - 
## Helpful Resources I Used
- https://www.redblobgames.com/maps/terrain-from-noise/
- https://iquilezles.org/www/articles/warp/warp.htm
- https://iquilezles.org/www/articles/palettes/palettes.htm
- https://thebookofshaders.com/edit.php#12/metaballs.frag

# HW 0: Intro to Javascript and WebGL
The fragment shader is implemented with 3D perlin and worley noise, both displaced with time. You can change one of the base colors using the color picker in the gui on the top right. The vertex shader displaces x and y coordinates with a sin function over time.

![Alt Text](https://media.giphy.com/media/MXjh2U0hGcgwJuGp27/giphy.gif?cid=790b761104e45ac8167ff98bc109ed47be8e78d0f975ffac&rid=giphy.gif&ct=g)
