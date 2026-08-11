import AppKit
import Combine
import Foundation

@MainActor
final class ArtworkStore: ObservableObject {
    static let shared = ArtworkStore()

    enum WallpaperState: Equatable {
        case idle
        case working
        case done
        case failed
    }

    struct Notice: Identifiable, Equatable {
        let id = UUID()
        let title: String
        let message: String
        let isError: Bool
    }

    @Published private(set) var current: Artwork
    @Published var searchText = "" {
        didSet { updateSearchResults() }
    }
    @Published private(set) var searchResults: [Artwork] = []
    @Published private(set) var updateInstallBusy = false
    @Published private(set) var updateInstalled = LaunchAgentManager.shared.isInstalled
    @Published var discoverOpen = false
    @Published private(set) var discoverArtworks: [Artwork] = []
    @Published private(set) var discoverLoading = false
    @Published private(set) var discoverMessage: String?
    @Published private(set) var wallpaperState: WallpaperState = .idle
    @Published private(set) var collectionCount = 0
    @Published var notice: Notice?

    private let curatedCatalog: [Artwork]
    private var catalog: [Artwork]
    private var browseOffset: Int
    private var nineAMTimer: Timer?
    private var wallpaperTask: Task<Void, Never>?

    var menuArtworkTitle: String {
        let raw = "\(current.title) — \(current.artist)"
        return raw.count > 42 ? String(raw.prefix(41)) + "…" : raw
    }

    var formattedUpdateTime: String {
        Self.formattedUpdateTime()
    }

    private init() {
        curatedCatalog = ArtworkCatalog.wallpaper
        let acceptedDiscoveries = ArtworkDiscoveryService.deduplicated(
            ArtworkDiscoveryService.cachedDiscoveries(),
            excluding: curatedCatalog
        )
        catalog = Self.interleaved(curated: curatedCatalog, discoveries: acceptedDiscoveries)
        collectionCount = catalog.count
        let defaults = UserDefaults.standard
        defaults.register(defaults: [
            "applyToAllDisplays": true,
            "zoomToFill": true,
            "updateHour": 9,
            "updateMinute": 0,
        ])
        if !defaults.bool(forKey: "didAdoptFramedWallpaper") {
            defaults.set(false, forKey: "zoomToFill")
            defaults.set(true, forKey: "didAdoptFramedWallpaper")
        }
        if !defaults.bool(forKey: "didAdoptLandscapeOnly") {
            defaults.set(true, forKey: "zoomToFill")
            defaults.set(true, forKey: "didAdoptLandscapeOnly")
        }
        if !defaults.bool(forKey: "didAdoptArtFirstFraming") {
            defaults.set(false, forKey: "zoomToFill")
            defaults.set(true, forKey: "didAdoptArtFirstFraming")
        }

        let todayKey = Self.dayKey()
        if defaults.string(forKey: "lastDayKey") != todayKey {
            defaults.set(todayKey, forKey: "lastDayKey")
            defaults.set(0, forKey: "browseOffset")
        }
        browseOffset = defaults.integer(forKey: "browseOffset")

        let dayIndex = Self.daysSinceLaunchBase() % catalog.count
        current = catalog[(dayIndex + browseOffset) % catalog.count]
        scheduleNineAMRefresh()
    }

    // MARK: - Artwork selection

    func nextArtwork() {
        advanceToDifferentArtwork(direction: 1)
        startWallpaperUpdate(skippingFailuresBy: 1)
    }

    func previousArtwork() {
        advanceToDifferentArtwork(direction: -1)
        startWallpaperUpdate(skippingFailuresBy: -1)
    }

    private func advanceToDifferentArtwork(direction: Int) {
        let previousWork = canonicalArtworkIdentity(current)
        let previousSubject = artworkSubject(current)
        for _ in 0..<max(catalog.count, 1) {
            browseOffset += direction
            updateCurrentFromOffset()
            if canonicalArtworkIdentity(current) != previousWork,
               artworkSubject(current) != previousSubject {
                return
            }
        }
    }

