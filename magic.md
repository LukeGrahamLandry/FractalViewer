# Magic

// Complex Numbers 
- `#define complex_mul(a, b) float2(a.x*b.x-a.y*b.y, a.x*b.y+a.y*b.x)`

// Mandlebrot 
- https://mathigon.org/course/fractals/mandelbrot
// everything outside 2 radius circle around origin is guarenteeed to diverge 
to fix the colour stair step: http://linas.org/art-gallery/escape/escape.html
approximation for higher zoom when floats run out of precision: https://math.stackexchange.com/questions/939270/perturbation-of-mandelbrot-set-fractal

// Big triangle that covers the screen so the fragment shader runs for every pixel.
- https://www.saschawillems.de/blog/2016/08/13/vulkan-tutorial-on-rendering-a-fullscreen-quad-without-buffers/
- `{ float4(2 * (float) ((vid << 1) & 2) - 1, 2 * (float) (vid & 2) - 1, 0, 1) }`

// https://www.laurivan.com/rgb-to-hsv-to-rgb-for-shaders/
