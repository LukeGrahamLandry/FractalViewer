import Metal
import MetalKit
import ScreenSaver

class MandelbrotScreensaver: ScreenSaverView {
    var fractal: MandelbrotRender;
    
    override init?(frame: NSRect, isPreview: Bool) {
        fractal = MandelbrotRender.init();
        super.init(frame: frame, isPreview: isPreview);
        layer = fractal.mtl_layer;
        wantsLayer = true;
    }

    @available(*, unavailable)
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: NSRect) {
        
    }

    override func animateOneFrame() {
        super.animateOneFrame();
        fractal.mtl_layer.drawableSize = bounds.size;
        fractal.draw();
    }
}
