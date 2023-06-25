#include <metal_stdlib>
using namespace metal;

#include "float_float.h"

typedef struct {
    float4 position [[position]];
} VertOut;

typedef struct {
    float zoom;
    float2 c_offset;
    int32_t steps;
    int32_t colour_count;
    float2 z_initial;
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

fragment float4 fragment_main(constant ShaderInputs& input [[buffer(0)]], VertOut pixel [[stage_in]]) {
    int i = 0;
    df64_2 c = pixel.position.xy;
    c = c / df64_2(input.zoom);
    c = c + df64_2(input.c_offset);
    df64_2 z = input.z_initial;
    df64_2 zSq = z * z;
    for (;i<input.steps && (zSq.x + zSq.y).toFloat() < 4;i++){
        z.y = (z.x + z.x) * z.y;
        z.x = zSq.x - zSq.y;
        z = z + c;
        zSq = z * z;
    }
    // Sad branch noises but nobody cares. 
    if (i == input.steps) {
        return {0.0, 0.0, 0.0, 1.0};
    }
    float3 hsv = { (float) (i % input.colour_count) / (float) input.colour_count, 1.0, 1.0 };
    return float4(hsv2rgb(hsv), 1.0);
}

// TODO: show corisponding julia set
// TODO: move around c for julia set
// TODO: beware fast-math when i start cheating precision
