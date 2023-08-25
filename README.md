# Fractal Viewer (MacOS)

An app for exploring fractals in real time. 

- Mandelbrot
- Julia
- Newton (cubics only)

Metal only supports 32 bit floats. Code for getting higher precision with pairs of floats (float_float.h) is from Andrew Thall's paper [Extended-Precision Floating-Point Numbers for GPU Computation](https://andrewthall.org/papers/df64_qf128.pdf). Much credit to them for making this extra cool!

- [Demo (youtube)](https://youtu.be/Zdf4CTQF6i8)

[![Demo Video](https://img.youtube.com/vi/Zdf4CTQF6i8/0.jpg)](https://youtu.be/Zdf4CTQF6i8 "Demo")

> ^ Quality reduced because the file's big and I'm impatient. Chaotic fractals don't compress well!

## Try it

[**Download (github releases)**](https://github.com/LukeGrahamLandry/FractalViewer/releases/latest)  

Apple will probably warn you it might be dangerous because I don't pay them thier $100/year. You can also build it from source instead: 

Install the XCode Command Line Tools, download my code, and run `xcodebuild build` in the project folder. The built program will be at `build/Release/FractalApp` and you can just run it. 

## Controls

Scroll to zoom (mice that give you momentum are fun). Click and drag to move around. 

Zoom in on a point in mandelbrot mode, then switch to julia to get the corrisponding set. When you zoom out, the whole thing will be visually similar to that point on the mandelbrot set. 

## Things to fix

- Adaptive fps/resolution. It's a bit laggy when you're super zoomed in on a black section.
- Cheat to do less work. 
    - Scale last frame when zooming, so you only render every other frame or whatever. 
    - Translate instead of re-rendering whem moving around. 
- Change coordinate system to be based on the center of the view port and adjust to keep the same area in view as you resize the window. 
- When showing Julia set, show mandelbrot image in C-coord UI so you can see where you are. 
- Fix zoom & repositioning when toggling back from newton. 
- Clean up newton (currently there's some lazy copy-pasting). Or just give up because it doesn't look as cool anyway. 
- Would be cool to let you type in any equation to make a newton fractal (can compile MSL at runtime). 
- Figure out how to run tests in xcode reliably. 
- Animate colours. 
- Save a zoom path and select it as a screen saver. 
- Better error messages if it fails to setup metal on an old computer. 
