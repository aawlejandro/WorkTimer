import Foundation
import Observation

// All timer states the UI needs to react to.
enum TimerState {
    case idle
    case running
    case paused
    case completed
}

// Observable class — SwiftUI views re-render automatically when properties change.
// Marked @MainActor so UI updates always happen on the main thread.
@MainActor
@Observable
final class TimerViewModel {

    // MARK: - User-configurable inputs

    var taskLabel: String = ""
    /// Duration chosen before starting, in minutes.
    var selectedMinutes: Int = 25

    // MARK: - Runtime state

    var state: TimerState = .idle
    /// Seconds remaining in the current run.
    var secondsRemaining: Int = 0

    // Set to true when the timer reaches zero on its own.
    // ContentView observes this to persist the session.
    var didAutoComplete: Bool = false

    // Total seconds when the timer was started — needed to compute elapsed time on save.
    private var totalSeconds: Int = 0
    private var timerTask: Task<Void, Never>?

    // MARK: - Derived display helpers

    var displayTime: String {
        let m = secondsRemaining / 60
        let s = secondsRemaining % 60
        return String(format: "%02d:%02d", m, s)
    }

    /// 0…1 progress for the circular arc (goes from 1 → 0 as time elapses).
    var progress: Double {
        guard totalSeconds > 0 else { return 1 }
        return Double(secondsRemaining) / Double(totalSeconds)
    }

    // MARK: - Actions

    func start() {
        totalSeconds = selectedMinutes * 60
        secondsRemaining = totalSeconds
        state = .running
        scheduleTimer()
    }

    func pause() {
        guard state == .running else { return }
        state = .paused
        timerTask?.cancel()
        timerTask = nil
    }

    func resume() {
        guard state == .paused else { return }
        state = .running
        scheduleTimer()
    }

    func reset() {
        timerTask?.cancel()
        timerTask = nil
        state = .idle
        secondsRemaining = 0
        totalSeconds = 0
    }

    // Returns the elapsed seconds so the caller can persist a WorkSession.
    func complete() -> Int {
        timerTask?.cancel()
        timerTask = nil
        state = .completed
        let elapsed = totalSeconds - secondsRemaining
        return elapsed > 0 ? elapsed : totalSeconds
    }

    // MARK: - Private

    // Async loop that ticks every second on MainActor — no Sendable issues.
    private func scheduleTimer() {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self else { return }
                if self.secondsRemaining > 0 {
                    self.secondsRemaining -= 1
                    if self.secondsRemaining == 0 {
                        _ = self.complete()
                        self.didAutoComplete = true
                    }
                }
            }
        }
    }
}
