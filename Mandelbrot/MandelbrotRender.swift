import Metal
import MetalKit
import ScreenSaver

struct MandelbrotRender {
    var device: MTLDevice;
    var mtl_layer: CAMetalLayer;
    var queue: MTLCommandQueue;
    var pipeline: MTLRenderPipelineState;
    var frame_index: Float32 = 1.0;
    var input: ShaderInputs;
    
    init() {
        device = MTLCreateSystemDefaultDevice()!;
        let library = device.makeDefaultLibrary()!;
        // Default library seems to not work with screen saver? I see it in the package but it gives nil. Can paste the MSL as a string.
        // let library = (try? device.makeLibrary(source: fuckyouxcode, options: nil))!;
        let pipe_desc = MTLRenderPipelineDescriptor();
        pipe_desc.vertexFunction = library.makeFunction(name: "vertex_main")!;
        pipe_desc.fragmentFunction = library.makeFunction(name: "fragment_main")!;
        pipe_desc.colorAttachments[0].pixelFormat = .bgra8Unorm;
        pipeline = (try? device.makeRenderPipelineState(descriptor: pipe_desc))!;
        mtl_layer = CAMetalLayer();
        mtl_layer.device = device;
        mtl_layer.pixelFormat = .bgra8Unorm;
        queue = device.makeCommandQueue()!;
        input = ShaderInputs(t: 1.0, c_offset: float32x2_t(x: -0.15, y: -0.4), resolution: 100, colour_count: 100);
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
        input.t = frame_index * (frame_index * 0.5);
        // size works for screen saver but not for app. idk
        encoder.setFragmentBytes(&input, length: MemoryLayout<ShaderInputs>.stride, index: 0);
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3);
        encoder.endEncoding();
        commands.present(drawable);
        commands.commit();
        // frame_index += 1.0;  // TODO: flag
    }
}

struct ShaderInputs {
    var t: Float32;
    // This is added after pixel coordinates are scaled so it's in the complex units for the actual mandelbrot function. 
    var c_offset: float32x2_t;
    var resolution: Int32;
    var colour_count: Int32;  // Probably going to remove this. wasn't interesting. 
}