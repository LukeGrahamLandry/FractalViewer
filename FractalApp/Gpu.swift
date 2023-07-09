import Metal
import MetalKit

struct Gpu {
    var device: MTLDevice;
    var mtl_layer: CAMetalLayer;
    var queue: MTLCommandQueue;
    var mandelbrot_pipeline: MTLRenderPipelineState;
    var newton_pipeline: MTLRenderPipelineState;
    
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
        mandelbrot_pipeline = (try? device.makeRenderPipelineState(descriptor: pipe_desc))!;
        pipe_desc.fragmentFunction = library.makeFunction(name: "newton_fragment_main")!;
        newton_pipeline = (try? device.makeRenderPipelineState(descriptor: pipe_desc))!;
        mtl_layer = CAMetalLayer();
        mtl_layer.device = device;
        mtl_layer.pixelFormat = .bgra8Unorm;
        queue = device.makeCommandQueue()!;
        print("Setup GPU");
    }

    mutating func draw_mandelbrot(_ real_inputs: MandelbrotShaderInputs) {
        let drawable = mtl_layer.nextDrawable()!;
        let pass_desc = MTLRenderPassDescriptor();
        let colour_attatch = pass_desc.colorAttachments[0]!;
        colour_attatch.texture = drawable.texture;
        colour_attatch.loadAction = .clear;
        colour_attatch.storeAction = .store;
        colour_attatch.clearColor = .init(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0);
        
        let commands = queue.makeCommandBuffer()!;
        let encoder = commands.makeRenderCommandEncoder(descriptor: pass_desc)!;
        encoder.setRenderPipelineState(mandelbrot_pipeline);
        // Copy to allow taking the address. 
        var temp = real_inputs;
        // Stride vs size!
        encoder.setFragmentBytes(&temp, length: MemoryLayout<MandelbrotShaderInputs>.stride, index: 0);
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3);
        encoder.endEncoding();
        commands.present(drawable);
        commands.commit();
    }
    
    // TODO: this is a copy-paste
    mutating func draw_newton(_ newton_inputs: NewtonShaderInputs, _ real_inputs: MandelbrotShaderInputs) {
        let drawable = mtl_layer.nextDrawable()!;
        let pass_desc = MTLRenderPassDescriptor();
        let colour_attatch = pass_desc.colorAttachments[0]!;
        colour_attatch.texture = drawable.texture;
        colour_attatch.loadAction = .clear;
        colour_attatch.storeAction = .store;
        colour_attatch.clearColor = .init(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0);
        
        let commands = queue.makeCommandBuffer()!;
        let encoder = commands.makeRenderCommandEncoder(descriptor: pass_desc)!;
        encoder.setRenderPipelineState(newton_pipeline);
        
        var temp_newton = newton_inputs;
        temp_newton.zoom = real_inputs.zoom;
        temp_newton.offset = real_inputs.c_offset;
        temp_newton.steps = real_inputs.steps;
        temp_newton.flags = real_inputs.flags;
        temp_newton.colour_count = real_inputs.colour_count;
        
        // Stride vs size!
        encoder.setFragmentBytes(&temp_newton, length: MemoryLayout<NewtonShaderInputs>.stride, index: 0);
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3);
        encoder.endEncoding();
        commands.present(drawable);
        commands.commit();
    }
}

// TODO: switch the screen saver to use the same model class as the app.
struct OldShaderInputs {
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
let FLAG_ROOT_COLOURING: Int32 = 1 << 3;

struct MandelbrotShaderInputs {
    var zoom: df64_t;
    var c_offset: df64_2;
    var steps: Int32;
    var colour_count: Int32;
    var z_initial: df64_2;
    var flags: Int32;
}

struct NewtonShaderInputs {
    var zoom: df64_t;
    var offset: df64_2;
    var steps: Int32;
    var flags: Int32;
    var f0: df64_2;
    var f1: df64_2;
    var f2: df64_2;
    var f3: df64_2;
    var df0: df64_2;
    var df1: df64_2;
    var df2: df64_2;
    var df3: df64_2;
    var r0: df64_2;
    var r1: df64_2;
    var r2: df64_2;
    var epsilon: df64_t;
    var colour_count: Int32;
    
    static func create(roots: Array<float2>) -> NewtonShaderInputs {
        let f = Polynomial(roots: roots);
        let df = f.derivative();
        return NewtonShaderInputs(zoom: df64_t(1), offset: df64_2(float2(0, 0)), steps: 1, flags: 0, f0: df64_2(f.coefficients[0]), f1: df64_2(f.coefficients[1]), f2: df64_2(f.coefficients[2]), f3: df64_2(f.coefficients[3]), df0: df64_2(df.coefficients[0]), df1: df64_2(df.coefficients[1]), df2: df64_2(df.coefficients[2]), df3: df64_2(df.coefficients[3]), r0: df64_2(roots[0]), r1: df64_2(roots[1]), r2: df64_2(roots[2]), epsilon: df64_t(0.000001), colour_count: 3);

    }
};

struct df64_t {
    var v: SIMD2<Float32>;
    init(_ a: Double) {
        // https://andrewthall.org/papers/df64_qf128.pdf
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
