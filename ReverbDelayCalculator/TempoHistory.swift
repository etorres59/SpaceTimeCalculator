//
//  TempoHistory.swift
//  Space & Time
//
//  Recent tempos and named favourites, persisted to UserDefaults.
//

import Foundation
import Combine

struct FavoriteTempo: Codable, Identifiable, Equatable {
    var id = UUID()
    var bpm: Double
    var name: String
}

/// Store for the tempo the user has been using and the ones they've starred.
/// `UserDefaults` is injectable so tests get a clean, isolated suite.
final class TempoHistory: ObservableObject {
    static let maxRecents = 8

    @Published private(set) var recents: [Double] = []
    @Published private(set) var favorites: [FavoriteTempo] = []

    private let defaults: UserDefaults
    private let recentsKey = "tempo.recents"
    private let favoritesKey = "tempo.favorites"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        recents = defaults.array(forKey: recentsKey) as? [Double] ?? []
        if let data = defaults.data(forKey: favoritesKey),
           let decoded = try? JSONDecoder().decode([FavoriteTempo].self, from: data) {
            favorites = decoded
        }
    }

    /// Tempos are matched at 0.1-BPM resolution so tap-tempo decimals dedupe sensibly.
    private func rounded(_ bpm: Double) -> Double { (bpm * 10).rounded() / 10 }

    func record(_ bpm: Double) {
        guard TimeCalculator.validRange.contains(bpm) else { return }
        let value = rounded(bpm)
        recents.removeAll { rounded($0) == value }
        recents.insert(value, at: 0)
        if recents.count > Self.maxRecents {
            recents.removeLast(recents.count - Self.maxRecents)
        }
        defaults.set(recents, forKey: recentsKey)
    }

    func clearRecents() {
        recents.removeAll()
        defaults.set(recents, forKey: recentsKey)
    }

    func isFavorite(_ bpm: Double) -> Bool {
        favorites.contains { rounded($0.bpm) == rounded(bpm) }
    }

    func addFavorite(_ bpm: Double, name: String) {
        guard TimeCalculator.validRange.contains(bpm), !isFavorite(bpm) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        favorites.insert(FavoriteTempo(bpm: rounded(bpm), name: trimmed), at: 0)
        persistFavorites()
    }

    func removeFavorite(_ id: FavoriteTempo.ID) {
        favorites.removeAll { $0.id == id }
        persistFavorites()
    }

    func removeFavorite(bpm: Double) {
        favorites.removeAll { rounded($0.bpm) == rounded(bpm) }
        persistFavorites()
    }

    func rename(_ id: FavoriteTempo.ID, to name: String) {
        guard let index = favorites.firstIndex(where: { $0.id == id }) else { return }
        favorites[index].name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        persistFavorites()
    }

    private func persistFavorites() {
        if let data = try? JSONEncoder().encode(favorites) {
            defaults.set(data, forKey: favoritesKey)
        }
    }
}
