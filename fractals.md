# Learning Fractal Magic

## Colour Spaces
- https://www.laurivan.com/rgb-to-hsv-to-rgb-for-shaders/

## Complex Numbers 
- `#define complex_mul(a, b) float2(a.x*b.x-a.y*b.y, a.x*b.y+a.y*b.x)`

## Mandlebrot 
- https://mathigon.org/course/fractals/mandelbrot
Everything outside 2 radius circle around origin is guarenteeed to diverge 
(TODO?) to fix the colour stair step
    - http://linas.org/art-gallery/escape/escape.html
Simple algebra to simplify the loop
    - https://en.wikipedia.org/wiki/Plotting_algorithms_for_the_Mandelbrot_set
    - https://randomascii.wordpress.com/2011/08/13/faster-fractals-through-algebra/
(TODO?) approximation for higher zoom when floats run out of precision:
    - https://math.stackexchange.com/questions/939270/perturbation-of-mandelbrot-set-fractal

## Higher Precision Math
