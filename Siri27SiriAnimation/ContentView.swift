import SwiftUI

struct ContentView: View {
    @State private var selectedMode: SiriAnimationMode = .wave

    var body: some View {
        ZStack {
            Color(red: 0.039, green: 0.039, blue: 0.047)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Picker("Animation", selection: $selectedMode) {
                    ForEach(SiriAnimationMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 360)

                SiriMetalView(mode: selectedMode)
                    .aspectRatio(1, contentMode: .fit)
                    .frame(maxWidth: 420, maxHeight: 420)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .black.opacity(0.6), radius: 30, x: 0, y: 20)
                    .accessibilityLabel(selectedMode.accessibilityLabel)
            }
            .padding(24)
        }
    }
}

#Preview {
    ContentView()
}
