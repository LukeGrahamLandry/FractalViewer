import Metal
import MetalKit
import ScreenSaver

// TODO: rearrange my classes to prepare for seperate julia set window. 
struct MandelbrotRender {
    var device: MTLDevice;
    var mtl_layer: CAMetalLayer;
    var queue: MTLCommandQueue;
    var pipeline: MTLRenderPipelineState;
    var input: ShaderInputs;
    
    // TODO: return an error here and show a message if metal setup fails
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
        input = ShaderInputs(zoom: 300.0, c_offset: float64x2_t(x: -2.85, y: -1.32), steps: 500, colour_count: 100, z_initial: float64x2_t(x: 0.0, y: 0.0));
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
        var real_inputs = RealShaderInputs(
            zoom: df64_t(input.zoom),
            c_offset: df64_2(input.c_offset),
            steps: input.steps,
            colour_count: input.colour_count,
            z_initial: df64_2(input.z_initial)
        );
        // Stride vs size!
        encoder.setFragmentBytes(&real_inputs, length: MemoryLayout<RealShaderInputs>.stride, index: 0);
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3);
        encoder.endEncoding();
        commands.present(drawable);
        commands.commit();
    }
}

struct ShaderInputs {
    var zoom: Float64;
    // This is added after pixel coordinates are scaled so it's in the complex units for the actual mandelbrot function. 
    var c_offset: float64x2_t;
    var steps: Int32;
    var colour_count: Int32;
    var z_initial: float64x2_t;
}

struct RealShaderInputs {
    var zoom: df64_t;
    var c_offset: df64_2;
    var steps: Int32;
    var colour_count: Int32;
    var z_initial: df64_2;
}

struct df64_t {
    var v: float32x2_t;
    init(_ a: Double) {
        let SPLITTER = Double((1 << 29) + 1);
        let t = a * SPLITTER;
        let x = t - (t - a);
        let y = a - x;
        self.v = float32x2_t(Float(x), Float(y));
    }
}

struct df64_2 {
    var x: df64_t;
    var y: df64_t;
    init(_ v: float64x2_t) {
        self.x = df64_t(v.x);
        self.y = df64_t(v.y);
    }
}
