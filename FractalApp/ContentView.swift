import SwiftUI
import MetalKit

let MAX_ZOOM_LOG2: Int = 50;

// https://developer.apple.com/forums/thread/119112
struct MetalView: NSViewRepresentable {
    var model: Model;
    // TODO: combine these all into a struct since they need to be passed down a bunch of layers. then that's one struct where any update causes the canvas view to be remade. 
    // It seems that setting these fields in the init method is what causes updateNSView to get called.
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
        print("updateNSView window=\(self.canvas.windowArea); res=\(self.canvas.resolutionScale)");
// TODO
//        // Compensate with zoom so you stay looking at the same area.
//        let old_scale = oldResolutionScale / oldDisplayScale;
//        let new_scale = self.resolutionScale / self.displayScale;
//        let raw_zoom = self.model.zoom * old_scale;
//        // This is why zoom can't be @Published
//        self.model.zoom = raw_zoom / new_scale;
        
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
            
            let debug = MTLCaptureManager.shared().makeCaptureScope(commandQueue: parent.model.gpu.queue);
            MTLCaptureManager.shared().defaultCaptureScope = debug;
            debug.begin();
            parent.model.gpu.draw(parent.model.shaderInputs());
            debug.end();
            parent.model.dirty = false;
        
        }
    }
}

class Model: ObservableObject {
    // Zoom is modified in updateNSView so SwiftUI complains if this is @Published but it works without so whatever.
    @Published var zoom: Float64 = 300.0;
    // These needs to be @Published for the config ui to update. Somehow the zoom field still updates
    @Published var c_offset = float2(x: -2.85, y: -1.32);
    @Published var z_initial = float2(x: 0.0, y: 0.0);
    
    var steps = 500;
    var colour_count = 100;
    
    var gpu = MandelbrotRender();
    
    var delta = float2(0.0, 0.0);
    
    // The published fields cause the ui to update. This field causes the frame to redraw.
    var dirty = true;
    
    // TODO: take out the parts that don't apply to the screen saver
    @Published var canvasUpdateCount = 0;
    var eventHandlers: Array<Any?> = [];
    
    // Change the zoom but adjust the translation so it looks like the zoom is centered at an arbitrary point.
    // The chosen window position will corrispond to the same complex position before and after the zoom.
    func zoomCentered(windowX: Float64, windowY: Float64, newZoom: Float64, _ canvas: CanvasModel){
        let oldZoom = self.zoom;
        let center = self.windowToCanvas(windowX, windowY, canvas);
        let c_old_offset = center / oldZoom;
        let c_new_offset = center / newZoom;
        self.c_offset += c_old_offset - c_new_offset;
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
        let new_y = Float64((self.gpu.mtl_layer.drawableSize.height) - (y * s));
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
    
    func addEventListeners(_ canvas: CanvasModel) {
        print("addEventListeners");
        
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
            let zoom_delta_log2 = Float64($0.scrollingDeltaY) * 0.00001 * max(old_zoom_log2, 1.0);
            let new_zoom_raw = pow(2, old_zoom_log2 + zoom_delta_log2)
            let new_zoom = min(max(new_zoom_raw, 1.0), Float64(1 << MAX_ZOOM_LOG2));
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
            self.c_offset += self.windowToCanvasVec($0.deltaX, $0.deltaY, canvas) / self.zoom;
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
    
//    func inCanvas(_ pos: float2) -> Bool {
//
//    }
}
