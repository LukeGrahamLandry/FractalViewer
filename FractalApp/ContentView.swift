import SwiftUI
import MetalKit

struct PosGetter: View {
    var model: Model;
    var displayScale: CGFloat;
    @Binding var resolutionScale: Float64;
    
    var body: some View {
        GeometryReader { geo ->MetalView in
            MetalView(self.model, self.displayScale, geo, self.resolutionScale)
        }
    }
}

// https://developer.apple.com/forums/thread/119112
struct MetalView: NSViewRepresentable {
    var model: Model;
    // I think this field getting set by a binding on an upper view causes updateNSView to fire when the resolution bar changes (which is what I want).
    var resolutionScale: Float64;
    var realSize: CGSize;
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // This only gets called the first time the view is made.
    func makeNSView(context: NSViewRepresentableContext<MetalView>) -> MTKView {
        let mtkView = MTKView();
        self.model.mtkView = mtkView;
        mtkView.delegate = context.coordinator;
        mtkView.preferredFramesPerSecond = 60;  // TODO: this can be 20
        mtkView.enableSetNeedsDisplay = true;
        mtkView.device = self.model.fractal.device;
        mtkView.framebufferOnly = false;
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0);
        mtkView.isPaused = false;
        mtkView.layer = self.model.fractal.mtl_layer;
        return self.model.mtkView!;
    }
    
    // TODO: displayScale is not used properly. changing mointors messes stuff up. 
    // This gets called when an @State change triggers a view update.
    func updateNSView(_ nsView: MTKView, context: NSViewRepresentableContext<MetalView>) {
        print("updateNSView");
        
        // Compensate with zoom so you stay looking at the same area.
        let old_scale = self.model.resolutionScale;
        let new_scale = self.resolutionScale;
        let raw_zoom = self.model.input.zoom * old_scale;
        self.model.input.zoom = raw_zoom / new_scale;
        
        // Update the fake canvas sizes.
        self.model.realSize = self.realSize;
        self.model.resolutionScale = self.resolutionScale;
        self.model.fractal.mtl_layer.drawableSize = self.model.scaledDrawSize();
        nsView.drawableSize = self.model.scaledDrawSize();
        self.model.dirty = true;
    }
    
    init(_ m: Model, _ ds: CGFloat, _ geo: GeometryProxy, _ resolutionScale: Float64){
        print("init MetalView \(resolutionScale) geoSize: \(geo.size)");
        self.resolutionScale = resolutionScale;
        self.model = m;
        // There seem to be multiple instance of the view floating around.
        // You need to store this on the model instead of just using it in the closure.
        model.displayScale = ds;
        self.realSize = geo.size;
        
        let new_area = geo.frame(in: .global);
        if let old_area = m.canvasArea {
            let new_corner = float2(old_area.minX, old_area.minY);
            let old_corner = float2(new_area.minX, new_area.minY);
            let s = m.displayScale / m.resolutionScale / m.input.zoom;
            let delta = (old_corner - new_corner) * s;
            m.input.c_offset += delta;
        }
        
        m.canvasArea = new_area;
        
        // Zoom
        // TODO: this needs to be framerate independant
        NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel]) {
            let zoom_delta = Float64($0.scrollingDeltaY) * 0.00001 * m.input.zoom / m.displayScale;
            let old_zoom = m.input.zoom;
            let new_zoom = min(max(old_zoom + zoom_delta, 1.0), 1_010_000_000_000_000);
            
            // We want the zoom to be centered on the mouse.
            // So calculate the mouse position and then see how much it would move with the new zoom
            // and translate the camera by that much to compensate.
            let canvas_mouse_pos = m.windowToCanvas($0.locationInWindow.x, $0.locationInWindow.y);
            let c_mouse_offset = canvas_mouse_pos / old_zoom;
            let c_new_mouse_offset = canvas_mouse_pos / new_zoom;
            m.input.c_offset += c_mouse_offset - c_new_mouse_offset;
            
            m.dirty = true;
            m.input.zoom = new_zoom;
            
            return $0
        };
        
        // Drag to move
        NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDragged]) {
            let mousePos = m.windowToCanvas($0.locationInWindow.x, $0.locationInWindow.y);
            if m.canvasArea != nil && (!m.canvasArea!.contains($0.locationInWindow) || mousePos.y < 0) {
                return $0;
            }
//            let s = m.displayScale / m.resolutionScale / m.input.zoom;
//            let delta = float2(Float64($0.deltaX), Float64($0.deltaY)) * s;
            let zero = m.windowToCanvas(0, 0);
            let pos = m.windowToCanvas($0.deltaX, -$0.deltaY);
            let delta = zero - pos;
            m.input.c_offset += delta / m.input.zoom;
            m.dirty = true;
            return nil;
        }
        
        // TODO: for z move dont just use scale cause that gets too slow.  
        // Keys to move
        NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) {
            let move_speed = 10.0 / m.input.zoom;
            // https://stackoverflow.com/questions/1918841/how-to-convert-ascii-character-to-cgkeycode
            // TODO: theres no way this is what you're supposed to do
            switch ($0.keyCode){
            case 0:   // a
                m.delta.x = -move_speed;
            case 1:   // s
                m.delta.y = move_speed;
            case 2:   // d
                m.delta.x = move_speed;
            case 13:   // w
                m.delta.y = -move_speed;
            default:
                return $0;
            }
            // Say we handled the event so it doesn't make the angry bing noise.
            return nil;
        };
        
        // Stop key moving
        NSEvent.addLocalMonitorForEvents(matching: [.keyUp]) {
            // https://stackoverflow.com/questions/1918841/how-to-convert-ascii-character-to-cgkeycode
            // TODO: theres no way this is what you're supposed to do
            switch ($0.keyCode){
            case 0:   // a
                m.delta.x = 0.0;
            case 1:   // s
                m.delta.y = 0.0;
            case 2:   // d
                m.delta.x = 0.0;
            case 13:   // w
                m.delta.y = 0.0;
            default:
                return $0;
            }
            return nil;
        };
    }
    
    class Coordinator : NSObject, MTKViewDelegate {
        var parent: MetalView
        
        init(_ parent: MetalView) {
            self.parent = parent
            super.init()
        }
        
        // This gets called when the window resizes OR when I change the resolution.
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            print("drawableSizeWillChange");
            // TODO: this should do nothing. metalview is recreated when window is resized (because of GeometryReader I think). 
//            print("drawableSizeWillChange");
//            self.parent.model.dirty = true;
//            // TODO: Hack!
//            if !self.parent.model.isFakeResizing {
//                // If this size event was sent because we're changing the resolution, don't forget what the real size was.
//                let s = self.parent.model.resolutionScale;
//                self.parent.model.realSize = CGSize(width: size.width * s, height: size.height * s);
//
//                // Changing resolution already set mtl_layer.drawableSize so don't bother.
//                self.parent.model.fractal.mtl_layer.drawableSize = self.parent.model.scaledDrawSize();
//            }
        }
        
        func draw(in view: MTKView) {
            if parent.model.delta != float2(0.0, 0.0) {
                parent.model.input.z_initial += parent.model.delta;
                parent.model.input.z_initial = clamp(parent.model.input.z_initial, min: float2(-2, -2), max: float2(2, 2));
            } else if !parent.model.dirty {
                // If not moving and haven't zoomed, don't bother rendering this frame.
                return;
            }
            
            let debug = MTLCaptureManager.shared().makeCaptureScope(commandQueue: parent.model.fractal.queue);
            MTLCaptureManager.shared().defaultCaptureScope = debug;
            debug.begin();
            parent.model.fractal.draw(parent.model.shaderInputs());
            debug.end();
            parent.model.dirty = false;
        
        }
    }
}

