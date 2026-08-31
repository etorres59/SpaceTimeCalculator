//
//  Components.swift
//  Space & Time
//
//  Results list, single result row, and the tap-tempo sheet.
//

import SwiftUI

// MARK: - Results

struct ResultsView: View {
    @ObservedObject var calculator: TimeCalculator
    /// Non-nil when shown as a sheet (compact width); nil when inline beside the input.
    var onClose: (() -> Void)?

    @AppStorage("unit") private var unitRaw = TimeUnit.milliseconds.rawValue
    @AppStorage("sampleRate") private var sampleRateRaw = SampleRate.sr48000.rawValue
    @State private var copiedID: String?

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
                results
            } else {
                ContentUnavailableCompat(
                    title: "No tempo yet",
                    message: calculator.validationMessage ?? "Enter a tempo to see delay and reverb times."
                )
            }
        }
        .background(Color.surface)
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

            if calculator.isValidBPM {
                HStack {
                    Button {
                        Clipboard.copy(calculator.exportText(unit: unit, sampleRate: sampleRate))
                        flash("all")
                    } label: {
                        Label(copiedID == "all" ? "Copied" : "Copy all", systemImage: copiedID == "all" ? "checkmark" : "doc.on.doc")
                    }
                    Spacer()
                    ShareLink(item: calculator.exportText(unit: unit, sampleRate: sampleRate)) {
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
