# Learning SwiftUI + Metal

# Sat June 24

## @Environment displaySize 

- https://developer.apple.com/documentation/swiftui/environmentvalues

Magic annotation on a field that lets it read from the environment value. 
Putting it on a view struct makes it automaticlly update when the value changes like @State. 

# Fri June 23

## Kill the app when window closes

- https://stackoverflow.com/questions/65743619/close-swiftui-application-when-last-window-is-closed

## Text fields

- https://sarunw.com/posts/textfield-in-swiftui/
- https://stackoverflow.com/questions/58776561/add-label-to-swiftui-textfield
- https://stackoverflow.com/questions/59507471/use-bindingint-with-a-textfield-swiftui

## @State view fields

- https://www.hackingwithswift.com/quick-start/swiftui/how-to-use-observedobject-to-manage-state-from-external-objects
- https://www.avanderlee.com/swiftui/stateobject-observedobject-differences/
- https://www.hackingwithswift.com/quick-start/swiftui/what-is-the-stateobject-property-wrapper
- https://developer.apple.com/documentation/swiftui/stateobject

Various magic annotations to rerun the view when a model value changes. 

## Overlay view above another

- https://www.simpleswiftguide.com/how-to-add-text-overlay-on-image-in-swiftui/

There's just a .overlay builder method. Also ZStack if you want multiple. 

## Using the shader debugger

- https://developer.apple.com/documentation/xcode/creating-and-using-custom-capture-scopes
- https://developer.apple.com/documentation/metal/developing_and_debugging_metal_shaders

Call a function on a capture scope to mark the start and end of your rendering. 
Then there's a little camera icon in the debug window. 

## Escaping closures

- https://forums.swift.org/t/how-to-fix-error-escaping-closure-captures-mutating-self-parameter-in-init/29870/5
- https://docs.swift.org/swift-book/documentation/the-swift-programming-language/classesandstructures/
- https://docs.swift.org/swift-book/documentation/the-swift-programming-language/closures
- https://www.swiftbysundell.com/articles/mutating-and-nonmutating-swift-contexts/

Structs are value types. Closures marked as @Escaping (which the event callbacks are) can't capture a mutable reference. Makes sense, what would that even mean, it's like a rust type being Copy. You can have a field on the struct that's a class (which are automaticlly reference counted) and save that in a local variable that closures can capture. 

## Lower level event listeners

- https://stackoverflow.com/questions/1918841/how-to-convert-ascii-character-to-cgkeycode
- https://developer.apple.com/forums/thread/678661
- https://developer.apple.com/documentation/appkit/nsevent/1534971-addlocalmonitorforevents

NSEvent.addLocalMonitorForEvents lets you set callbacks for different event types and it just gives you a tagged union with details. 
Returning nil lets marks the event as handled. Didn't find the keyCode constants yet.

# Rendering a SwiftUI view with Metal

- https://developer.apple.com/forums/thread/119112
- https://medium.com/@warrenm/thirty-days-of-metal-day-4-mtkview-1e64ce5cd2ae
- https://developer.apple.com/documentation/swiftui/uiviewrepresentable
- https://developer.apple.com/documentation/metal/onscreen_presentation/creating_a_custom_metal_view
- https://developer.apple.com/documentation/metal/using_metal_to_draw_a_view_s_contents

Extending UIViewRepresentable gives you a function to return a MTKView and attatch 
a struct extending MTKViewDelegate which gives you a callback to draw each frame. 

There's also a resize callback that needs to set the layer's drawableSize, otherwise it just squishes the image to fit. 

# Thu June 22

## Run fragment shader runs for every pixel

- https://www.saschawillems.de/blog/2016/08/13/vulkan-tutorial-on-rendering-a-fullscreen-quad-without-buffers/

`{ float4(2 * (float) ((vid << 1) & 2) - 1, 2 * (float) (vid & 2) - 1, 0, 1) }`

Bit magic that makes a big triangle that covers the screen. 
Without dealing with a buffer for sending vertex positions to the gpu. 

## How to make a screen saver with metal 

- https://betterprogramming.pub/how-to-make-a-custom-screensaver-for-mac-os-x-7e1650c13bd8
- https://www.reddit.com/r/swift/comments/un88in/making_a_macos_screen_saver_with_swift/
- https://developer.apple.com/documentation/screensaver
- https://github.com/nickzman/rainingcubes
- https://github.com/edmonston/hello-triangle-swift/blob/master/HelloTriangleSwift/MetalViewController.swift

Debugging's really annoying becasue you can't run it from xcode, so wrapping the logic in an app as well seems smart. 