    private func updateCurrentFromOffset() {
        UserDefaults.standard.set(browseOffset, forKey: "browseOffset")
        let dayIndex = Self.daysSinceLaunchBase() % catalog.count
        let index = ((dayIndex + browseOffset) % catalog.count + catalog.count) % catalog.count
        current = catalog[index]
    }

    func show(_ artwork: Artwork) {
        guard let index = catalog.firstIndex(of: artwork) else { return }
        let dayIndex = Self.daysSinceLaunchBase() % catalog.count
        browseOffset = (index - dayIndex + catalog.count) % catalog.count
        UserDefaults.standard.set(browseOffset, forKey: "browseOffset")
        current = artwork
        searchText = ""
    }

    func openPage() {
        guard let url = URL(string: current.pageURL) else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Wallpaper

    /// Applies the current artwork to the desktop wallpaper.
    func setAsWallpaper() {
        startWallpaperUpdate(skippingFailuresBy: nil)
    }

    private func startWallpaperUpdate(skippingFailuresBy direction: Int?) {
        wallpaperTask?.cancel()
        wallpaperState = .working
        wallpaperTask = Task {
            let attempts = direction == nil ? 1 : max(catalog.count, 1)
            var lastError: Error?

            for attempt in 0..<attempts {
                let selectedArtwork = current
                do {
                    try await applyWallpaper(artwork: selectedArtwork)
                    try Task.checkCancellation()
                    wallpaperState = .done
                    notice = Notice(
                        title: "Wallpaper updated",
                        message: UserDefaults.standard.bool(forKey: "applyToAllDisplays") && NSScreen.screens.count > 1
                            ? "Applied to all connected displays. Your lock screen follows this wallpaper."
                            : "Applied to your desktop. Your lock screen follows this wallpaper.",
                        isError: false
                    )
                    return
                } catch is CancellationError {
                    return
                } catch {
                    lastError = error
                    appendWallpaperLog("\(Date()) SKIPPED — \(selectedArtwork.title): \(error.localizedDescription)\n")
                    guard let direction, attempt + 1 < attempts else { break }
                    advanceToDifferentArtwork(direction: direction)
                }
            }

            wallpaperState = .failed
            notice = Notice(
                title: "Couldn't update wallpaper",
                message: lastError?.localizedDescription ?? "No working artwork was available.",
                isError: true
            )
        }
    }

    /// Applies the currently-selected artwork as the wallpaper, then quits.
    /// Used by the daily 9 AM launchd agent and headless invocations.
    func setTodayWallpaperAndQuit() async {
        do {
            try await applyWallpaper(artwork: current)
        } catch {
            appendWallpaperLog("\(Date()) FAILED — \(current.title): \(error.localizedDescription)\n")
        }
        NSApp.terminate(nil)
    }

    private func applyWallpaper(artwork: Artwork) async throws {
        let allDisplays = UserDefaults.standard.bool(forKey: "applyToAllDisplays")
        let screens = allDisplays ? NSScreen.screens : NSScreen.main.map { [$0] } ?? []
        guard !screens.isEmpty else { throw CocoaError(.fileNoSuchFile) }
        let fill = UserDefaults.standard.bool(forKey: "zoomToFill")
        var appliedPath = ""
        for screen in screens {
            let pixelSize = CGSize(
                width: screen.frame.width * screen.backingScaleFactor,
                height: screen.frame.height * screen.backingScaleFactor
            )
            let sourceURL = try await ArtworkImageStore.shared.wallpaperURL(for: artwork, pixelSize: pixelSize, fill: fill)
            try Task.checkCancellation()
            appliedPath = sourceURL.path
            let options: [NSWorkspace.DesktopImageOptionKey: Any] = [
                .imageScaling: NSImageScaling.scaleAxesIndependently.rawValue,
                .allowClipping: false,
            ]
            try NSWorkspace.shared.setDesktopImageURL(sourceURL, for: screen, options: options)
        }
        appendWallpaperLog("\(Date()) OK — \(artwork.title) by \(artwork.artist) (\(appliedPath))\n")
    }

    private func appendWallpaperLog(_ line: String) {
        let logURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/ArtDaily/wallpaper.log")
        if let data = line.data(using: .utf8) {
            try? FileManager.default.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: logURL.path) {
                if let handle = try? FileHandle(forWritingTo: logURL) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    try? handle.close()
                }
            } else {
                try? data.write(to: logURL)
            }
        }
    }

    /// Shows a selected work from the mixed, deduplicated library.
    func display(_ artwork: Artwork) {
        show(artwork)
        discoverOpen = false
    }

    // MARK: - Discover

    func openDiscover() {
        discoverOpen = true
        discoverArtworks = catalog
    }

    func discoverMore() {
        guard !discoverLoading else { return }
        discoverLoading = true
        discoverMessage = nil
        Task {
            do {
                let additions = try await ArtworkDiscoveryService.shared.discover(excluding: discoverArtworks)
                if additions.isEmpty {
                    discoverMessage = "No new works passed the quality and duplicate checks. Try again for the next themes."
                } else {
                    let existingDiscoveries = catalog.filter { $0.id.hasPrefix("discovery-") }
                    let discoveries = ArtworkDiscoveryService.deduplicated(
                        existingDiscoveries + additions,
                        excluding: curatedCatalog
                    )
                    ArtworkDiscoveryService.saveDiscoveries(discoveries)
                    rebuildMixedCatalog(discoveries: discoveries)
                    discoverMessage = "Added \(additions.count) inspiring works to the mixed daily rotation."
                }
            } catch {
                discoverMessage = "Wikimedia Commons could not be reached. Your curated daily rotation is unaffected."
            }
            discoverLoading = false
        }
    }

    func closeDiscover() {
        discoverOpen = false
    }

    private func rebuildMixedCatalog(discoveries: [Artwork]) {
        catalog = Self.interleaved(curated: curatedCatalog, discoveries: discoveries)
        collectionCount = catalog.count
        discoverArtworks = catalog
        updateSearchResults()

        if let currentIndex = catalog.firstIndex(where: { $0.id == current.id }) {
            let dayIndex = Self.daysSinceLaunchBase() % catalog.count
            browseOffset = (currentIndex - dayIndex + catalog.count) % catalog.count
            UserDefaults.standard.set(browseOffset, forKey: "browseOffset")
            current = catalog[currentIndex]
        }
    }

    private static func interleaved(curated: [Artwork], discoveries: [Artwork]) -> [Artwork] {
        var result: [Artwork] = []
        result.reserveCapacity(curated.count + discoveries.count)
        let count = max(curated.count, discoveries.count)
        for index in 0..<count {
            if index < curated.count { result.append(curated[index]) }
            if index < discoveries.count { result.append(discoveries[index]) }
        }
        return result
    }

    private func artworkIdentity(_ artwork: Artwork) -> String {
        "\(artwork.title)|\(artwork.artist)"
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "", options: .regularExpression)
    }

    private func canonicalArtworkIdentity(_ artwork: Artwork) -> String {
        let text = "\(artwork.title) \(artwork.artist) \(artwork.pageURL)".lowercased()
        if text.contains("last supper"),
           ["leonardo", "da_vinci", "da vinci", "milan"].contains(where: text.contains) {
            return "masterpiece-last-supper-leonardo"
        }
        if text.contains("annunciation"),
           ["leonardo", "da_vinci", "da vinci"].contains(where: text.contains) {
            return "masterpiece-annunciation-leonardo"
        }
        if text.contains("sistine chapel ceiling") {
            return "masterpiece-sistine-chapel-ceiling"
        }
        return artworkIdentity(artwork)
    }

    private func artworkSubject(_ artwork: Artwork) -> String {
        let text = "\(artwork.title) \(artwork.artist)".lowercased()
        if ["annunciation", "anunciación", "annunciazione"].contains(where: text.contains) {
            return "annunciation"
        }
        let subjects = [
            "nativity", "resurrection", "ascension", "last supper", "saint peter",
            "angel", "sistine", "vatican",
            "holy family", "baptism", "madonna", "christ",
        ]
        return subjects.first(where: text.contains) ?? canonicalArtworkIdentity(artwork)
    }

    // MARK: - Daily 9 AM update

    func toggleDailyUpdate() {
        guard !updateInstallBusy else { return }
        updateInstallBusy = true
        Task {
            do {
                if updateInstalled {
                    try LaunchAgentManager.shared.uninstall()
                } else {
                    try LaunchAgentManager.shared.install(
                        hour: UserDefaults.standard.integer(forKey: "updateHour"),
                        minute: UserDefaults.standard.integer(forKey: "updateMinute")
                    )
                }
                updateInstalled = LaunchAgentManager.shared.isInstalled
                notice = Notice(
                    title: updateInstalled ? "Daily updates are on" : "Daily updates are off",
                    message: updateInstalled ? "Art will refresh automatically at \(Self.formattedUpdateTime())." : "Your current wallpaper will stay in place.",
                    isError: false
                )
            } catch {
                notice = Notice(title: "Couldn't change the schedule", message: error.localizedDescription, isError: true)
            }
            updateInstallBusy = false
            NotificationCenter.default.post(name: .artInstallChanged, object: nil)
        }
    }

    func refreshInstalledSchedule() {
        guard updateInstalled else { return }
        do {
            try LaunchAgentManager.shared.install(
                hour: UserDefaults.standard.integer(forKey: "updateHour"),
                minute: UserDefaults.standard.integer(forKey: "updateMinute")
            )
            scheduleDailyRefresh()
        } catch {
            notice = Notice(title: "Couldn't save the new time", message: error.localizedDescription, isError: true)
        }
    }

    // MARK: - Search

    private func updateSearchResults() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        searchResults = catalog.filter { artwork in
            let haystack = "\(artwork.title) \(artwork.artist) \(artwork.museum) \(artwork.city) \(artwork.country)".lowercased()
            return query.split(separator: " ").allSatisfy { haystack.contains($0) }
        }
    }

    // MARK: - Nine AM refresh while running

    private func scheduleNineAMRefresh() {
        scheduleDailyRefresh()
    }

    private func scheduleDailyRefresh() {
        nineAMTimer?.invalidate()
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = UserDefaults.standard.integer(forKey: "updateHour")
        components.minute = UserDefaults.standard.integer(forKey: "updateMinute")
        components.second = 0
        var next = calendar.date(from: components) ?? Date()
        if next <= Date() {
            next = calendar.date(byAdding: .day, value: 1, to: next) ?? next
        }
        let timer = Timer(fire: next, interval: 0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.refreshForNewDay()
                self?.scheduleNineAMRefresh()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        nineAMTimer = timer
    }

    private func refreshForNewDay() {
        let defaults = UserDefaults.standard
        defaults.set(Self.dayKey(), forKey: "lastDayKey")
        defaults.set(0, forKey: "browseOffset")
        browseOffset = 0
        let dayIndex = Self.daysSinceLaunchBase() % catalog.count
        current = catalog[dayIndex]
        if updateInstalled {
            setAsWallpaper()
        }
    }

    // MARK: - Day math

    /// Local calendar day key, e.g. "2026-08-09".
    private static func dayKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: Date())
    }

    /// Whole days elapsed since the app's launch day (2026-08-09), using a fixed UTC calendar.
    private static func daysSinceLaunchBase() -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let base = calendar.date(from: DateComponents(year: 2026, month: 8, day: 9))!
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: base), to: calendar.startOfDay(for: Date())).day ?? 0
        return days
    }


    private static func formattedUpdateTime() -> String {
        var components = DateComponents()
        components.hour = UserDefaults.standard.integer(forKey: "updateHour")
        components.minute = UserDefaults.standard.integer(forKey: "updateMinute")
        let date = Calendar.current.date(from: components) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }
}
