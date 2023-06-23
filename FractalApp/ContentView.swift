//
//  ContentView.swift
//  FractalApp
//
//  Created by Luke Graham Landry on 2023-06-23.
//

import SwiftUI
import MetalKit

// https://developer.apple.com/forums/thread/119112
struct MetalView: NSViewRepresentable {
    @ObservedObject var model = Model();
    
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
    
    init(){
        let m = self.model;
        NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel]) {
            m.fractal.frame_index += Float32($0.scrollingDeltaY);
            if m.fractal.frame_index < 0.0 {
                m.fractal.frame_index = 0.0;
            }
            print(m.fractal.frame_index);
            return $0
        };
        NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) {
            // https://stackoverflow.com/questions/1918841/how-to-convert-ascii-character-to-cgkeycode
            // TODO: theres no way this is what you're supposed to do
            let delta = 10.0 / m.fractal.input.t;
            switch ($0.keyCode){
            case 0:   // a
                m.fractal.input.c_offset.x -= delta;
            case 1:   // s
                m.fractal.input.c_offset.y += delta;
            case 2:   // d
                m.fractal.input.c_offset.x += delta;
            case 13:   // w
                m.fractal.input.c_offset.y -= delta;
            default:
                break;
            }
            return $0
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
        }
        func draw(in view: MTKView) {
            view.layer = parent.model.fractal.mtl_layer;
            parent.model.fractal.draw();
        }
    }
}

class Model: ObservableObject {
    var fractal = MandelbrotRender();
}
