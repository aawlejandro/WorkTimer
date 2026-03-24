import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    // Fetch all sessions — we filter by today in the computed property
    // so the view stays correct even if the app crosses midnight.
    @Query(sort: \WorkSession.completedAt, order: .reverse)
    private var allSessions: [WorkSession]

    @State private var vm = TimerViewModel()
    @State private var showCompletedBanner = false
    @State private var bannerTask: Task<Void, Never>?
    @FocusState private var isTextFieldFocused: Bool

    // Filter sessions to today only, recalculated on every body evaluation.
    private var todaySessions: [WorkSession] {
        let startOfDay = Calendar.current.startOfDay(for: .now)
        return allSessions.filter { $0.completedAt >= startOfDay }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    timerSection
                    if !todaySessions.isEmpty {
                        historySection
                    }
                }
                .padding()
            }
            // Dismiss keyboard when tapping outside the text field.
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Work Timer")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                // Explicit keyboard dismiss button for iPad where the
                // software keyboard lacks a built-in dismiss key.
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isTextFieldFocused = false }
                }
            }
            .onChange(of: vm.didAutoComplete) { _, didComplete in
                guard didComplete else { return }
                vm.didAutoComplete = false
                // Timer reached zero — save the session automatically.
                saveAutoCompletedSession()
            }
        }
    }

    // MARK: - Timer section

    private var timerSection: some View {
        VStack(spacing: 24) {
            // Task label input — only editable while idle.
            TextField("What are you working on?", text: $vm.taskLabel)
                .font(.title3)
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.sentences)
                .submitLabel(.done)
                .focused($isTextFieldFocused)
                .disabled(vm.state != .idle)
                .padding(.horizontal)
                .onSubmit { isTextFieldFocused = false }

            // Duration picker — only when idle.
            if vm.state == .idle {
                durationPicker
            }

            // Circular progress ring + time display.
            ZStack {
                // Background track.
                Circle()
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 12)

                // Progress arc — animates smoothly on every tick.
                Circle()
                    .trim(from: 0, to: vm.progress)
                    .stroke(
                        ringColor,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: vm.progress)

                VStack(spacing: 4) {
                    Text(vm.state == .idle
                         ? String(format: "%02d:00", vm.selectedMinutes)
                         : vm.displayTime)
                        .font(.system(size: 56, weight: .thin, design: .monospaced))
                        .contentTransition(.numericText())
                    if vm.state != .idle {
                        Text(stateLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(1.5)
                    }
                }
            }
            .frame(width: 240, height: 240)

            // Completed banner
            if showCompletedBanner {
                Label("Session saved!", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                    .font(.subheadline.weight(.medium))
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Action buttons.
            controlButtons
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private var durationPicker: some View {
        HStack(spacing: 0) {
            Text("Duration")
                .foregroundStyle(.secondary)
            Spacer()
            Stepper(
                "\(vm.selectedMinutes) min",
                value: $vm.selectedMinutes,
                in: 1...240
            )
            .fixedSize()
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var controlButtons: some View {
        switch vm.state {
        case .idle:
            Button(action: {
                isTextFieldFocused = false
                vm.start()
            }) {
                Label("Start", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

        case .running:
            HStack(spacing: 16) {
                Button(action: { vm.pause() }) {
                    Label("Pause", systemImage: "pause.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button(action: saveSession) {
                    Label("Done", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.green)
            }

        case .paused:
            HStack(spacing: 16) {
                Button(action: { vm.resume() }) {
                    Label("Resume", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(action: saveSession) {
                    Label("Done", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(.green)
            }

        case .completed:
            Button(action: {
                vm.reset()
                vm.taskLabel = ""
            }) {
                Label("New Session", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    // MARK: - History section

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today")
                    .font(.headline)
                Spacer()
                Text(totalDurationToday)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)

            ForEach(todaySessions) { session in
                SessionRow(session: session) {
                    modelContext.delete(session)
                }
            }
        }
    }

    // MARK: - Helpers

    private var ringColor: Color {
        switch vm.state {
        case .idle, .running: return .accentColor
        case .paused: return .orange
        case .completed: return .green
        }
    }

    private var stateLabel: String {
        switch vm.state {
        case .idle: return ""
        case .running: return "Running"
        case .paused: return "Paused"
        case .completed: return "Done"
        }
    }

    private var totalDurationToday: String {
        let total = todaySessions.reduce(0) { $0 + $1.durationSeconds }
        let minutes = total / 60
        let hours = minutes / 60
        let remaining = minutes % 60
        if hours > 0 {
            return remaining > 0 ? "\(hours) h \(remaining) min total" : "\(hours) h total"
        }
        return "\(minutes) min total"
    }

    private func saveSession() {
        let elapsed = vm.complete()
        persistSession(elapsed: elapsed)
    }

    // Called when the timer reaches zero on its own — vm.complete() was
    // already called by the ViewModel, so we just need the elapsed time.
    private func saveAutoCompletedSession() {
        persistSession(elapsed: vm.selectedMinutes * 60)
    }

    private func persistSession(elapsed: Int) {
        guard elapsed > 0 else { return }
        let label = vm.taskLabel.trimmingCharacters(in: .whitespaces)
        let session = WorkSession(
            taskLabel: label.isEmpty ? "Untitled" : label,
            durationSeconds: elapsed
        )
        modelContext.insert(session)

        // Cancel any previous banner dismissal to avoid race conditions.
        bannerTask?.cancel()
        withAnimation {
            showCompletedBanner = true
        }
        bannerTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            withAnimation { showCompletedBanner = false }
            vm.reset()
            vm.taskLabel = ""
        }
    }
}

// MARK: - Session row

private struct SessionRow: View {
    let session: WorkSession
    let onDelete: () -> Void

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.taskLabel)
                    .font(.body)
                Text(Self.timeFormatter.string(from: session.completedAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(session.formattedDuration)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
