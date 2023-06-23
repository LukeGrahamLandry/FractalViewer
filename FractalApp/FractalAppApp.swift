//
//  FractalAppApp.swift
//  FractalApp
//
//  Created by Luke Graham Landry on 2023-06-23.
//

import SwiftUI

@main
struct FractalAppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
    
    init() {
        
    }
}

// TODO: this feels hacky
struct ContentView: View {
    var model = Model();
    @ObservedObject var show = M();
    
    var body: some View {
        if self.show.show_ui {
            HStack {
                TextView(model)
                MetalView(model)
            }
        } else {
            MetalView(model)
        }
    }
    
    init() {
        let s = self.show;
        let m = self.model;
        NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) {
            switch ($0.keyCode){
            case 14:   // e
                s.show_ui = !s.show_ui;
                m.dirty = true;
            default:
                return $0;
            }
            return nil;
        };
    }
}

struct TextView: View {
    @ObservedObject var model: Model;
    
    init(_ model: Model) {
        self.model = model
    }
    
    var body: some View {
        Text("X: \(model.fractal.input.c_offset.x)\nY: \(model.fractal.input.c_offset.y)\n\(Int(model.fractal.input.t))x  \n i: \(Int(model.fractal.frame_index))").foregroundColor(.black)
    }
}

class M: ObservableObject {
    @Published var show_ui = false;
}
