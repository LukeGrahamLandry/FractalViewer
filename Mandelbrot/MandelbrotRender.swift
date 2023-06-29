import Metal
import MetalKit

struct MandelbrotRender {
    var device: MTLDevice;
    var mtl_layer: CAMetalLayer;
    var queue: MTLCommandQueue;
    var pipeline: MTLRenderPipelineState;
    
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
        print("Setup GPU");
    }

    mutating func draw(_ real_inputs: RealShaderInputs) {
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
        // Copy to allow taking the address. 
        var temp = real_inputs;
        // Stride vs size!
        encoder.setFragmentBytes(&temp, length: MemoryLayout<RealShaderInputs>.stride, index: 0);
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3);
        encoder.endEncoding();
        commands.present(drawable);
        commands.commit();
    }
}

struct ShaderInputs {
    var zoom: Float64 = 300.0;
    // This is added after pixel coordinates are scaled so it's in the complex units for the actual mandelbrot function. 
    var c_offset = float2(x: -2.85, y: -1.32);
    var steps: Int32 = 500;
    var colour_count: Int32 = 100;
    var z_initial = float2(x: 0.0, y: 0.0);
    var use_doubles = true;
}

let FLAG_USE_DOUBLES: Int32 = 1;
let FLAG_DO_JULIA: Int32 = 1 << 2;

struct RealShaderInputs {
    var zoom: df64_t;
    var c_offset: df64_2;
    var steps: Int32;
    var colour_count: Int32;
    var z_initial: df64_2;
    var flags: Int32;
}

// https://andrewthall.org/papers/df64_qf128.pdf

struct df64_t {
    var v: SIMD2<Float32>;
    init(_ a: Double) {
        let SPLITTER = Double((1 << 29) + 1);
        let t = a * SPLITTER;
        let x = t - (t - a);
        let y = a - x;
        self.v = SIMD2<Float32>(Float(x), Float(y));
    }
}

struct df64_2 {
    var x: df64_t;
    var y: df64_t;
    init(_ v: float2) {
        self.x = df64_t(v.x);
        self.y = df64_t(v.y);
    }
}
