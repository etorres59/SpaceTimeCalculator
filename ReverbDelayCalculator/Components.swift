//
//  Components.swift
//  Space & Time
//
//  Results list, single result row, and the tap-tempo sheet.
//

import SwiftUI

// MARK: - Results

enum ResultMode: String, CaseIterable, Identifiable {
    case delay = "Delay"
    case reverb = "Reverb"
    var id: String { rawValue }
}

struct ResultsView: View {
    @ObservedObject var calculator: TimeCalculator
    @ObservedObject var reverb: ReverbCalculator
    /// Non-nil when shown as a sheet (compact width); nil when inline beside the input.
    var onClose: (() -> Void)?

    @AppStorage("resultMode") private var modeRaw = ResultMode.delay.rawValue
    @AppStorage("unit") private var unitRaw = TimeUnit.milliseconds.rawValue
    @AppStorage("sampleRate") private var sampleRateRaw = SampleRate.sr48000.rawValue
    @State private var copiedID: String?

    private var mode: ResultMode {
        get { ResultMode(rawValue: modeRaw) ?? .delay }
        nonmutating set { modeRaw = newValue.rawValue }
    }
    private var unit: TimeUnit {
        get { TimeUnit(rawValue: unitRaw) ?? .milliseconds }
        nonmutating set { unitRaw = newValue.rawValue }
    }
    private var sampleRate: SampleRate {
        get { SampleRate(rawValue: sampleRateRaw) ?? .sr48000 }
        nonmutating set { sampleRateRaw = newValue.rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if calculator.isValidBPM {
                switch mode {
                case .delay:
                    results
                case .reverb:
                    ReverbHelperView(reverb: reverb, bpm: calculator.bpm,
                                     copiedID: $copiedID, flash: flash)
                }
            } else {
                ContentUnavailableCompat(
                    title: "No tempo yet",
                    message: calculator.validationMessage ?? "Enter a tempo to see delay and reverb times."
                )
            }
        }
        .background(Color.surface)
    }

    private var copyAllText: String {
        mode == .delay
            ? calculator.exportText(unit: unit, sampleRate: sampleRate)
            : reverb.exportText(bpm: calculator.bpm)
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                Text(calculator.isValidBPM ? "\(Int(calculator.bpm)) BPM" : "Set a tempo")
                    .font(.headline)
                Spacer()
                if let onClose {
                    Button("Done", action: onClose)
                        .buttonStyle(.borderedProminent)
                        .tint(.brandPurple)
                }
            }

