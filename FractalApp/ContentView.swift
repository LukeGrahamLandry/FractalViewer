import SwiftUI
import MetalKit

// TODO: this should be different for different fractals 
let MAX_ZOOM_LOG2: Float64 = 50;

struct MetalView: NSViewRepresentable {
    var model: Model;
    @ObservedObject var canvas: CanvasModel;
    
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // This only gets called the first time the view is made.
    func makeNSView(context: NSViewRepresentableContext<MetalView>) -> MTKView {
        let mtkView = MTKView();
        mtkView.delegate = context.coordinator;
        mtkView.preferredFramesPerSecond = self.canvas.fps;
        mtkView.enableSetNeedsDisplay = true;
        mtkView.device = self.model.gpu.device;
        mtkView.framebufferOnly = false;
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0);
        mtkView.isPaused = false;
        mtkView.layer = self.model.gpu.mtl_layer;
        self.model.addEventListeners(self.canvas);
        DispatchQueue.main.async {
            self.model.canvasUpdateCount += 1;
        };
        return mtkView;
    }
    
    // This gets called when an @State change triggers a view update.
    func updateNSView(_ nsView: MTKView, context: NSViewRepresentableContext<MetalView>) {
        // Update the fake canvas sizes.
        self.model.gpu.mtl_layer.drawableSize = self.model.scaledDrawSize(self.canvas);
        nsView.drawableSize = self.model.scaledDrawSize(self.canvas);
        nsView.preferredFramesPerSecond = self.canvas.fps;
        self.model.dirty = true;
        self.model.addEventListeners(self.canvas);
        DispatchQueue.main.async {
            self.model.canvasUpdateCount += 1;
        };
    }
    
    class Coordinator : NSObject, MTKViewDelegate {
        var parent: MetalView
        
        init(_ parent: MetalView) {
            self.parent = parent
            super.init();
        }
        
        // This gets called when the window resizes OR when I change the resolution so it's kinda useless.
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            
        }
        
        func draw(in view: MTKView) {
            // TODO: framerate independence
            if parent.model.delta != float2(0.0, 0.0) {
                parent.model.z_initial += parent.model.delta;
                parent.model.z_initial = clamp(parent.model.z_initial, min: float2(-2, -2), max: float2(2, 2));
            } else if !parent.model.dirty {
                // If not moving and haven't zoomed, don't bother rendering this frame.
                return;
            }
            
            let debug = MTLCaptureManager.shared().makeCaptureScope(commandQueue: parent.model.gpu.queue);
            MTLCaptureManager.shared().defaultCaptureScope = debug;
            debug.begin();
            
            if (parent.model.selectedFractal == .newton) {
                parent.model.gpu.draw_newton(parent.model.newtonInputs, parent.model.shaderInputs());
            } else {
                parent.model.gpu.draw_mandelbrot(parent.model.shaderInputs());
            }
            
            debug.end();
            parent.model.dirty = false;
        }
    }
}


// These are variables that must trigger updateNSView.
class CanvasModel: ObservableObject {
    // This is the value controlled by the slider so you can adjust performace.
    @Published var resolutionScale: Float64 = 1.0;
    @Published var realSize: CGSize = .zero;
    
    // This comes from the monitor settings.
    // Can't just put @Environment on this field because reading it every frame while zooming is really slow.
    @Published var displayScale: CGFloat = 1.0;
    @Published var fps = 30;
    
    // Real unscaled area in pixels. This also tells you which part of the window is the view.
    @Published var canvasArea: CGRect = .zero;
    @Published var windowArea: CGRect = .zero;
    @Published var showSidebars = true;
}

// The published fields cause the ui to update. The dirty field causes the frame to redraw.
class Model: ObservableObject {
    @Published var zoom: Float64 = 300.0;
    @Published var c_offset = float2(x: -2.85, y: -1.32);
    @Published var z_initial = float2(x: 0.0, y: 0.0);
    @Published var steps = 500;
    @Published var colour_count = 100;
    @Published var selectedFractal = Fractal.mandelbrot;
    @Published var floatPrecisionCutoff = Float64(1 << 22);
    var prevZ = float2(x: 0.0, y: 0.0);
    
    // TODO: this should be on the MetalView instead but it needs to not be recreated every update.
    var gpu = Gpu();
    
    var delta = float2(0.0, 0.0);
    
    var dirty = true;
    
    // TODO: take out the parts that don't apply to the screen saver
    @Published var canvasUpdateCount = 0;
    var eventHandlers: Array<Any?> = [];
    
    
    var newtonInputs = NewtonShaderInputs.create(roots: [float2(0, 0), float2(0, 0), float2(0, 0)]);
    @Published var r1 = float2(1.0, 0.0);
    @Published var r2 = float2(2.0, 5.0);
    @Published var r3 = float2(3.0, 0.0);
    @Published var newtonColouring = NewtonColouring.root;
    
    init() {
        self.updateNewton();
    }
    
    // Change the zoom but adjust the translation so it looks like the zoom is centered at an arbitrary point.
    // The chosen window position will corrispond to the same complex position before and after the zoom.
    func zoomCentered(windowX: Float64, windowY: Float64, newZoom: Float64, _ canvas: CanvasModel){
        let oldZoom = self.zoom;
        let center = self.windowToCanvas(windowX, windowY, canvas);
        let c_old_offset = center / oldZoom;
        let c_new_offset = center / newZoom;
        let delta = c_old_offset - c_new_offset;
        if self.selectedFractal == .julia {
            self.z_initial += delta;
        } else {
            self.c_offset += delta;
        }
        self.dirty = true;
        self.zoom = newZoom;
    }
    
