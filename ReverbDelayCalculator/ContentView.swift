import SwiftUI

@main
struct ReverbDelayCalculatorApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// Main content view for the app
struct ContentView: View {
    @StateObject private var timeCalculator = TimeCalculator()
    @StateObject private var tapTempoCalculator = TapTempoCalculator()
    @State private var showCalculatedTimes = false
    @State private var showTapTempo = false

    var body: some View {
        VStack {
            Text("SPACE & TIME")
                .font(.custom("NaNHoloGigawide-Ultra", size: 25)) // Nice looking font for title
                .frame(alignment: .center) // Makes the text frame centered
                .foregroundColor(Color.white)

            Image("Space and time In app image 2") //
                .resizable()
                .frame(width: 100, height: 100)
                .clipShape(Circle())// Apply a circular shape to the image
            
            Text("Reverb & Delay")
                .font(.custom("NaNHoloGigawide-Ultra", size: 15)) // Nice looking font for title
                .frame(alignment: .center) // Makes the text frame centered
                .foregroundColor(Color.white)
            Text("Calculator")
                .font(.custom("NaNHoloGigawide-Ultra", size: 15)) // Nice looking font for title
                .frame(alignment: .center) // Makes the text frame fill the entire width and centers it
                .foregroundColor(Color.white)
                
            Text("by Evan Torres")
                .font(.title3)
                .foregroundColor(Color.white)
                .padding()
            
            // BPM input field
            TextField("Enter BPM", value: $timeCalculator.bpm, formatter: NumberFormatter())
                .padding()
                .background(Color.white)
                .foregroundColor(.black)
                .cornerRadius(8)
                .shadow(radius: 2)
                .padding(.horizontal)
                .onAppear {
                    timeCalculator.bpm = 0 // Ensure BPM is reset on appear
                }

            // Calculate Times button
            Button(action: {
                timeCalculator.calculateTimes()
                showCalculatedTimes = true
            }) {
                Text("Calculate Times")
                    .font(.title2)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.customPink1)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding()

            // Tap Tempo button
            Button(action: {
                showTapTempo = true
            }) {
                Text("Tap Tempo")
                    .font(.title2)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .frame(alignment: .center)
                    .background(Color.customPurple1)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding()

            Spacer()
        }
        .sheet(isPresented: $showCalculatedTimes) {
            NoteTimesView(calculatedTimes: timeCalculator.calculatedTimes, onClose: {
                showCalculatedTimes = false
            })
        }
        .sheet(isPresented: $showTapTempo) {
            TapTempoView(tapTempoCalculator: tapTempoCalculator, onCalculate: {
                if let bpm = tapTempoCalculator.calculatedBPM {
                    timeCalculator.bpm = bpm
                    timeCalculator.calculateTimes()
                    showCalculatedTimes = true
                    showTapTempo = false
                }
            }, onClose: {
                showTapTempo = false
            })
        }
        .padding()
        .background(Color.vibrantPurple.ignoresSafeArea()) // Light pastel background
    }
}

// View to display calculated note times, grouped by note subdivision
struct NoteTimesView: View {
    let calculatedTimes: [(String, Double)] // Updated tuple to remove the number
    var onClose: () -> Void // Close function
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Group {
                    Text("Whole Notes")
                        .font(.headline)
                        .foregroundColor(.customPink1)
                        .underline(true, color: .customPink1)
                    ForEach(calculatedTimes.prefix(3), id: \.0) { note in
                        Text("\(note.0): \(String(format: "%.2f", note.1)) ms")
                            .foregroundColor(.black)
                        Text("-------------------------")
                            .foregroundColor(.black)
                    }
                }

                Group {
                    Text("Half Notes")
                        .font(.headline)
                        .foregroundColor(.customPink1)
                        .underline(true, color: .customPink1)
                    ForEach(calculatedTimes[3..<6], id: \.0) { note in
                        Text("\(note.0): \(String(format: "%.2f", note.1)) ms")
                            .foregroundColor(.black)
                        Text("-------------------------")
                            .foregroundColor(.black)
                    }
                }

                Group {
                    Text("Quarter Notes")
                        .font(.headline)
                        .foregroundColor(.customPink1)
                        .underline(true, color: .customPink1)
                    ForEach(calculatedTimes[6..<9], id: \.0) { note in
                        Text("\(note.0): \(String(format: "%.2f", note.1)) ms")
                            .foregroundColor(.black)
                        Text("-------------------------")
                            .foregroundColor(.black)
                    }
                }

                Group {
                    Text("Eighth Notes")
                        .font(.headline)
                        .foregroundColor(.customPink1)
                        .underline(true, color: .customPink1)
                    ForEach(calculatedTimes[9..<12], id: \.0) { note in
                        Text("\(note.0): \(String(format: "%.2f", note.1)) ms")
                            .foregroundColor(.black)
                        Text("-------------------------")
                            .foregroundColor(.black)
                    }
                }

