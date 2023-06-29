#include <metal_stdlib>
using namespace metal;

#include "float_float.h"

typedef struct {
    float4 position [[position]];
} VertOut;


#define FLAG_USE_DOUBLES 1
#define FLAG_DO_JULIA 1 << 2

typedef struct {
    df64 zoom;
    df64_2 c_offset;
    int32_t steps;
    int32_t colour_count;
    df64_2 z_initial;
    int32_t flags;
    
} ShaderInputs;


// Big triangle that covers the screen so the fragment shader runs for every pixel.
// https://www.saschawillems.de/blog/2016/08/13/vulkan-tutorial-on-rendering-a-fullscreen-quad-without-buffers/
vertex VertOut vertex_main(uint vid [[vertex_id]]) {
    return { float4(2 * (float) ((vid << 1) & 2) - 1, 2 * (float) (vid & 2) - 1, 0, 1) };
}

float3 hsv2rgb(float3 c){
    float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    float3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// TODO: can these be templates?
int count_iters_doubles(ShaderInputs input, VertOut pixel) {
    int i = 0;
    df64_2 c;
    df64_2 z;
    if (input.flags & FLAG_DO_JULIA){
        c = input.c_offset;
        z = pixel.position.xy;
        z = z / input.zoom;
        z = z + input.z_initial;
    } else {
        c = pixel.position.xy;
        c = c / input.zoom;
        c = c + input.c_offset;
        z = input.z_initial;
    }
    
    df64_2 zSq = z * z;
    for (;i<input.steps && (zSq.x + zSq.y).toFloat() < 4;i++){
        z.y = (z.x + z.x) * z.y;
        z.x = zSq.x - zSq.y;
        z = z + c;
        zSq = z * z;
    }
    return i;
}
// TODO: not passing by constant ref because it makes calling function annoying. hoping compiler just picks the best one. should measure to make sure
int count_iters_floats(ShaderInputs input, VertOut pixel) {
    int i = 0;
    float2 c;
    float2 z;
    if (input.flags & FLAG_DO_JULIA){
        c = input.c_offset.toFloat2();
        z = pixel.position.xy;
        z = z / input.zoom.toFloat();
        z = z + input.z_initial.toFloat2();
    } else {
        c = pixel.position.xy;
        c = c / input.zoom.toFloat();
        c = c + input.c_offset.toFloat2();
        z = input.z_initial.toFloat2();
    }
    float2 zSq = z * z;
    for (;i<input.steps && (zSq.x + zSq.y) < 4;i++){
        z.y = (z.x + z.x) * z.y;
        z.x = zSq.x - zSq.y;
        z = z + c;
        zSq = z * z;
    }
    return i;
}

// TODO: Since I can compile shaders at runtime, you could enter an equation in a text box and I could do the Newton fractal 
fragment float4 fragment_main(constant ShaderInputs& input [[buffer(0)]], VertOut pixel [[stage_in]]) {
    int i;
    // Branches are bad but every pixel is guarenteeed to take the same one so I think it's fine.
    // TODO: measure to make sure or split these into different shaders.
    if (input.flags & FLAG_USE_DOUBLES) {
        i = count_iters_doubles(input, pixel);
    } else {
        i = count_iters_floats(input, pixel);
    }
    
    // TODO: toggle for colour smoothing https://en.wikipedia.org/wiki/Plotting_algorithms_for_the_Mandelbrot_set#Continuous_(smooth)_coloring
    if (i == input.steps) {
        return {0.0, 0.0, 0.0, 1.0};
    }
    float3 hsv = { (float) (i % input.colour_count) / (float) input.colour_count, 1.0, 1.0 };
    return float4(hsv2rgb(hsv), 1.0);
}

// TODO: show corisponding julia set
// TODO: move around c for julia set
