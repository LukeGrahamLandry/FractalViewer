import SwiftUI
import MetalKit

// https://developer.apple.com/forums/thread/119112
struct MetalView: NSViewRepresentable {
    var model: Model;
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: NSViewRepresentableContext<MetalView>) -> MTKView {
        let mtkView = MTKView()
        mtkView.delegate = context.coordinator
        mtkView.preferredFramesPerSecond = 60
        mtkView.enableSetNeedsDisplay = true
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            mtkView.device = metalDevice
        }
        mtkView.framebufferOnly = false
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        mtkView.drawableSize = mtkView.frame.size
        mtkView.enableSetNeedsDisplay = true
        mtkView.isPaused = false;
        return mtkView
    }
    
    init(_ m: Model){
        self.model = m;
        
        // TODO: have zoom be centered on mouse position.
        NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel]) {
            // TODO: move time based zoom to screen saver and directly modify inputs.t instead of setting it every frame.
            m.fractal.frame_index -= Float32($0.scrollingDeltaY) * 0.15;
            m.fractal.frame_index = max(min(m.fractal.frame_index, 25000.0), 5.0);
            m.dirty = true;
            
            return $0
        };
        
        NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) {
            let move_speed = 10.0 / m.fractal.input.t;
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
            // I don't care about this but the protocol needs it.
        }
        
        func draw(in view: MTKView) {
            if parent.model.delta != float32x2_t(0.0, 0.0) {
                parent.model.fractal.input.c_offset += parent.model.delta;
                parent.model.fractal.input.c_offset = clamp(parent.model.fractal.input.c_offset, min: float32x2_t(-5, -5), max: float32x2_t(5, 5));
            } else if !parent.model.dirty {
                // If not moving and haven't zoomed, don't bother rendering this frame.
                return;
            }
            
            view.layer = parent.model.fractal.mtl_layer;
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
