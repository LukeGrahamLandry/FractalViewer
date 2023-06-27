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
    
    var body: some View {
        NavigationView {
            Group {
                ConfigView(model: model, steps_text: "\(model.input.steps)", wrap_text: "\(model.input.colour_count)", resolutionScale: $resolutionScale)
                PosGetter(model: model, displayScale: self.displayScale, resolutionScale: $resolutionScale)
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
    @Binding var resolutionScale: Float64;
    
    // TODO: toggle between c_offset and z_initial
    var body: some View {
        VStack {
            Group {
                Text("X: \(model.input.c_offset.x)")
                Text("Y: \(model.input.c_offset.y)")
                Text("\(Int(model.input.zoom))x")
                Text("2^\(Int(log2(model.input.zoom)))x")
                Text("10^\(Int(log10(model.input.zoom)))x")
            }
            
            // TODO: wrap these in thier own view? Field can take ParseableFormatStyle to parse numbers?
            // TODO: show explanation of what the numbers do.
            LabeledContent {
                TextField("Steps", text: $steps_text).onSubmit {
                    if let steps = Int32(self.steps_text) {
                        // This is capped at the point where changes stop being visable anyway.
                        // Should go up when I figure out how to zoom farther
                        self.model.input.steps = min(max(steps, 2), 10000);
                        self.model.dirty = true;
                    }
                    self.steps_text = "\(self.model.input.steps)";
                }.frame(width: 50.0)
            } label: {
              Text("Steps")
            }
            LabeledContent {
                TextField("Wrap", text: $wrap_text).onSubmit {
                    if let wrap = Int32(self.wrap_text) {
                        self.model.input.colour_count = min(max(wrap, 2), 10000);
                        self.model.dirty = true;
                    }
                    self.wrap_text = "\(self.model.input.colour_count)";
                }.frame(width: 50.0)
            } label: {
              Text("Wrap")
            }
            
            // TODO: show this position as a little plane
            let zr_binding = Binding(
                get: { "\(self.model.input.z_initial.x)" },
                set: {
                    if let z = Float64($0) {
                        self.model.input.z_initial.x = min(max(z, -2.0), 2.0);
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
                get: { "\(self.model.input.z_initial.y)" },
                set: {
                    if let z = Float64($0) {
                        self.model.input.z_initial.y = min(max(z, -2.0), 2.0);
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
            
            let doubles_binding = Binding(
                get: { self.model.input.use_doubles},
                set: {
                    self.model.input.use_doubles = $0;
                    self.model.dirty = true;
                }
            );
            Group {
                Toggle(isOn: doubles_binding, label: { Text("Use Doubles") })
                Button("Reset", action: {
                    self.model.resolutionScale = 1.0;
                    self.model.input = ShaderInputs();
                    self.model.dirty = true;
                    self.steps_text = "\(model.input.steps)";
                    self.wrap_text = "\(model.input.colour_count)";
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
