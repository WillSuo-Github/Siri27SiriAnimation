# Siri27SiriAnimation

用 SwiftUI + Metal 复刻 iOS 27 风格的 Siri 动画，包括两种模式：

- Wave：彩色 Siri 波形
- Fluid Dots：流体融合点阵

动画核心不是用 SwiftUI Path 近似重画，而是把网页版本里的 GLSL shader 逻辑移植到 Metal shader 中，由 `MTKView` 实时渲染。

## Demo

<video src="Media/siri27-siri-animation-demo.mp4" controls width="320"></video>

如果 GitHub 页面没有直接展示视频，可以打开这里查看：[演示视频](Media/siri27-siri-animation-demo.mp4)。

## Implementation

- `Siri27SiriAnimation/SiriShaders.metal`：从 GLSL 移植的两个 fragment shader。
- `Siri27SiriAnimation/SiriMetalView.swift`：SwiftUI 中承载 `MTKView`，管理 Metal pipeline、时间和分辨率 uniform。
- `Siri27SiriAnimation/ContentView.swift`：两个动画模式的 SwiftUI segmented control。

## Requirements

- Xcode 26.5 或更新版本
- iOS 26.5 Simulator 或更新版本
- 支持 Metal 的设备或模拟器

## Run

```bash
open Siri27SiriAnimation.xcodeproj
```

选择 `Siri27SiriAnimation` scheme 后直接运行即可。

## License

MIT
