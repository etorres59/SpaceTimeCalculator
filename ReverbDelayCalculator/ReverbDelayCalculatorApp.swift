//
//  ReverbDelayCalculatorApp.swift
//  ReverbDelayCalculator
//
//  Created by Evan Torres on 10/17/24.
//
import Foundation
import Combine

// Class to calculate times based on BPM
class TimeCalculator: ObservableObject {
    @Published var bpm: Double = 0.0
    @Published var calculatedTimes: [(String, Double)] = [] // Updated tuple

    // Function to calculate the times based on BPM
    func calculateTimes() {
        let quarterNoteMs = 60000.0 / bpm
        calculatedTimes = [
            ("Whole Note", quarterNoteMs * 4),
            ("Dotted Whole Note", quarterNoteMs * 6),
            ("Triplet Whole Note", quarterNoteMs * 8 / 3),
            ("Half Note", quarterNoteMs * 2),
            ("Dotted Half Note", quarterNoteMs * 3),
            ("Triplet Half Note", quarterNoteMs * 4 / 3),
            ("Quarter Note", quarterNoteMs),
            ("Dotted Quarter Note", quarterNoteMs * 1.5),
            ("Triplet Quarter Note", quarterNoteMs * 2 / 3),
            ("Eighth Note", quarterNoteMs / 2),
            ("Dotted Eighth Note", quarterNoteMs * 0.75),
            ("Triplet Eighth Note", quarterNoteMs / 3),
            ("Sixteenth Note", quarterNoteMs / 4),
            ("Dotted Sixteenth Note", quarterNoteMs / 4 * 1.5),
            ("Triplet Sixteenth Note", quarterNoteMs / 6),
            ("Thirty-second Note", quarterNoteMs / 8),
            ("Dotted Thirty-second Note", quarterNoteMs / 8 * 1.5),
            ("Triplet Thirty-second Note", quarterNoteMs / 12),
            ("Sixty-fourth Note", quarterNoteMs / 16),
            ("Dotted Sixty-fourth Note", quarterNoteMs / 16 * 1.5),
            ("Triplet Sixty-fourth Note", quarterNoteMs / 24)
        ]
    }
}

// Class to handle tap tempo functionality
class TapTempoCalculator: ObservableObject {
    @Published var intervals: [Double] = []
    @Published var calculatedBPM: Double?
    @Published var instructions: String = "Press the tap button 8 times to calculate BPM:"
    let minimumTapInterval = 10.0 // 10 ms minimum interval to avoid double taps
    
    // Function to register a tap
    func registerTap() {
        let now = Date().timeIntervalSince1970 * 1000 // Current time in milliseconds
        
        if intervals.isEmpty {
            intervals.append(now) // Record the first tap timestamp
        } else {
            let lastTap = intervals.last!
            let interval = now - lastTap // Calculate the interval from the last tap
            
            if interval > minimumTapInterval {
                intervals.append(now) // Append current tap timestamp

                // Calculate BPM if enough taps are recorded (minimum of 9 taps)
                if intervals.count >= 8 {
                    calculateBPM()
                }
            } else {
                instructions = "Tap ignored (too fast). Please tap again."
            }
        }
    }

    // Function to calculate BPM from tap intervals
    func calculateBPM() {
        guard intervals.count >= 8 else { return }
        
        // Calculate the intervals between each consecutive tap
        var timeIntervals: [Double] = []
        for i in 1..<intervals.count {
            let interval = intervals[i] - intervals[i - 1]
            timeIntervals.append(interval)
        }
        
        // Calculate the average of the intervals
        let averageInterval = timeIntervals.reduce(0, +) / Double(timeIntervals.count)
        
        // Calculate BPM from the average interval
        let bpm = 60000.0 / averageInterval
        calculatedBPM = bpm

    }
    
    // Reset the tap tempo calculation
    func resetTapping() {
        intervals.removeAll()
        calculatedBPM = nil
        instructions = "Press the tap button 8 times to calculate BPM"
    }
}
