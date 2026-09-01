import SwiftUI

// Main content view: tempo input on the left/top, calculated times on the right/in a sheet.
struct ContentView: View {
    @StateObject private var timeCalculator = TimeCalculator()
    @StateObject private var tapTempoCalculator = TapTempoCalculator()
    @StateObject private var reverbCalculator = ReverbCalculator()
    @StateObject private var metronome = MetronomeEngine()
    @StateObject private var history = TempoHistory()

    @AppStorage("lastBPM") private var lastBPM = 120.0
    @State private var bpmText = ""
    @State private var showResults = false
    @State private var showTapTempo = false
    @State private var showMetronome = false
    @State private var recordTask: Task<Void, Never>?

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
        .onChange(of: bpmText) { _ in
            syncBPM()
            scheduleRecord()
        }
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
        .sheet(isPresented: $showMetronome) {
            MetronomeView(metronome: metronome,
                          bpm: timeCalculator.isValidBPM ? timeCalculator.bpm : 120) {
                showMetronome = false
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

                TempoChipsView(history: history,
                               current: timeCalculator.bpm,
                               isValid: timeCalculator.isValidBPM,
                               onPick: applyBPM)
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

            HStack(spacing: 12) {
                Button {
                    showTapTempo = true
                } label: {
                    Label("Tap Tempo", systemImage: "hand.tap")
                        .frame(maxWidth: .infinity)
                }
                Button {
                    showMetronome = true
                } label: {
                    Label(metronome.isRunning ? "Playing" : "Metronome",
                          systemImage: metronome.isRunning ? "metronome.fill" : "metronome")
                        .frame(maxWidth: .infinity)
                }
            }
            .font(.body)
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

    /// Push a tempo into the input field (used by Tap Tempo, Match mode, and history chips).
    private func applyBPM(_ value: Double) {
        let rounded = (value * 10).rounded() / 10
        bpmText = formattedBPM(rounded)
        history.record(rounded)
    }

    /// Record the current tempo once editing settles, so typing doesn't spam the recents list.
    private func scheduleRecord() {
        recordTask?.cancel()
        recordTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled, timeCalculator.isValidBPM else { return }
            history.record(timeCalculator.bpm)
        }
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
