import MetalKit
import SwiftUI

enum SiriAnimationMode: String, CaseIterable, Identifiable {
    case wave
    case fluidDots

    var id: Self { self }

    var title: String {
        switch self {
        case .wave:
            "Wave"
        case .fluidDots:
            "Fluid Dots"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .wave:
            "Siri wave animation"
        case .fluidDots:
            "Siri fluid dots animation"
        }
    }
}

struct SiriMetalView: UIViewRepresentable {
    var mode: SiriAnimationMode

    func makeCoordinator() -> SiriRenderer {
        SiriRenderer(mode: mode)
    }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: context.coordinator.device)
        view.delegate = context.coordinator
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        view.framebufferOnly = true
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        view.preferredFramesPerSecond = 60
        view.autoResizeDrawable = true
        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.mode = mode
    }
}

private struct SiriShaderUniforms {
    var iResolution: SIMD2<Float>
    var iTime: Float
    var padding: Float = 0
}

final class SiriRenderer: NSObject, MTKViewDelegate {
    let device: MTLDevice

    var mode: SiriAnimationMode

    private let commandQueue: MTLCommandQueue
    private let wavePipeline: MTLRenderPipelineState
    private let fluidDotsPipeline: MTLRenderPipelineState
    private let startTime = CACurrentMediaTime()

    init(mode: SiriAnimationMode) {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not available on this device.")
        }
        guard let commandQueue = device.makeCommandQueue() else {
            fatalError("Could not create a Metal command queue.")
        }
        guard let library = try? device.makeDefaultLibrary(bundle: .main) else {
            fatalError("Could not load the default Metal library.")
        }

        self.device = device
        self.mode = mode
        self.commandQueue = commandQueue
        self.wavePipeline = Self.makePipeline(
            device: device,
            library: library,
            fragmentName: "siriWaveFragment"
        )
        self.fluidDotsPipeline = Self.makePipeline(
            device: device,
            library: library,
            fragmentName: "siriFluidDotsFragment"
        )

        super.init()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard
            let drawable = view.currentDrawable,
            let renderPassDescriptor = view.currentRenderPassDescriptor,
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        else {
            return
        }

        var uniforms = SiriShaderUniforms(
            iResolution: SIMD2(Float(view.drawableSize.width), Float(view.drawableSize.height)),
            iTime: Float(CACurrentMediaTime() - startTime)
        )

        commandEncoder.setRenderPipelineState(pipeline(for: mode))
        commandEncoder.setFragmentBytes(
            &uniforms,
            length: MemoryLayout<SiriShaderUniforms>.stride,
            index: 0
        )
        commandEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        commandEncoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func pipeline(for mode: SiriAnimationMode) -> MTLRenderPipelineState {
        switch mode {
        case .wave:
            wavePipeline
        case .fluidDots:
            fluidDotsPipeline
        }
    }

    private static func makePipeline(
        device: MTLDevice,
        library: MTLLibrary,
        fragmentName: String
    ) -> MTLRenderPipelineState {
        guard
            let vertexFunction = library.makeFunction(name: "siriFullscreenVertex"),
            let fragmentFunction = library.makeFunction(name: fragmentName)
        else {
            fatalError("Could not find Metal shader function \(fragmentName).")
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        do {
            return try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            fatalError("Could not create Metal pipeline \(fragmentName): \(error)")
        }
    }
}
