import SwiftUI

typealias float2 = SIMD2<Float64>;

@main
struct FractalAppApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
        
    var body: some Scene {
        WindowGroup {
            ContentView()
        }.commands {
            SidebarCommands()
        }
    }
}

// TODO: this feels hacky
struct ContentView: View {
    var model = Model();
    // The view automatically reruns when this changes.
    @Environment(\.displayScale) var displayScale: CGFloat;
    @State private var resolutionScale: Float64 = 1.0;
    @State private var fps = 30;
    
    var body: some View {
        NavigationView {
            Group {
                ConfigView(model: model, steps_text: "\(model.steps)", wrap_text: "\(model.colour_count)", resolutionScale: $resolutionScale, fps: $fps)
                PosGetter(model: model, displayScale: self.displayScale, resolutionScale: $resolutionScale, fps: $fps)
            }
        } 
    }
    
    init() {
        let m = self.model;
        NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) {
            switch ($0.keyCode){
            case 14:   // e
                NSApp.sendAction(#selector(NSSplitViewController.toggleSidebar(_:)), to: nil, from: nil)
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
    @State var steps_text: String;
    @State var wrap_text: String;
    // These is watched by the MetalView.
    @Binding var resolutionScale: Float64;  // TODO: option to reduce while moving 
    @Binding var fps: Int;
    
    // TODO: toggle between c_offset and z_initial
    var body: some View {
        VStack {
            Group {
                // TODO: directly edit these in the ui
                Text("X: \(model.c_offset.x)")
                Text("Y: \(model.c_offset.y)")
                Text("\(Int(model.zoom))x")
                Text("2^\(Int(log2(model.zoom)))x")
                Text("10^\(Int(log10(model.zoom)))x")
            }
            
            // TODO: wrap these in thier own view? Field can take ParseableFormatStyle to parse numbers?
            // TODO: show explanation of what the numbers do.
            let maxSteps = 10000;
            LabeledContent {
                TextField("Steps", text: $steps_text).onSubmit {
                    if let steps = Int(self.steps_text) {
                        // This is capped at the point where changes stop being visable anyway.
                        // Should go up when I figure out how to zoom farther
                        self.model.steps = min(max(steps, 2), maxSteps);
                        self.model.dirty = true;
                    }
                    self.steps_text = "\(self.model.steps)";
                }.frame(width: 50.0)
            } label: {
              Text("Steps")
            }
            LabeledContent {
                TextField("Wrap", text: $wrap_text).onSubmit {
                    if let wrap = Int(self.wrap_text) {
                        self.model.colour_count = min(max(wrap, 2), maxSteps);
                        self.model.dirty = true;
                    }
                    self.wrap_text = "\(self.model.colour_count)";
                }.frame(width: 50.0)
            } label: {
              Text("Wrap")
            }
            
            // TODO: show this position as a little plane
            let zr_binding = Binding(
                get: { "\(self.model.z_initial.x)" },
                set: {
                    if let z = Float64($0) {
                        self.model.z_initial.x = min(max(z, -2.0), 2.0);
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
                get: { "\(self.model.z_initial.y)" },
                set: {
                    if let z = Float64($0) {
                        self.model.z_initial.y = min(max(z, -2.0), 2.0);
                        self.model.dirty = true;
                    }
                }
            );
            LabeledContent {
                TextField("Z_i", text: zi_binding).frame(width: 100.0)
            } label: {
              Text("Z_i")
            }
            
            let min_res = 1.0;
            let max_res = 5.0;
            let resolution_binding = Binding(
                get: { max_res - self.resolutionScale + min_res},
                set: {
                    self.resolutionScale = max_res - $0 + min_res;
                    self.model.dirty = true;
                }
            );
            LabeledContent {
                Slider(value: resolution_binding, in: min_res...max_res).frame(width: 100.0)
            } label: {
              Text("Res")
            }
            let size = self.model.scaledDrawSize();
            Text("\(Int(size.width))x\(Int(size.height)) px.")
            
            let fps_binding = Binding(
                get: { Float64(self.fps) },
                set: {
                    self.fps = Int($0);
                }
            );
            LabeledContent {
                Slider(value: fps_binding, in: 5.0...60.0).frame(width: 100.0)
            } label: {
              Text("FPS")
            }
            // TODO: show frame time somehow so you can see how hard it's working 
            
            if self.model.usingDoubles() {
                Text("Precision: float-float")
            } else {
                Text("Precision: float")
            }
            
            Group {
                Button("Reset", action: {
                    // TODO: you need to press the button twice if you changed the resolution
                    self.model.setDefaults();
                    self.steps_text = "\(model.steps)";
                    self.wrap_text = "\(model.colour_count)";
                    self.fps = 30;
                    self.resolutionScale = 1.0;
                }).background(Color.gray)
                
            }
        }.foregroundColor(.white)
    }
}

// https://stackoverflow.com/questions/65743619/close-swiftui-application-when-last-window-is-closed
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
