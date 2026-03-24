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

    // Local text state — avoids binding through @MainActor @Observable
    // which can drop keystrokes from external keyboards on iPad.
    @State private var taskText = ""

    // Filter sessions to today only, recalculated on every body evaluation.
    private var todaySessions: [WorkSession] {
        let startOfDay = Calendar.current.startOfDay(for: .now)
        return allSessions.filter { $0.completedAt >= startOfDay }
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 32) {
                        timerSection
                        historySection
                            .id("history")
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)
                .navigationTitle("Work Timer")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") { isTextFieldFocused = false }
                    }
                }
                .onChange(of: vm.didAutoComplete) { _, didComplete in
                    guard didComplete else { return }
                    vm.didAutoComplete = false
                    saveAutoCompletedSession()
                    withAnimation {
                        proxy.scrollTo("history", anchor: .top)
                    }
                }
            }
        }
    }

    // MARK: - Timer section

    private var timerSection: some View {
        VStack(spacing: 24) {
            // Task label — local @State avoids binding issues with
            // external keyboards that go through @MainActor @Observable.
            TextField("What are you working on?", text: $taskText)
                .font(.title3)
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled(false)
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
                Circle()
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 12)

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

            if showCompletedBanner {
                Label("Session saved!", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                    .font(.subheadline.weight(.medium))
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

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
            Button(action: resetToIdle) {
                Label("New Session", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    // MARK: - History section (always visible)

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Today", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                    .font(.headline)
                Spacer()
                if !todaySessions.isEmpty {
                    Text(totalDurationToday)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 4)

            if todaySessions.isEmpty {
                Text("Completed sessions will appear here.")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                ForEach(todaySessions) { session in
                    SessionRow(session: session) {
                        withAnimation {
                            modelContext.delete(session)
                        }
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
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

    private func saveAutoCompletedSession() {
        persistSession(elapsed: vm.selectedMinutes * 60)
    }

    private func persistSession(elapsed: Int) {
        guard elapsed > 0 else { return }
        let label = taskText.trimmingCharacters(in: .whitespaces)
        let session = WorkSession(
            taskLabel: label.isEmpty ? "Untitled" : label,
            durationSeconds: elapsed
        )
        modelContext.insert(session)

        bannerTask?.cancel()
        withAnimation {
            showCompletedBanner = true
        }
        bannerTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            withAnimation { showCompletedBanner = false }
            resetToIdle()
        }
    }

    private func resetToIdle() {
        vm.reset()
        taskText = ""
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
