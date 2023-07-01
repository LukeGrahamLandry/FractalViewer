#include <metal_stdlib>
using namespace metal;

#include "float_float.h"

typedef struct {
    float4 position [[position]];
} VertOut;


#define FLAG_USE_DOUBLES 1
#define FLAG_DO_JULIA 1 << 2
#define FLAG_ROOT_COLOURING 1 << 3

typedef struct {
    df64 zoom;
    df64_2 c_offset;
    int32_t steps;
    int32_t colour_count;
    df64_2 z_initial;
    int32_t flags;
    
} MandelbrotShaderInputs;


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
int count_iters_doubles(MandelbrotShaderInputs input, VertOut pixel) {
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
int count_iters_floats(MandelbrotShaderInputs input, VertOut pixel) {
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
fragment float4 fragment_main(constant MandelbrotShaderInputs& input [[buffer(0)]], VertOut pixel [[stage_in]]) {
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

// Newton Fractal //

typedef struct {
    df64 zoom;
    df64_2 offset;
    int32_t steps;
    int32_t flags;
    df64_2 f[4];
    df64_2 df[4];
    df64_2 roots[3];
    df64 epsilon;
    int32_t colour_count;
} NewtonShaderInputs;

inline df64_2 complex_mul(df64_2 a, df64_2 b) {
    df64 real = a.x * b.x - a.y * b.y;
    df64 imaginary = a.x * b.y + a.y * b.x;
    return df64_2(real, imaginary);
}

inline df64_2 complex_div(df64_2 a, df64_2 b) {
    df64 denom = b.x*b.x + b.y*b.y;
    df64 real = ((a.x * b.x) + (a.y * b.y)) / denom;
    df64 imaginary = ((a.y * b.x) - (a.x * b.y)) / denom;
    return df64_2(real, imaginary);
}

int newton_doubles(NewtonShaderInputs input, VertOut pixel) {
    df64_2 z = pixel.position.xy;
    z = z / input.zoom;
    z = z + input.offset;
    
    int i = 0;
    df64 dist1;
    df64 dist2;
    df64 dist3;
    for (;i<input.steps;i++){
        // TODO: this is not complex math!
#define eval(f) (f[0] + complex_mul(z, f[1]) + complex_mul(zSq, f[2]) + complex_mul(zCu, f[3]))
        df64_2 zSq = complex_mul(z, z);
        df64_2 zCu = complex_mul(z, zSq);
        df64_2 f_val = eval(input.f);
        df64_2 df_val = eval(input.df);
        z = z - complex_div(f_val, df_val);
        
        // Not one big short-circuiting expression because dists are used again below.
        dist1 = (z - input.roots[0]).lengthSqr();
        dist2 = (z - input.roots[1]).lengthSqr();
        dist3 = (z - input.roots[2]).lengthSqr();
        if (df_val.lengthSqr() < input.epsilon || dist1 < input.epsilon || dist2 < input.epsilon || dist3 < input.epsilon) {
            break;
        }
#undef eval
    }
    
    if (i == input.steps) {
        return -1;
    }
    
    if (input.flags & FLAG_ROOT_COLOURING){
        if (dist1 < dist2 && dist1 < dist3) return 0;
        else if (dist2 < dist3) return 1; // dist2 < dist1
        else return 2; // dist3 < dist2
    } else {
        return i;
    }
}

fragment float4 newton_fragment_main(constant NewtonShaderInputs& input [[buffer(0)]], VertOut pixel [[stage_in]]) {
    int root = newton_doubles(input, pixel);
    if (root == -1) {
        return {0.0, 0.0, 0.0, 1.0};
    }
    int colours = input.colour_count;
    if (input.flags & FLAG_ROOT_COLOURING){
        colours = 3;
    }
    float3 hsv = { (float) (root % colours) / (float) colours, 1.0, 1.0 };
    return float4(hsv2rgb(hsv), 1.0);
}
