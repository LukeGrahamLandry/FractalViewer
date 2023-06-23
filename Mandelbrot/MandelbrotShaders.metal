#include <metal_stdlib>
using namespace metal;

typedef struct {
    float4 position [[position]];
} VertOut;

typedef struct {
    float t;
    float2 c_offset;
    int32_t resolution;
    int32_t colour_count;
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

#define complex_mul(a, b) float2(a.x*b.x-a.y*b.y, a.x*b.y+a.y*b.x)

fragment float4 fragment_main(constant ShaderInputs& input [[buffer(0)]], VertOut pixel [[stage_in]]) {
    int i = 0;
    float2 z = float2(0.0, 0.0);
    float2 c = { pixel.position.x, pixel.position.y};
    c /= input.t;
    c += input.c_offset;
    for (;i<input.resolution && length_squared(z) <= 4;i++){
        z = complex_mul(z, z) + c;
    }
    // Sad branch noises but nobody cares. 
    if (i == input.resolution) {
        return {0.0, 0.0, 0.0, 1.0};
    }
    float3 hsv = { (float) (i % input.colour_count) / (float) input.colour_count, 1.0, 1.0 };
    return float4(hsv2rgb(hsv), 1.0);
}