            Picker("Mode", selection: Binding(get: { mode }, set: { mode = $0 })) {
                ForEach(ResultMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            if mode == .delay {
                Picker("Unit", selection: Binding(get: { unit }, set: { unit = $0 })) {
                    ForEach(TimeUnit.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)

                if unit == .samples {
                    Picker("Sample rate", selection: Binding(get: { sampleRate }, set: { sampleRate = $0 })) {
                        ForEach(SampleRate.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if calculator.isValidBPM {
                HStack {
                    Button {
                        Clipboard.copy(copyAllText)
                        flash("all")
                    } label: {
                        Label(copiedID == "all" ? "Copied" : "Copy all", systemImage: copiedID == "all" ? "checkmark" : "doc.on.doc")
                    }
                    Spacer()
                    ShareLink(item: copyAllText) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
                .font(.subheadline)
            }
        }
        .padding()
    }

    // MARK: Rows

    private var results: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                ForEach(NoteDuration.grouped, id: \.base.id) { group in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(group.base.sectionTitle)
                            .font(.headline)
                            .foregroundStyle(Color.brandPink)
                        ForEach(group.durations) { note in
                            NoteRow(
                                name: note.displayName,
                                value: calculator.formatted(note, unit: unit, sampleRate: sampleRate),
                                isCopied: copiedID == note.id
                            ) {
                                Clipboard.copy(calculator.formatted(note, unit: unit, sampleRate: sampleRate))
                                flash(note.id)
                            }
                            if note.id != group.durations.last?.id {
                                Divider()
                            }
                        }
                    }
                    .padding()
                    .background(Color.surfaceSecondary, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
        }
    }

    private func flash(_ id: String) {
        withAnimation { copiedID = id }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation { if copiedID == id { copiedID = nil } }
        }
    }
}

struct NoteRow: View {
    let name: String
    let value: String
    let isCopied: Bool
    let onCopy: () -> Void

    var body: some View {
        HStack {
            Text(name)
            Spacer()
            Text(value)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc")
                .foregroundStyle(isCopied ? Color.green : Color.secondary)
                .imageScale(.small)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onCopy)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(value)")
        .accessibilityHint("Double tap to copy")
    }
}

// MARK: - Reverb helper

struct ReverbHelperView: View {
    @ObservedObject var reverb: ReverbCalculator
    let bpm: Double
    @Binding var copiedID: String?
    let flash: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                card("Space") {
                    Picker("Space", selection: Binding(get: { reverb.space }, set: { reverb.apply($0) })) {
                        ForEach(ReverbSpace.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                card("Adjust") {
                    HStack {
                        Text("Pre-delay")
                        Spacer()
                        Picker("Pre-delay", selection: $reverb.preDelay) {
                            ForEach(ReverbCalculator.preDelayChoices) { Text($0.fractionLabel).tag($0) }
                        }
                        .labelsHidden()
                    }
                    Divider()
                    HStack {
                        Text("Decay")
                        Spacer()
                        Picker("Decay", selection: $reverb.decay) {
                            ForEach(ReverbDecayLength.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .labelsHidden()
                    }
                }

                card("Suggested") {
                    row("Pre-delay", String(format: "%.1f ms", reverb.preDelayMs(bpm: bpm)), "reverb-pre")
                    Divider()
                    row("Decay", String(format: "%.0f ms", reverb.decayMs(bpm: bpm)), "reverb-decay")
                    Divider()
                    row("Total", String(format: "%.0f ms", reverb.totalMs(bpm: bpm)), "reverb-total")
                }

                Text("Pre-delay keeps the dry hit clear before the tail; total is when the tail has faded, so the reverb resolves before the next phrase.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }

    @ViewBuilder
    private func card<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.brandPink)
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surfaceSecondary, in: RoundedRectangle(cornerRadius: 12))
    }

    private func row(_ name: String, _ value: String, _ id: String) -> some View {
        NoteRow(name: name, value: value, isCopied: copiedID == id) {
            Clipboard.copy(value)
            flash(id)
        }
    }
}

// MARK: - Tap tempo

struct TapTempoView: View {
    @ObservedObject var tapTempo: TapTempoCalculator
    var onUse: (Double) -> Void
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Tap Tempo")
                .font(BrandFont.display(34, relativeTo: .largeTitle))
                .foregroundStyle(Color.brandPurple)

            Text(tapTempo.instructions)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)

            Button(action: tap) {
                Text("TAP")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity, minHeight: 140)
                    .background(Color.brandPurple, in: RoundedRectangle(cornerRadius: 16))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Tap in time with the tempo you want")

            if let bpm = tapTempo.calculatedBPM {
                Text("\(Int(bpm.rounded())) BPM")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.brandPink)

                HStack {
                    nudgeButton("÷2") { tapTempo.halve() }
                    nudgeButton("−1") { tapTempo.nudge(-1) }
                    nudgeButton("−0.1") { tapTempo.nudge(-0.1) }
                    nudgeButton("+0.1") { tapTempo.nudge(0.1) }
                    nudgeButton("+1") { tapTempo.nudge(1) }
                    nudgeButton("×2") { tapTempo.double() }
                }
            }

            Spacer()

            Button {
                if let bpm = tapTempo.calculatedBPM { onUse(bpm) }
            } label: {
                Text("Use Tempo").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.brandPink)
            .disabled(tapTempo.calculatedBPM == nil)

            HStack {
                Button("Restart", action: tapTempo.reset)
                    .frame(maxWidth: .infinity)
                Button("Close", action: onClose)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: 480)
        .background(Color.surface)
    }

    private func nudgeButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.footnote)
            .buttonStyle(.bordered)
    }

    private func tap() {
        tapTempo.registerTap()
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }
}

// MARK: - Small compatibility shim

/// `ContentUnavailableView` is macOS 14+/iOS 17+; this keeps a 13.5 deployment target working.
struct ContentUnavailableCompat: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "metronome")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
