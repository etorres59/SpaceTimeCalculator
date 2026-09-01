//
//  Components.swift
//  Space & Time
//
//  Results list, single result row, and the tap-tempo sheet.
//

import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

// MARK: - Results

enum ResultMode: String, CaseIterable, Identifiable {
    case delay = "Delay"
    case reverb = "Reverb"
    case match = "Match"
    var id: String { rawValue }
}

/// Card with a pink section title, used across the results modes for a consistent look.
struct SectionCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.brandPink)
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surfaceSecondary, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct ResultsView: View {
    @ObservedObject var calculator: TimeCalculator
    @ObservedObject var reverb: ReverbCalculator
    /// Non-nil when shown as a sheet (compact width); nil when inline beside the input.
    var onClose: (() -> Void)?
    /// Lets Match mode push a tempo back to the input field.
    var onPickBPM: ((Double) -> Void)?

    @AppStorage("resultMode") private var modeRaw = ResultMode.delay.rawValue
    @AppStorage("unit") private var unitRaw = TimeUnit.milliseconds.rawValue
    @AppStorage("sampleRate") private var sampleRateRaw = SampleRate.sr48000.rawValue
    @AppStorage("feelFilter") private var feelRaw = "Straight,Dotted,Triplet"
    @AppStorage("shortestNote") private var shortestRaw = NoteBase.sixtyFourth.rawValue
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
    private var feels: Set<NoteModifier> {
        let set = Set(feelRaw.split(separator: ",").compactMap { NoteModifier(rawValue: String($0)) })
        return set.isEmpty ? [.straight] : set
    }
    private var shortest: NoteBase {
        get { NoteBase(rawValue: shortestRaw) ?? .sixtyFourth }
        nonmutating set { shortestRaw = newValue.rawValue }
    }
    private var isFiltered: Bool { feels.count < NoteModifier.allCases.count || shortest != .sixtyFourth }

    private func setFeel(_ modifier: NoteModifier, on: Bool) {
        var set = feels
        if on { set.insert(modifier) } else { set.remove(modifier) }
        guard !set.isEmpty else { return }   // always leave one feel visible
        feelRaw = NoteModifier.allCases.filter { set.contains($0) }.map(\.rawValue).joined(separator: ",")
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
                case .match:
                    MatchView(calculator: calculator, onPickBPM: onPickBPM,
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
            ? calculator.exportText(unit: unit, sampleRate: sampleRate, feels: feels, shortest: shortest)
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

                Menu {
                    Section("Feel") {
                        ForEach(NoteModifier.allCases) { modifier in
                            Toggle(modifier.rawValue, isOn: Binding(
                                get: { feels.contains(modifier) },
                                set: { setFeel(modifier, on: $0) }))
                        }
                    }
                    Picker("Shortest note", selection: Binding(get: { shortest }, set: { shortest = $0 })) {
                        ForEach(NoteBase.allCases) { Text($0.fractionLabel).tag($0) }
                    }
                } label: {
                    Label(isFiltered ? "Filtered" : "Filter",
                          systemImage: isFiltered ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if calculator.isValidBPM && mode != .match {
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
                ForEach(NoteDuration.grouped(feels: feels, shortest: shortest), id: \.base.id) { group in
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

// MARK: - Tempo history

struct TempoChipsView: View {
    @ObservedObject var history: TempoHistory
    let current: Double
    let isValid: Bool
    var onPick: (Double) -> Void

    @State private var namingNew = false
    @State private var renameTarget: FavoriteTempo?
    @State private var draftName = ""

    var body: some View {
        if isValid || !history.favorites.isEmpty || !history.recents.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if isValid {
                        Button {
                            if history.isFavorite(current) {
                                history.removeFavorite(bpm: current)
                            } else {
                                draftName = ""
                                namingNew = true
                            }
                        } label: {
                            Image(systemName: history.isFavorite(current) ? "star.fill" : "star")
                        }
                        .buttonStyle(.bordered)
                        .tint(.brandPink)
                        .accessibilityLabel(history.isFavorite(current) ? "Remove this tempo from favourites" : "Save this tempo")
                    }

                    ForEach(history.favorites) { fav in
                        chip(fav.name.isEmpty ? label(fav.bpm) : "\(fav.name) · \(label(fav.bpm))",
                             icon: "star.fill", tint: .brandPink) { onPick(fav.bpm) }
                            .contextMenu {
                                Button("Rename") {
                                    draftName = fav.name
                                    renameTarget = fav
                                }
                                Button("Remove", role: .destructive) { history.removeFavorite(fav.id) }
                            }
                    }

                    ForEach(history.recents.filter { !history.isFavorite($0) }, id: \.self) { bpm in
                        chip(label(bpm), icon: nil, tint: .brandPurple) { onPick(bpm) }
                    }
                }
                .padding(.vertical, 2)
            }
            .alert("Name this tempo", isPresented: $namingNew) {
                TextField("e.g. Verse", text: $draftName)
                Button("Save") { history.addFavorite(current, name: draftName) }
                Button("Cancel", role: .cancel) { }
            }
            .alert("Rename tempo", isPresented: Binding(get: { renameTarget != nil },
                                                       set: { if !$0 { renameTarget = nil } }),
                   presenting: renameTarget) { fav in
                TextField("Name", text: $draftName)
                Button("Save") { history.rename(fav.id, to: draftName) }
                Button("Cancel", role: .cancel) { }
            }
        }
    }

    private func label(_ v: Double) -> String {
        v.rounded() == v ? String(Int(v)) : String(format: "%.1f", v)
    }

    private func chip(_ text: String, icon: String?, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon { Image(systemName: icon).imageScale(.small) }
                Text(text).monospacedDigit()
            }
            .font(.subheadline)
        }
        .buttonStyle(.bordered)
        .tint(tint)
        .accessibilityLabel("\(text) BPM")
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
        SectionCard(title: title) { content() }
    }

    private func row(_ name: String, _ value: String, _ id: String) -> some View {
        NoteRow(name: name, value: value, isCopied: copiedID == id) {
            Clipboard.copy(value)
            flash(id)
        }
    }
}

// MARK: - Reverse lookup

struct MatchView: View {
    @ObservedObject var calculator: TimeCalculator
    var onPickBPM: ((Double) -> Void)?
    @Binding var copiedID: String?
    let flash: (String) -> Void

    @AppStorage("matchText") private var text = "320"
    @AppStorage("matchUseHz") private var useHz = false

    /// The typed value converted to milliseconds (a period, if entered as Hz).
    private var targetMs: Double {
        guard let v = Double(text.replacingOccurrences(of: ",", with: ".")), v > 0 else { return 0 }
        return useHz ? 1_000.0 / v : v
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionCard(title: "Target") {
                    HStack {
                        TextField(useHz ? "Frequency" : "Delay time", text: $text)
                            .textFieldStyle(.roundedBorder)
                            .monospacedDigit()
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .accessibilityLabel(useHz ? "Target frequency in hertz" : "Target time in milliseconds")
                        Picker("Unit", selection: $useHz) {
                            Text("ms").tag(false)
                            Text("Hz").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 108)
                    }
                }

                if targetMs > 0 {
                    let matches = calculator.matches(toMs: targetMs)

                    SectionCard(title: "Closest at \(Int(calculator.bpm)) BPM") {
                        ForEach(Array(matches.enumerated()), id: \.element.id) { index, match in
                            matchRow(match)
                            if index < matches.count - 1 { Divider() }
                        }
                    }

                    if let best = matches.first {
                        SectionCard(title: "Lock to grid") {
                            Text("\(best.note.displayName) hits \(displayTarget) exactly at \(bpmText(best.bpmForExact)) BPM.")
                                .font(.subheadline)
                            if let onPickBPM, TimeCalculator.validRange.contains(best.bpmForExact) {
                                Button("Use \(bpmText(best.bpmForExact)) BPM") { onPickBPM(best.bpmForExact) }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.brandPink)
                            }
                        }
                    }
                } else {
                    Text("Enter a delay time you dialled in by ear to find the closest musical note value — and the tempo that would land it exactly on the grid.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
    }

    private var displayTarget: String {
        useHz ? "\(text) Hz" : "\(text) ms"
    }

    private func bpmText(_ v: Double) -> String {
        v.rounded() == v ? String(Int(v)) : String(format: "%.1f", v)
    }

    private func matchRow(_ m: NoteMatch) -> some View {
        let exact = abs(m.deltaMs) < 0.05
        let delta = exact
            ? "exact"
            : String(format: "%@%.1f ms", m.deltaMs > 0 ? "+" : "−", abs(m.deltaMs))
        return HStack {
            Text(m.note.displayName)
            Spacer()
            Text(String(format: "%.1f ms", m.ms))
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Text(delta)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(exact ? Color.green : .secondary)
                .frame(minWidth: 64, alignment: .trailing)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            Clipboard.copy(String(format: "%.1f ms", m.ms))
            flash(m.id)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(m.note.displayName), \(String(format: "%.1f milliseconds", m.ms)), \(exact ? "exact" : delta)")
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

// MARK: - Metronome

struct MetronomeView: View {
    @ObservedObject var metronome: MetronomeEngine
    let bpm: Double
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("Metronome")
                .font(BrandFont.display(30, relativeTo: .largeTitle))
                .foregroundStyle(Color.brandPurple)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text("\(Int(bpm)) BPM")
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.brandPink)

            HStack(spacing: 14) {
                ForEach(0..<metronome.beatsPerBar, id: \.self) { index in
                    Circle()
                        .fill(dotColor(index))
                        .frame(width: index == 0 ? 22 : 16, height: index == 0 ? 22 : 16)
                        .scaleEffect(metronome.isRunning && metronome.beat == index ? 1.6 : 1)
                        .animation(.easeOut(duration: 0.12), value: metronome.beat)
                }
            }
            .frame(height: 44)
            .accessibilityHidden(true)

            Button(action: metronome.toggle) {
                Image(systemName: metronome.isRunning ? "stop.fill" : "play.fill")
                    .font(.system(size: 46))
                    .frame(width: 128, height: 128)
                    .background(metronome.isRunning ? Color.brandPink : Color.brandPurple, in: Circle())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(metronome.isRunning ? "Stop metronome" : "Start metronome")

            Stepper("Beats per bar: \(metronome.beatsPerBar)", value: $metronome.beatsPerBar, in: 1...12)
                .frame(maxWidth: 280)

            Spacer()

            Button("Close") {
                metronome.stop()
                onClose()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: 480)
        .background(Color.surface)
        .onAppear { metronome.bpm = bpm }
        .onChange(of: bpm) { newValue in metronome.bpm = newValue }
        .onDisappear { metronome.stop() }
    }

    private func dotColor(_ index: Int) -> Color {
        if metronome.isRunning && metronome.beat == index {
            return index == 0 ? .brandPink : .brandPurple
        }
        return .secondary.opacity(0.35)
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

// MARK: - macOS menu bar

#if os(macOS)
/// A glanceable version for `MenuBarExtra` — a BPM field and the delay times
/// producers reach for most, without leaving the DAW.
struct MenuBarView: View {
    @AppStorage("lastBPM") private var bpm = 120.0
    @State private var text = ""
    @State private var copiedID: String?

    private var isValid: Bool { TimeCalculator.validRange.contains(bpm) }

    private let keyNotes: [NoteDuration] = [
        NoteDuration(base: .quarter, modifier: .straight),
        NoteDuration(base: .eighth, modifier: .dotted),
        NoteDuration(base: .eighth, modifier: .straight),
        NoteDuration(base: .eighth, modifier: .triplet),
        NoteDuration(base: .sixteenth, modifier: .straight),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Space & Time")
                .font(.headline)

            HStack {
                Text("BPM")
                TextField("", text: $text)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 72)
                    .onSubmit(commit)
            }

            if isValid {
                ForEach(keyNotes) { note in
                    Button {
                        Clipboard.copy(value(note))
                        flash(note.id)
                    } label: {
                        HStack {
                            Text(note.displayName)
                            Spacer()
                            Text(value(note)).monospacedDigit().foregroundStyle(.secondary)
                            Image(systemName: copiedID == note.id ? "checkmark" : "doc.on.doc")
                                .imageScale(.small)
                                .foregroundStyle(copiedID == note.id ? Color.green : .secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Text("Enter a tempo between 20 and 999.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()
            Button("Quit Space & Time") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain)
        }
        .padding(12)
        .frame(width: 244)
        .onAppear { text = label(bpm) }
    }

    private func value(_ note: NoteDuration) -> String {
        String(format: "%.1f ms", note.milliseconds(bpm: bpm))
    }

    private func commit() {
        if let parsed = Double(text.replacingOccurrences(of: ",", with: ".")),
           TimeCalculator.validRange.contains(parsed) {
            bpm = (parsed * 10).rounded() / 10
        }
        text = label(bpm)
    }

    private func label(_ v: Double) -> String {
        v.rounded() == v ? String(Int(v)) : String(format: "%.1f", v)
    }

    private func flash(_ id: String) {
        withAnimation { copiedID = id }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            withAnimation { if copiedID == id { copiedID = nil } }
        }
    }
}
#endif
