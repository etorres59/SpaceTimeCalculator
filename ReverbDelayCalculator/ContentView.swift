import SwiftUI

// Main content view: tempo input on the left/top, calculated times on the right/in a sheet.
struct ContentView: View {
    @StateObject private var timeCalculator = TimeCalculator()
    @StateObject private var tapTempoCalculator = TapTempoCalculator()
    @StateObject private var reverbCalculator = ReverbCalculator()

    @AppStorage("lastBPM") private var lastBPM = 120.0
    @State private var bpmText = ""
    @State private var showResults = false
    @State private var showTapTempo = false

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool { horizontalSizeClass == .compact }

    var body: some View {
        Group {
            if isCompact {
                ScrollView { inputColumn.padding() }
            } else {
                HStack(alignment: .top, spacing: 0) {
                    ScrollView { inputColumn.padding(24) }
                        .frame(maxWidth: 420)
                    Divider()
                    ResultsView(calculator: timeCalculator, reverb: reverbCalculator,
                                onClose: nil, onPickBPM: applyBPM)
                }
            }
        }
        .background(Color.surface.ignoresSafeArea())
        .onAppear {
            bpmText = formattedBPM(lastBPM)
            timeCalculator.bpm = lastBPM
        }
        .onChange(of: bpmText) { _ in syncBPM() }
        .sheet(isPresented: $showResults) {
            ResultsView(calculator: timeCalculator, reverb: reverbCalculator,
                        onClose: { showResults = false }, onPickBPM: applyBPM)
                .presentationDetentsCompat()
        }
        .sheet(isPresented: $showTapTempo) {
            TapTempoView(tapTempo: tapTempoCalculator) { bpm in
                bpmText = formattedBPM(bpm)
                showTapTempo = false
                if isCompact { showResults = true }
            } onClose: {
                showTapTempo = false
            }
        }
    }

    // MARK: - Input column

    private var inputColumn: some View {
        VStack(spacing: 16) {
            VStack(spacing: 2) {
                Text("SPACE & TIME")
                    .font(BrandFont.display(28, relativeTo: .largeTitle))
                Image("Space and time In app image 2")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 96, height: 96)
                    .clipShape(Circle())
                    .accessibilityHidden(true)
                Text("Reverb & Delay Calculator")
                    .font(BrandFont.display(15, relativeTo: .headline))
                    .multilineTextAlignment(.center)
                Text("by Evan Torres")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 4)

            VStack(alignment: .leading, spacing: 6) {
                TextField("Enter BPM", text: $bpmText)
                    .textFieldStyle(.roundedBorder)
                    .font(.title2)
                    .multilineTextAlignment(.center)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                    .accessibilityLabel("Tempo in beats per minute")

                if let message = timeCalculator.validationMessage, !bpmText.isEmpty {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            if isCompact {
                Button {
                    if timeCalculator.isValidBPM { showResults = true }
                } label: {
                    Text("Calculate Times")
                        .font(.title3)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.brandPink)
                .disabled(!timeCalculator.isValidBPM)
            }

            Button {
                showTapTempo = true
            } label: {
                Label("Tap Tempo", systemImage: "hand.tap")
                    .font(.title3)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.brandPurple)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: 420)
    }

    // MARK: - Helpers

    private func syncBPM() {
        let cleaned = bpmText.replacingOccurrences(of: ",", with: ".")
        if let value = Double(cleaned) {
            timeCalculator.bpm = value
            if TimeCalculator.validRange.contains(value) { lastBPM = value }
        } else {
            timeCalculator.bpm = 0
        }
    }

    private func formattedBPM(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
    }

    /// Push a tempo into the input field (used by Tap Tempo and Match mode).
    private func applyBPM(_ value: Double) {
        bpmText = formattedBPM((value * 10).rounded() / 10)
    }
}

// `presentationDetents` needs iOS 16.4 / macOS 13.3 for the `.fraction` cases we care about;
// this keeps the call site tidy and no-ops where unavailable.
private extension View {
    @ViewBuilder
    func presentationDetentsCompat() -> some View {
        #if os(iOS)
        self.presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        #else
        self.frame(minWidth: 420, minHeight: 560)
        #endif
    }
}

#Preview {
    ContentView()
}