    func scaledDrawSize(_ canvas: CanvasModel) -> CGSize {
        let size = canvas.canvasArea;
        // TODO: maintain aspect ratio when clamping.
        let w = max(50.0, size.width / canvas.resolutionScale * canvas.displayScale);
        let h = max(50.0, size.height / canvas.resolutionScale * canvas.displayScale);
        return CGSize(width: w, height: h);
    }
    
    func windowToCanvas(_ x: Float64, _ y: Float64, _ canvas: CanvasModel) -> float2 {
        let s = 1.0 / canvas.resolutionScale * canvas.displayScale;
        let new_x = (x - Float64(canvas.canvasArea.minX)) * s;
        // TODO: need to use minY somehow if I ever make it not take up full window height
        let new_y = Float64((canvas.canvasArea.height * s) - (y * s));
        return float2(new_x, new_y);
    }
    
    func windowToCanvas(_ pos: float2, _ canvas: CanvasModel) -> float2 {
        return self.windowToCanvas(pos.x, pos.y, canvas);
    }
    
    func windowToCanvasVec(_ x: Float64, _ y: Float64, _ canvas: CanvasModel) -> float2 {
        let zero = self.windowToCanvas(0, 0, canvas);
        let pos = self.windowToCanvas(x, -y, canvas);
        return zero - pos;
    }
    
    func shaderInputs() -> MandelbrotShaderInputs {
        var flags: Int32 = 0;
        if self.usingDoubles() {
            flags |= FLAG_USE_DOUBLES;
        }
        if self.selectedFractal == .julia {
            flags |= FLAG_DO_JULIA;
        }
        if self.newtonColouring == .root {
            flags |= FLAG_ROOT_COLOURING;
        }
        
        return MandelbrotShaderInputs(
            zoom: df64_t(self.zoom),
            c_offset: df64_2(self.c_offset),
            steps: Int32(self.steps),
            colour_count: Int32(self.colour_count),
            z_initial: df64_2(self.z_initial),
            flags: flags
        );
    }
    
    // TODO: drop down to force one that defaults to auto. 
    func usingDoubles() -> Bool {
        return self.zoom > self.floatPrecisionCutoff;
    }
    
    func minZoom() -> Float64 {
        return self.selectedFractal == .newton ? 0.001 : 1.0;
    }
    
    func setDefaults(){
        self.zoom = 300.0;
        self.c_offset = float2(x: -2.85, y: -1.32);
        self.z_initial = float2(x: 0.0, y: 0.0);
        self.steps = 500;
        self.colour_count = 100;
        self.dirty = true;
    }
    
    func updateNewton() -> Polynomial {
        self.dirty = true;
        self.newtonInputs = NewtonShaderInputs.create(roots: [r1, r2, r3]);
        return Polynomial(roots: [r1, r2, r3]);
    }
    
    func addEventListeners(_ canvas: CanvasModel) {
        for handler in eventHandlers {
            if handler != nil {
                NSEvent.removeMonitor(handler!);
            }
        }
        self.eventHandlers.removeAll(keepingCapacity: true);
        
        // Zoom
        // TODO: this needs to be framerate independant
        self.eventHandlers.append(NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel]) {
            let old_zoom_log2 = log2(self.zoom);
            let zoom_delta_log2 = Float64($0.scrollingDeltaY) * 0.00005 * max(old_zoom_log2, 3);
            let new_zoom_raw = pow(2, old_zoom_log2 + zoom_delta_log2);
            let new_zoom = min(max(new_zoom_raw, self.minZoom()), Float64(1 << Int(MAX_ZOOM_LOG2)));
            self.zoomCentered(windowX: $0.locationInWindow.x, windowY: $0.locationInWindow.y, newZoom: new_zoom, canvas);
            return $0
        });
        
        // Drag to move
        self.eventHandlers.append(NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDragged]) {
            let mousePos = self.windowToCanvas($0.locationInWindow.x, $0.locationInWindow.y, canvas);
            
            // TODO: this needs to know about scale so it doesnt think you're moving when dragging the window between monitors.
            if (!canvas.canvasArea.contains($0.locationInWindow) || mousePos.y < 0) {
                return $0;
            }
            let delta = self.windowToCanvasVec($0.deltaX, $0.deltaY, canvas) / self.zoom;
            if self.selectedFractal == .julia {
                self.z_initial += delta;
            } else {
                self.c_offset += delta;
            }
            self.dirty = true;
            return nil;
        });
        
        // TODO: for z move dont just use scale cause that gets too slow.
        // Keys to move
        self.eventHandlers.append(NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) {
            let move_speed = 10.0 / self.zoom;
            // https://stackoverflow.com/questions/1918841/how-to-convert-ascii-character-to-cgkeycode
            // TODO: theres no way this is what you're supposed to do
            switch ($0.keyCode){
            case 0:   // a
                self.delta.x = -move_speed;
            case 1:   // s
                self.delta.y = move_speed;
            case 2:   // d
                self.delta.x = move_speed;
            case 13:   // w
                self.delta.y = -move_speed;
            case 14:   // e
                canvas.showSidebars = !canvas.showSidebars;
            default:
                return $0;
            }
            // Say we handled the event so it doesn't make the angry bing noise.
            return nil;
        });
        
        // Stop key moving
        NSEvent.addLocalMonitorForEvents(matching: [.keyUp]) {
            // https://stackoverflow.com/questions/1918841/how-to-convert-ascii-character-to-cgkeycode
            // TODO: theres no way this is what you're supposed to do
            switch ($0.keyCode){
            case 0:   // a
                self.delta.x = 0.0;
            case 1:   // s
                self.delta.y = 0.0;
            case 2:   // d
                self.delta.x = 0.0;
            case 13:   // w
                self.delta.y = 0.0;
            default:
                return $0;
            }
            return nil;
        };
    }
}
