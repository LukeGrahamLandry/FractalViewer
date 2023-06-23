#include <metal_stdlib>
using namespace metal;

typedef struct {
    float4 position [[position]];
} VertOut;

// Big triangle that covers the screen so the fragment shader runs for every pixel.
// https://www.saschawillems.de/blog/2016/08/13/vulkan-tutorial-on-rendering-a-fullscreen-quad-without-buffers/
vertex VertOut vertex_main(uint vid [[vertex_id]]) {
    return { float4(2 * (float) ((vid << 1) & 2) - 1, 2 * (float) (vid & 2) - 1, 0, 1) };
}

fragment float4 fragment_main(VertOut pixel [[stage_in]]) {
    return float4(1.0, 0.0, 0.1, 1.0);
}
