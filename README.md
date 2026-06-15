# Siri27SiriAnimation


https://github.com/user-attachments/assets/e2a01de5-03b2-4bd2-9432-75418db6f9ea




An unofficial recreation of the iOS 27 Siri animation, built with SwiftUI and Metal.

The project includes two animation modes:

- **Wave**: a colorful, layered Siri waveform
- **Fluid Dots**: six animated metaballs that merge, gather, and burst

The effects are not approximated with SwiftUI paths or CPU-rendered shapes. The original GLSL shader logic from the [Siri GLSL demo](https://aaaa-zhen.github.io/siri-glsl/siri-wave.html) was translated to Metal Shading Language and rendered in real time with `MTKView`.

## Implementation

- `Siri27SiriAnimation/SiriShaders.metal` contains the Metal ports of the two fragment shaders.
- `Siri27SiriAnimation/SiriMetalView.swift` manages the Metal render pipelines, animation time, and resolution uniforms.
- `Siri27SiriAnimation/ContentView.swift` provides the SwiftUI interface for switching between animation modes.

## Requirements

- Xcode 26.5 or later
- iOS 26.5 Simulator or later
- A device or simulator with Metal support

## Running the Project

```bash
open Siri27SiriAnimation.xcodeproj
```

Select the `Siri27SiriAnimation` scheme and run the app.

## Disclaimer

This is an independent educational project and is not affiliated with or endorsed by Apple Inc. Siri and iOS are trademarks of Apple Inc.

## License

Released under the MIT License.
