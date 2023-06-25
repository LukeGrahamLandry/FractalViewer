//
//  FractalAppApp.swift
//  FractalApp
//
//  Created by Luke Graham Landry on 2023-06-23.
//

import SwiftUI

@main
struct FractalAppApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
        
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// TODO: this feels hacky
struct ContentView: View {
    var model = Model();
    @ObservedObject var show = M();
    // The view automatically reruns when this changes.
    @Environment(\.displayScale) var displayScale: CGFloat;
    
    var body: some View {
        if self.show.show_ui {
            MetalView(model, self.displayScale).overlay(ConfigView(model), alignment: .topLeading)
        } else {
            MetalView(model, self.displayScale)
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

struct ConfigView: View {
    @ObservedObject var model: Model;
    @State private var steps_text: String;
    @State private var wrap_text: String;
    
    init(_ model: Model) {
        self.model = model;
        self.steps_text = "\(model.fractal.input.steps)";
        self.wrap_text = "\(model.fractal.input.colour_count)";
    }
    
    var body: some View {
        VStack {
            Text("X: \(model.fractal.input.c_offset.x)")
            Text("Y: \(model.fractal.input.c_offset.y)")
            Text("\(Int(model.fractal.input.zoom))x")
            
            // TODO: wrap these in thier own view? Field can take ParseableFormatStyle to parse numbers?
            // TODO: show explanation of what the numbers do.
            LabeledContent {
                TextField("Steps", text: $steps_text).onSubmit {
                    if let steps = Int32(self.steps_text) {
                        // This is capped at the point where changes stop being visable anyway.
                        // Should go up when I figure out how to zoom farther
                        self.model.fractal.input.steps = min(max(steps, 2), 10000);
                        self.model.dirty = true;
                    }
                    self.steps_text = "\(self.model.fractal.input.steps)";
                }.frame(width: 50.0)
            } label: {
              Text("Steps")
            }
            LabeledContent {
                TextField("Wrap", text: $wrap_text).onSubmit {
                    if let wrap = Int32(self.wrap_text) {
                        self.model.fractal.input.colour_count = min(max(wrap, 2), 10000);
                        self.model.dirty = true;
                    }
                    self.wrap_text = "\(self.model.fractal.input.colour_count)";
                }.frame(width: 50.0)
            } label: {
              Text("Wrap")
            }
            
            let zr_binding = Binding(
                get: { "\(self.model.fractal.input.z_initial.x)" },
                set: {
                    if let z = Float($0) {
                        self.model.fractal.input.z_initial.x = min(max(z, -2.0), 2.0);
                        self.model.dirty = true;
                    }
                }
            );
            
            LabeledContent {
                TextField("Z_r", text: zr_binding).frame(width: 100.0)
            } label: {
              Text("Z_r")
            }
            let zi_binding = Binding(
                get: { "\(self.model.fractal.input.z_initial.y)" },
                set: {
                    if let z = Float($0) {
                        self.model.fractal.input.z_initial.y = min(max(z, -2.0), 2.0);
                        self.model.dirty = true;
                    }
                }
            );
            LabeledContent {
                TextField("Z_i", text: zi_binding).frame(width: 100.0)
            } label: {
              Text("Z_i")
            }
        }.foregroundColor(.black).background(Color.white.opacity(0.6))
    }
}

class M: ObservableObject {
    @Published var show_ui = false;
}

// https://stackoverflow.com/questions/65743619/close-swiftui-application-when-last-window-is-closed
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