class Model: ObservableObject {
    var fractal = MandelbrotRender();
    // TODO: UB!
    @Published var input = ShaderInputs();
    var delta = float2(0.0, 0.0);
    var dirty = true;
    // Can't just put @Environment on this field because reading it every frame while zooming is really slow.
    var displayScale: CGFloat = 1.0;
    var realSize: CGSize = CGSize(width: 0.0, height: 0.0);
    var mtkView: MTKView?;
    
    // Real unscaled area in pixels.
    var canvasArea: CGRect?;
    
    // TODO: Hack! Need to set the drawableSize on the view (as well as layer) so it's not blurry but that calls the change size method which is what I rely on getting real sizes when you resize the window. Probably need to rearange the view hierarchy so it recreates the whole metal view when the slider changes.
        
    var isFakeResizing = false;
    
    var resolutionScale: Float64 = 1.0;
    
    func scaledDrawSize() -> CGSize {
        let w = max(50.0, self.realSize.width / self.resolutionScale);
        let h = max(50.0, self.realSize.height / self.resolutionScale);
        return CGSize(width: w, height: h);
    }
    
    func windowToCanvas(_ x: Float64, _ y: Float64) -> float2 {
        let s = self.displayScale / self.resolutionScale;
        let new_x = (x - Float64(self.canvasArea!.minX)) * s;
        let new_y = Float64((self.fractal.mtl_layer.drawableSize.height) - (y * s));
        return float2(new_x, new_y);
    }
    
    func windowToCanvas(_ pos: float2) -> float2 {
        return self.windowToCanvas(pos.x, pos.y);
    }
    
    func windowToCanvasVec(_ x: Float64, _ y: Float64) -> float2 {
        let zero = self.windowToCanvas(0, 0);
        let pos = self.windowToCanvas(x, -y);
        return zero - pos;
    }
    
    func shaderInputs() -> RealShaderInputs {
        return RealShaderInputs(
            zoom: df64_t(self.input.zoom),
            c_offset: df64_2(self.input.c_offset),
            steps: self.input.steps,
            colour_count: self.input.colour_count,
            z_initial: df64_2(self.input.z_initial),
            use_doubles: self.input.use_doubles
        );
    }
    
//    func inCanvas(_ pos: float2) -> Bool {
//
//    }
}
