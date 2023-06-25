import SwiftUI
import MetalKit

// https://developer.apple.com/forums/thread/119112
struct MetalView: NSViewRepresentable {
    var model: Model;
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: NSViewRepresentableContext<MetalView>) -> MTKView {
        let mtkView = MTKView();
        mtkView.delegate = context.coordinator;
        mtkView.preferredFramesPerSecond = 60;
        mtkView.enableSetNeedsDisplay = true;
        mtkView.device = self.model.fractal.device;
        mtkView.framebufferOnly = false;
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0);
        mtkView.drawableSize = mtkView.frame.size;
        mtkView.enableSetNeedsDisplay = true;
        mtkView.isPaused = false;
        mtkView.presentsWithTransaction = true;
        mtkView.layer = self.model.fractal.mtl_layer;
        return mtkView;
    }
    
    init(_ m: Model){
        self.model = m;
        
        // TODO: have zoom be centered on mouse position even when settings open.
        NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel]) {
            let zoom_delta = Float32($0.scrollingDeltaY) * 0.001 * m.fractal.input.zoom;
            let old_zoom = m.fractal.input.zoom;
            let new_zoom = max(min(old_zoom + zoom_delta, 300000000.0), 1.0);
            
            // We want the zoom to be centered on the mouse.
            // So calculate the mouse position and then see how much it would move with the new zoom
            // and translate the camera by that much to compensate.
            let screen_mouse_pos = float32x2_t(Float($0.locationInWindow.x), Float(m.fractal.mtl_layer.drawableSize.height - $0.locationInWindow.y));
            let c_mouse_offset = screen_mouse_pos / old_zoom;
            let c_new_mouse_offset = screen_mouse_pos / new_zoom;
            m.fractal.input.c_offset += c_mouse_offset - c_new_mouse_offset;
            
            m.dirty = true;
            m.fractal.input.zoom = new_zoom;
            
            return $0
        };
        
        NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) {
            
            return $0
        }
        
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
            self.parent.model.fractal.mtl_layer.drawableSize = size;
        }
        
        func draw(in view: MTKView) {
            if parent.model.delta != float32x2_t(0.0, 0.0) {
                parent.model.fractal.input.c_offset += parent.model.delta;
                parent.model.fractal.input.c_offset = clamp(parent.model.fractal.input.c_offset, min: float32x2_t(-5, -5), max: float32x2_t(5, 5));
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
    var delta = float32x2_t(0.0, 0.0);
    var dirty = true;
}
