import Metal
import MetalKit
import ScreenSaver

class MandelbrotScreensaver: ScreenSaverView {
    var fractal: MandelbrotRender;
    var input = ShaderInputs();
    
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
        fractal.draw(RealShaderInputs(
            zoom: df64_t(input.zoom),
            c_offset: df64_2(input.c_offset),
            steps: input.steps,
            colour_count: input.colour_count,
            z_initial: df64_2(input.z_initial),
            use_doubles: input.use_doubles
        ));
    }
}