                Group {
                    Text("Sixteenth Notes")
                        .font(.headline)
                        .foregroundColor(.customPink1)
                        .underline(true, color: .customPink1)
                    ForEach(calculatedTimes[12..<15], id: \.0) { note in
                        Text("\(note.0): \(String(format: "%.2f", note.1)) ms")
                            .foregroundColor(.black)
                        Text("-------------------------")
                            .foregroundColor(.black)
                    }
                }

                Group {
                    Text("Thirty-second Notes")
                        .font(.headline)
                        .foregroundColor(.customPink1)
                        .underline(true, color: .customPink1)
                    ForEach(calculatedTimes[15..<18], id: \.0) { note in
                        Text("\(note.0): \(String(format: "%.2f", note.1)) ms")
                            .foregroundColor(.black)
                        Text("-------------------------")
                            .foregroundColor(.black)
                    }
                }

                Group {
                    Text("Sixty-fourth Notes")
                        .font(.headline)
                        .foregroundColor(.customPink1)
                        .underline(true, color: .customPink1)
                    ForEach(calculatedTimes[18..<21], id: \.0) { note in
                        Text("\(note.0): \(String(format: "%.2f", note.1)) ms")
                            .foregroundColor(.black)
                        Text("-------------------------")
                            .foregroundColor(.black)
                    }
                }
            }
            .padding()

            Button("Close") { // Close button
                onClose()
            }
            .padding()
            .background(Color.customPurple1)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .background(Color.vibrantBackground.ignoresSafeArea())
    }
}

// View for tap tempo functionality
struct TapTempoView: View {
    @ObservedObject var tapTempoCalculator: TapTempoCalculator
    var onCalculate: () -> Void
    var onClose: () -> Void // Close function
    
    var body: some View {
        ZStack {
            // Custom background color for the entire pop-up
            Color.vibrantBackground // Replace with your desired color
                .ignoresSafeArea() // Ensures the color covers the entire safe area

            VStack {
                // Keep the Tap Tempo text where it was originally
                Text("     Tap Tempo")
                    .font(.custom("NaNHoloGigawide-Ultra", size: 34))
                    .foregroundColor(Color.vibrantPurple)
                    .padding()
                
                VStack(alignment: .center) {   // Instructions for tapping
                    Text(tapTempoCalculator.instructions)
                        .padding()
                        .foregroundColor(.black)
                }
                VStack {
                    Button(action: {
                        tapTempoCalculator.registerTap()
                    }) {
                        Text("Tap Here")
                            .font(.title)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.vibrantPurple)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .padding()
                    
                    if let bpm = tapTempoCalculator.calculatedBPM {
                        Text("Calculated BPM: \(Int(bpm))")
                            .font(.title)
                            .padding()
                            .foregroundColor(Color.vibrantPurple)
                    }
                    
                    Button("Calculate Times") {
                        onCalculate()
                    }
                    .padding()
                    .background(Color.customPink1)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    
                    Button("Restart") {
                        tapTempoCalculator.resetTapping()
                    }
                    .padding()
                    .background(Color.customPurple1)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    
                    Button("Close") { // Close button
                        onClose()
                    }
                    .padding()
                    .background(Color.customPurple1)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding()
                
                Spacer() // Keeps other elements spaced out below the text
            }
            .padding()
        }
    }
}

// Define colors in extensions for easy access
extension Color {
    static let vibrantBackground = Color(red: 240/255, green: 240/255, blue: 255/255) // Light pastel background
    static let vibrantPurple = Color(red: 180/255, green: 100/255, blue: 250/255) // Bright purple
    static let vibrantBlue = Color(red: 100/255, green: 150/255, blue: 250/255) // Bright blue
    static let vibrantGreen = Color(red: 100/255, green: 250/255, blue: 150/255) // Bright green
    static let vibrantYellow = Color(red: 250/255, green: 250/255, blue: 100/255) // Bright yellow
    static let customPink1 = Color(red: 166 / 255, green: 59 / 255, blue: 138 / 255) // Hex: #A63B8A
    static let customPink2 = Color(red: 213 / 255, green: 90 / 255, blue: 155 / 255) // Hex: #D55A9B
    static let customPurple1 = Color(red: 153 / 255, green: 146 / 255, blue: 216 / 255) // Hex: #9992D8
    static let customPurple2 = Color(red: 85 / 255, green: 70 / 255, blue: 101 / 255) // Hex: #554665
    static let customLavender = Color(red: 164 / 255, green: 142 / 255, blue: 173 / 255) // Hex: #A48EAD
}
