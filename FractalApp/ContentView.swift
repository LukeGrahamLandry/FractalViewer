import SwiftUI
import MetalKit

// https://developer.apple.com/forums/thread/119112
struct MetalView: NSViewRepresentable {
    var model: Model;
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: NSViewRepresentableContext<MetalView>) -> MTKView {
        self.model.mtkView = MTKView();
        self.model.mtkView!.delegate = context.coordinator;
        self.model.mtkView!.preferredFramesPerSecond = 60;  // TODO: this can be 20
        self.model.mtkView!.enableSetNeedsDisplay = true;
        self.model.mtkView!.device = self.model.fractal.device;
        self.model.mtkView!.framebufferOnly = false;
        self.model.mtkView!.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0);
        self.model.mtkView!.drawableSize = self.model.mtkView!.frame.size;
        self.model.mtkView!.isPaused = false;
        self.model.mtkView!.layer = self.model.fractal.mtl_layer;
        return self.model.mtkView!;
    }
    
    init(_ m: Model, _ ds: CGFloat){
        self.model = m;
        // There seem to be multiple instance of the view floating around.
        // You need to store this on the model instead of just using it in the closure.
        model.displayScale = ds;
        
        // Zoom
        NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel]) {
            let zoom_delta = Float64($0.scrollingDeltaY) * 0.0003 * m.fractal.input.zoom * 0.1;
            let old_zoom = m.fractal.input.zoom;
            let new_zoom = min(max(old_zoom + zoom_delta, 1.0), 1_010_000_000_000_000);
            
            // We want the zoom to be centered on the mouse.
            // So calculate the mouse position and then see how much it would move with the new zoom
            // and translate the camera by that much to compensate.
            let s = m.displayScale / m.resolutionScale;
            let mx = Float64($0.locationInWindow.x * s);
            // TODO: make sure this is reading the right size compared to resolutionScale
            let my = Float64(m.fractal.mtl_layer.drawableSize.height - ($0.locationInWindow.y * s))
            let screen_mouse_pos = SIMD2<Float64>(mx, my);
            let c_mouse_offset = screen_mouse_pos / old_zoom;
            let c_new_mouse_offset = screen_mouse_pos / new_zoom;
            m.fractal.input.c_offset += c_mouse_offset - c_new_mouse_offset;
            
            m.dirty = true;
            m.fractal.input.zoom = new_zoom;
            
            return $0
        };
        
        // Drag to move
        NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDragged]) {
            let s = m.displayScale / m.resolutionScale;
            let delta = SIMD2<Float64>(Float64($0.deltaX), Float64($0.deltaY)) * s;
            m.fractal.input.c_offset -= delta / m.fractal.input.zoom;
            m.dirty = true;
            return nil;
        }
        
        // TODO: for z move dont just use scale cause that gets too slow.  
        // Keys to move
        NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) {
            let move_speed = 10.0 / m.fractal.input.zoom;
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
    
    func updateNSView(_ nsView: MTKView, context: NSViewRepresentableContext<MetalView>) {
    }
    
    class Coordinator : NSObject, MTKViewDelegate {
        var parent: MetalView
        
        init(_ parent: MetalView) {
            self.parent = parent
            super.init()
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            self.parent.model.dirty = true;
            // TODO: Hack!
            if !self.parent.model.isFakeResizing {
                // If this size event was sent because we're changing the resolution, don't forget what the real size was.
                let s = self.parent.model.resolutionScale;
                self.parent.model.realSize = CGSize(width: size.width * s, height: size.height * s);
                
                // Changing resolution already set mtl_layer.drawableSize so don't bother.
                self.parent.model.fractal.mtl_layer.drawableSize = self.parent.model.scaledDrawSize();
            }
        }
        
        func draw(in view: MTKView) {
            if parent.model.delta != SIMD2<Float64>(0.0, 0.0) {
                parent.model.fractal.input.z_initial += parent.model.delta;
                parent.model.fractal.input.z_initial = clamp(parent.model.fractal.input.z_initial, min: SIMD2<Float64>(-2, -2), max: SIMD2<Float64>(2, 2));
            } else if !parent.model.dirty {
                // If not moving and haven't zoomed, don't bother rendering this frame.
                return;
            }
            
            let debug = MTLCaptureManager.shared().makeCaptureScope(commandQueue: parent.model.fractal.queue);
            MTLCaptureManager.shared().defaultCaptureScope = debug;
            debug.begin();
            parent.model.fractal.draw();
            debug.end();
            parent.model.dirty = false;
        }
    }
}

class Model: ObservableObject {
    @Published var fractal = MandelbrotRender();
    var delta = SIMD2<Float64>(0.0, 0.0);
    var dirty = true;
    // Can't just put @Environment on this field because reading it every frame while zooming is really slow.
    var displayScale: CGFloat = 1.0;
    var realSize: CGSize = CGSize(width: 0.0, height: 0.0);
    var mtkView: MTKView?
    
    // TODO: Hack! Need to set the drawableSize on the view (as well as layer) so it's not blurry but that calls the change size method which is what I rely on getting real sizes when you resize the window. Probably need to rearange the view hierarchy so it recreates the whole metal view when the slider changes.
        
    var isFakeResizing = false;
    
    // TODO: I don't love the magiclly called function.
    var resolutionScale: Float64 = 1.0 {
        didSet {
            if let view = self.mtkView {
                // Update the canvas size.
                let new_size = self.scaledDrawSize();
                self.isFakeResizing = true;
                view.drawableSize = new_size;
                self.fractal.mtl_layer.drawableSize = new_size;
                self.isFakeResizing = false;
                
                
                // Compensate with zoom so you stay looking at the same area (this fixes translation as well).
                let old_scale = oldValue;
                let new_scale = self.resolutionScale;
                let raw_zoom = self.fractal.input.zoom * old_scale;
                self.fractal.input.zoom = raw_zoom / new_scale;

            }
        }
    }
    
    func scaledDrawSize() -> CGSize {
        let w = max(50.0, self.realSize.width / self.resolutionScale);
        let h = max(50.0, self.realSize.height / self.resolutionScale);
        return CGSize(width: w, height: h);
    }
}
