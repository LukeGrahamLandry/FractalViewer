import Metal
import MetalKit
import ScreenSaver

class MandelbrotView: ScreenSaverView {
    var device: MTLDevice;
    var mtl_layer: CAMetalLayer;
    var queue: MTLCommandQueue;
    var pipeline: MTLRenderPipelineState;
    
    override init?(frame: NSRect, isPreview: Bool) {
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
        
        super.init(frame: frame, isPreview: isPreview);
        layer = mtl_layer;
        wantsLayer = true;
    }

    @available(*, unavailable)
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: NSRect) {
        
    }

    override func animateOneFrame() {
        super.animateOneFrame();
        mtl_layer.drawableSize = bounds.size;
        
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
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3);
        encoder.endEncoding();
        commands.present(drawable);
        commands.commit();
    }
}

let fuckyouxcode = """
                                 
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

                                 """;
