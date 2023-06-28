import SwiftUI

// TODO: Figure out how much xcode junk I can gitignore. 
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

// TODO: animate colour offset

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

// TODO: save waypoints and another tab for showing a list of them. these can be selected as screen savers 
struct ConfigView: View {
    @ObservedObject var model: Model;
    @State var steps_text: String;
    @State var wrap_text: String;
    // These is watched by the MetalView.
    @Binding var resolutionScale: Float64;  // TODO: option to reduce while moving 
    @Binding var fps: Int;
    @State var hack = false;
    
    // TODO: toggle between c_offset and z_initial
    // TODO: option to apply momentum (for if you dont have free spinning mouse)
    // TODO: rotation (a pain because I'd want it around the center point)
    var body: some View {
        VStack {
            Group {
                // TODO: directly edit these in the ui
                Text("X: \(model.c_offset.x)")
                Text("Y: \(model.c_offset.y)")
                
                // TODO: these dont update when you use the slider because zoom isn't @Published
                Text("\(Int(model.zoom))x")
                Text("2^\(Int(log2(model.zoom)))x")
                Text("10^\(Int(log10(model.zoom)))x")
                
                let zs_binding = Binding(
                    get: { log2(self.model.zoom) },
                    set: {
                        let x = self.model.canvasArea!.minX + (self.model.canvasArea!.width / 2);
                        let y = self.model.canvasArea!.minY + (self.model.canvasArea!.height / 2);
                        self.model.zoomCentered(windowX: x, windowY: y, newZoom: pow(2, $0));
                    }
                );
                let max_zoom = Float64(MAX_ZOOM_LOG2);
                MyLabeledContent {
                    Slider(value: zs_binding, in: 1...max_zoom).frame(width: 90.0)
                } label: {
                  Text("Zoom")
                }
            }
            
            // TODO: wrap these in thier own view? Field can take ParseableFormatStyle to parse numbers?
            // TODO: show explanation of what the numbers do.
            
            // This needs go higher as I allow more precision but it's practically limited by render time.
            // If I don't set a cap, you can hang the gpu (and crash the app) by setting it high on a black screen.
            let maxSteps = 20000;
            MyLabeledContent {
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
            MyLabeledContent {
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
            
            let min_res = 1.0;
            let max_res = 5.0;
            let resolution_binding = Binding(
                get: { max_res - self.resolutionScale + min_res},
                set: {
                    self.resolutionScale = max_res - $0 + min_res;
                    self.model.dirty = true;
                }
            );
            MyLabeledContent {
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
            MyLabeledContent {
                Slider(value: fps_binding, in: 5.0...60.0).frame(width: 100.0)
            } label: {
              Text("FPS")
            }
            
            // TODO: slider for when to switch to float
            Group {
                if self.model.usingDoubles() {
                    Text("Precision: float-float")
                } else {
                    Text("Precision: float")
                }
                
                let z_binding = Binding(
                    get: { self.model.z_initial },
                    set: {
                        self.model.z_initial = $0;
                        self.model.dirty = true;
                    }
                );
                let z_max = 2.00;
                SliderPlane(length: 100, value: z_binding, minVal: float2(-z_max, -z_max), maxVal: float2(z_max, z_max), label: "Z Offset")
                
                // TODO: show frame time somehow so you can see how hard it's working. graph?
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

func MyLabeledContent<Label: View, Content: View>(
    @ViewBuilder content: () -> Content,
    @ViewBuilder label: () -> Label
) -> some View {
    // Was going to use `if #available(macOS 13.0, *) { return LabeledContent(content: content, label: label); } else... `
    // But this looks the same so why bother.
    return HStack {
        label()
        content()
    };
}

struct SliderPlane: View {
    var length: CGFloat;
    @Binding var value: float2;
    var minVal: float2;
    var maxVal: float2;
    var label: String
    
    // TODO: make this collapsable cause they take up a lot of space
    // TODO: allow background image of the set?
    var body: some View {
        VStack {
            Divider()
            Text(self.label)
            GeometryReader { geo -> SliderPlaneInner in
                SliderPlaneInner(length: length, value: $value, geo: geo, minVal: minVal, maxVal: maxVal)
            }.frame(width: 100.0, height: 100.0)
            
            // TODO: Trying to edit these is really annoying because it clamps to the range after every character you type.
            //       I need to have another field to hold the string and just highligh red or something if not valid.
            //       Use onSubmit to update the real binding.
            MyLabeledContent {
                TextField("X", text: Binding(
                    get: { "\(self.value.x)" },
                    set: {
                        if let val = Float64($0) {
                            self.value.x = min(max(val, minVal.x), maxVal.x);
                        }
                    }
                )).frame(width: 85.0)
            } label: {
              Text("X")
            }
            
            MyLabeledContent {
                TextField("Y", text: Binding(
                    get: { "\(self.value.y)" },
                    set: {
                        if let val = Float64($0) {
                            self.value.y = min(max(val, minVal.y), maxVal.y);
                        }
                    }
                )).frame(width: 85.0)
            } label: {
              Text("Y")
            }
            Divider()
        }
    }
}


struct SliderPlaneInner: View {
    var length: CGFloat;
    @Binding var value: float2;
    var geo: GeometryProxy;
    var minVal: float2;
    var maxVal: float2;
    
    var body: some View {
        let rect = geo.frame(in: .local);
        let range = self.maxVal - self.minVal;
        let val = (self.value - self.minVal) / range;
        let x = rect.minX + (geo.size.width * val.x);
        let y = rect.minY + (geo.size.height * val.y);
        
        VStack {
            ZStack {
                Rectangle()
                    .fill(.gray)
                Circle()
                    .fill(.black)
                    .frame(width: 5, height: 5)
                    .position(x: x, y: y)
            }
        }
        
        // TODO: this isnt sensitive enough
        .gesture(DragGesture()
                    .onChanged({ pos in
                        let x_scale = (rect.minX - pos.location.x) / geo.size.width;
                        let y_scale = (rect.minY - pos.location.y) / geo.size.height;
                        let range = self.maxVal - self.minVal;
                        let val = float2(min(max(Float64(-x_scale), 0.0), 1.0), min(max(Float64(-y_scale), 0.0), 1.0)) * range;
                        self.value = self.minVal + val;
                    })
        )
    }
}
