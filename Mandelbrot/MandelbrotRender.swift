import Metal
import MetalKit
import ScreenSaver

struct MandelbrotRender {
    var device: MTLDevice;
    var mtl_layer: CAMetalLayer;
    var queue: MTLCommandQueue;
    var pipeline: MTLRenderPipelineState;
    var frame_index: Float32 = 0.0;
    
    init() {
        device = MTLCreateSystemDefaultDevice()!;
//        let shaderURL = Bundle.main.url(forResource: "default", withExtension: "metallib")!;
//        let library = (try? device.makeLibrary(URL: shaderURL))!;
        // let library = (try? device.makeDefaultLibrary(bundle: Bundle.main))!;
//        let library = device.makeDefaultLibrary()!;
    
        let library = (try? device.makeLibrary(source: fuckyouxcode, options: nil))!;
        let pipe_desc = MTLRenderPipelineDescriptor();
        pipe_desc.vertexFunction = library.makeFunction(name: "vertex_main")!;
        pipe_desc.fragmentFunction = library.makeFunction(name: "fragment_main")!;
        pipe_desc.colorAttachments[0].pixelFormat = .bgra8Unorm;
        pipeline = (try? device.makeRenderPipelineState(descriptor: pipe_desc))!;
        mtl_layer = CAMetalLayer();
        mtl_layer.device = device;
        mtl_layer.pixelFormat = .bgra8Unorm;
        queue = device.makeCommandQueue()!;
    }

    mutating func draw() {
        let drawable = mtl_layer.nextDrawable()!;
        let pass_desc = MTLRenderPassDescriptor();
        let colour_attatch = pass_desc.colorAttachments[0]!;
        colour_attatch.texture = drawable.texture;
        colour_attatch.loadAction = .clear;
        colour_attatch.storeAction = .store;
        colour_attatch.clearColor = .init(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0);
        
        let commands = queue.makeCommandBuffer()!;
        let encoder = commands.makeRenderCommandEncoder(descriptor: pass_desc)!;
        encoder.setRenderPipelineState(pipeline);
        var input = ShaderInputs(t: frame_index * (frame_index * 0.5), c_offset: float32x2_t(x: 0.35, y: 0.1), resolution: 50);
        encoder.setFragmentBytes(&input, length: MemoryLayout<ShaderInputs>.stride, index: 0);
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3);
        encoder.endEncoding();
        commands.present(drawable);
        commands.commit();
        frame_index += 1.0;
    }
}

struct ShaderInputs {
    var t: Float32;
    var c_offset: float32x2_t;
    var resolution: Int32;
}


let fuckyouxcode = """
                                 #include <metal_stdlib>
                                 using namespace metal;

                                 typedef struct {
                                     float4 position [[position]];
                                 } VertOut;

                                 typedef struct {
                                     float t;
                                     float2 c_offset;
                                     int32_t resolution;
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
                                     c.x -= 500;
                                     c.y -= 500;
                                     c /= input.t;
                                     c += input.c_offset;
                                     for (;i<input.resolution && length_squared(z) <= 4;i++){
                                         z = complex_mul(z, z) + c;
                                     }
                                     float3 hsv = { (float) i / (float) input.resolution, 1.0, 1.0 };
                                     return float4(hsv2rgb(hsv), 1.0);
                                 }

                                 """;
