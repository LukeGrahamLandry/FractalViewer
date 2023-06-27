import SwiftUI
import MetalKit

struct PosGetter: View {
    var model: Model;
    var displayScale: CGFloat;
    @Binding var resolutionScale: Float64;
    @Binding var fps: Int;
    
    var body: some View {
        GeometryReader { geo ->MetalView in
            MetalView(self.model, self.displayScale, geo, self.resolutionScale, self.fps)
        }
    }
}

let MAX_ZOOM_LOG2: Int = 50;

// https://developer.apple.com/forums/thread/119112
struct MetalView: NSViewRepresentable {
    var model: Model;
    // TODO: combine these all into a struct since they need to be passed down a bunch of layers. then that's one struct where any update causes the canvas view to be remade. 
    // It seems that setting these fields in the init method is what causes updateNSView to get called.
    var resolutionScale: Float64;
    var realSize: CGSize;
    var displayScale: CGFloat;
    var fps = 30;
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // This only gets called the first time the view is made.
    func makeNSView(context: NSViewRepresentableContext<MetalView>) -> MTKView {
        let mtkView = MTKView();
        mtkView.delegate = context.coordinator;
        mtkView.preferredFramesPerSecond = self.fps;
        mtkView.enableSetNeedsDisplay = true;
        mtkView.device = self.model.fractal.device;
        mtkView.framebufferOnly = false;
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0);
        mtkView.isPaused = false;
        mtkView.layer = self.model.fractal.mtl_layer;
        return mtkView;
    }
    
    // This gets called when an @State change triggers a view update.
    func updateNSView(_ nsView: MTKView, context: NSViewRepresentableContext<MetalView>) {
        // Compensate with zoom so you stay looking at the same area.
        let old_scale = self.model.resolutionScale / self.model.displayScale;
        let new_scale = self.resolutionScale / self.displayScale;
        let raw_zoom = self.model.zoom * old_scale;
        // This is why zoom can't be @Published
        self.model.zoom = raw_zoom / new_scale;
        
        // Save values on the model so we can get the old ones next frame. 
        self.model.resolutionScale = self.resolutionScale;
        self.model.displayScale = self.displayScale;
        
        // Update the fake canvas sizes.
        self.model.fractal.mtl_layer.drawableSize = self.model.scaledDrawSize();
        nsView.drawableSize = self.model.scaledDrawSize();
        nsView.preferredFramesPerSecond = self.fps;
        self.model.dirty = true;
    }
    
    init(_ m: Model, _ ds: CGFloat, _ geo: GeometryProxy, _ resolutionScale: Float64, _ fps: Int){
        self.model = m;
        self.resolutionScale = resolutionScale;
        self.model.canvasArea = geo.frame(in: .global);
        self.realSize = geo.size;
        self.displayScale = ds;
        self.fps = fps;
        
        // Zoom
        // TODO: this needs to be framerate independant
        NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel]) {
            let old_zoom_log2 = log2(m.zoom);
            let zoom_delta_log2 = Float64($0.scrollingDeltaY) * 0.000001 * max(old_zoom_log2, 1.0);
            let new_zoom_raw = pow(2, old_zoom_log2 + zoom_delta_log2)
            let new_zoom = min(max(new_zoom_raw, 1.0), Float64(1 << MAX_ZOOM_LOG2));
            m.zoomCentered(windowX: $0.locationInWindow.x, windowY: $0.locationInWindow.y, newZoom: new_zoom);
            return $0
        };
        
        // Drag to move
        NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDragged]) {
            let mousePos = m.windowToCanvas($0.locationInWindow.x, $0.locationInWindow.y);
            
            // TODO: this needs to know about scale so it doesnt think you're moving when dragging the window between monitors. 
            if m.canvasArea != nil && (!m.canvasArea!.contains($0.locationInWindow) || mousePos.y < 0) {
                return $0;
            }
            m.c_offset += m.windowToCanvasVec($0.deltaX, $0.deltaY) / m.zoom;
            m.dirty = true;
            return nil;
        }
        
        // TODO: for z move dont just use scale cause that gets too slow.  
        // Keys to move
        NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) {
            let move_speed = 10.0 / m.zoom;
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
    // Zoom is modified in updateNSView so SwiftUI complains if this is @Published but it works without so whatever.
    var zoom: Float64 = 300.0;
    // These needs to be @Published for the config ui to update. Somehow the zoom field still updates
    @Published var c_offset = float2(x: -2.85, y: -1.32);
    @Published var z_initial = float2(x: 0.0, y: 0.0);
    
    var steps = 500;
    var colour_count = 100;
    
    var fractal = MandelbrotRender();
    
    var delta = float2(0.0, 0.0);
    var dirty = true;
    
    // This comes from the monitor settings.
    // Can't just put @Environment on this field because reading it every frame while zooming is really slow.
    var displayScale: CGFloat = 1.0;
    
    // Real unscaled area in pixels. This also tells you which part of the window is the view.
    var canvasArea: CGRect?;
    
    // This is the value controlled by the slider so you can adjust performace.
    var resolutionScale: Float64 = 1.0;
    
    // Change the zoom but adjust the translation so it looks like the zoom is centered at an arbitrary point.
    // The chosen window position will corrispond to the same complex position before and after the zoom.
    func zoomCentered(windowX: Float64, windowY: Float64, newZoom: Float64){
        let oldZoom = self.zoom;
        let center = self.windowToCanvas(windowX, windowY);
        let c_old_offset = center / oldZoom;
        let c_new_offset = center / newZoom;
        self.c_offset += c_old_offset - c_new_offset;
        self.dirty = true;
        self.zoom = newZoom;
    }
    
    func scaledDrawSize() -> CGSize {
        if let area = self.canvasArea {
            let size = area.size;
            // TODO: maintain aspect ratio when clamping.
            let w = max(50.0, size.width / self.resolutionScale * self.displayScale);
            let h = max(50.0, size.height / self.resolutionScale * self.displayScale);
            return CGSize(width: w, height: h);
        }
        
        // This happens the first frame when nothing's been set yet but it gets the right size immediately after.
        return CGSize(width: 0, height: 0);
    }
    
    func windowToCanvas(_ x: Float64, _ y: Float64) -> float2 {
        let s = 1.0 / self.resolutionScale * self.displayScale;
        let new_x = (x - Float64(self.canvasArea!.minX)) * s;
        // TODO: need to use minY somehow if I ever make it not take up full window height
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
            zoom: df64_t(self.zoom),
            c_offset: df64_2(self.c_offset),
            steps: Int32(self.steps),
            colour_count: Int32(self.colour_count),
            z_initial: df64_2(self.z_initial),
            use_doubles: self.usingDoubles()
        );
    }
    
    // TODO: drop down to force one that defaults to auto. 
    func usingDoubles() -> Bool {
        return Int(self.zoom) > (1 << 22);
    }
    
    func setDefaults(){
        self.zoom = 300.0;
        self.c_offset = float2(x: -2.85, y: -1.32);
        self.z_initial = float2(x: 0.0, y: 0.0);
        self.steps = 500;
        self.colour_count = 100;
        self.dirty = true;
        
    }
    
//    func inCanvas(_ pos: float2) -> Bool {
//
//    }
}
