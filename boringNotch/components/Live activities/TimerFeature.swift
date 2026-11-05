//
//  TimerFeature.swift
//  boringNotch
//
//  A simple countdown timer: the manager (state + sound), the "Timer" tab
//  shown when the notch is open, and the small indicator shown next to the
//  notch while the notch is closed.
//
//  Note: the notch window can never become the key window, so there is no
//  keyboard input here. Custom times are set with the plus/minus buttons.
//

import AppKit
import Combine
import SwiftUI

// MARK: - Manager

@MainActor
final class TimerManager: ObservableObject {
    static let shared = TimerManager()

    enum Phase {
        case idle
        case running
        case paused
        case finished
    }

    @Published private(set) var phase: Phase = .idle
    /// Length of the current timer in seconds.
    @Published private(set) var totalSeconds: TimeInterval = 0
    /// Seconds left. Updated about once per second while running.
    @Published private(set) var remainingSeconds: TimeInterval = 0
    /// Goes up by one every time a timer finishes, so views can react once per finish.
    @Published private(set) var finishCount: Int = 0

    private var endDate: Date?
    private var tickCancellable: AnyCancellable?
    private var alertTask: Task<Void, Never>?

    /// True while a timer is running, paused or waiting to be dismissed.
    var isActive: Bool { phase != .idle }

    /// Fraction of the timer that is left: 1 right after the start, 0 when done.
    var fractionLeft: Double {
        guard totalSeconds > 0 else { return 0 }
        return min(1, max(0, remainingSeconds / totalSeconds))
    }

    private init() {}

    // MARK: Controls

    func start(seconds: TimeInterval) {
        guard seconds > 0 else { return }
        stopAlert()
        totalSeconds = seconds
        remainingSeconds = seconds
        endDate = Date().addingTimeInterval(seconds)
        phase = .running
        startTicking()
    }

    func pause() {
        guard phase == .running, let currentEnd = endDate else { return }
        remainingSeconds = max(0, currentEnd.timeIntervalSinceNow)
        endDate = nil
        stopTicking()
        phase = .paused
    }

    func resume() {
        guard phase == .paused, remainingSeconds > 0 else { return }
        endDate = Date().addingTimeInterval(remainingSeconds)
        phase = .running
        startTicking()
    }

    /// Stops a running or paused timer, or dismisses a finished one.
    func cancel() {
        stopTicking()
        stopAlert()
        endDate = nil
        remainingSeconds = 0
        totalSeconds = 0
        phase = .idle
    }

    // MARK: Ticking

    private func startTicking() {
        stopTicking()
        tickCancellable = Timer.publish(every: 0.2, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.tick()
                }
            }
    }

    private func stopTicking() {
        tickCancellable?.cancel()
        tickCancellable = nil
    }

    private func tick() {
        guard phase == .running, let currentEnd = endDate else { return }
        let left = currentEnd.timeIntervalSinceNow
        if left <= 0 {
            finish()
        } else if left.rounded(.up) != remainingSeconds.rounded(.up) {
            // Only publish when the displayed second changes, to keep redraws cheap.
            remainingSeconds = left
        }
    }

    private func finish() {
        stopTicking()
        endDate = nil
        remainingSeconds = 0
        phase = .finished
        finishCount += 1
        playAlert()
    }

    // MARK: Sound

    /// Plays the sound four times, 2.5 seconds apart, unless the timer is dismissed first.
    private func playAlert() {
        stopAlert()
        alertTask = Task { @MainActor in
            for round in 0..<4 {
                if Task.isCancelled { return }
                Self.playSound()
                if round < 3 {
                    try? await Task.sleep(for: .seconds(2.5))
                }
            }
        }
    }

    private func stopAlert() {
        alertTask?.cancel()
        alertTask = nil
    }

    private static func playSound() {
        if let sound = NSSound(named: NSSound.Name("Glass")) {
            sound.stop()
            sound.play()
        } else {
            NSSound.beep()
        }
    }

    // MARK: Formatting

    /// "09:42", or "1:09:42" when an hour or more is left.
    nonisolated static func clockString(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.up)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }
}

// MARK: - Closed notch indicator

enum TimerLayout {
    /// Width of the icon area (left) and the time area (right) beside the notch.
    static let sideWidth: CGFloat = 60
}

/// Small indicator shown while the notch is closed: icon on the left, time on the right.
struct TimerLiveActivity: View {
    let notchWidth: CGFloat
    let height: CGFloat

    @ObservedObject var timer = TimerManager.shared

    var body: some View {
        HStack {
            Image(systemName: iconName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: TimerLayout.sideWidth, alignment: .center)

            Rectangle()
                .fill(.black)
                .frame(width: notchWidth - cornerRadiusInsets.closed.top)

            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(tint)
                .frame(width: TimerLayout.sideWidth, alignment: .center)
        }
        .frame(height: height, alignment: .center)
    }

    private var iconName: String {
        switch timer.phase {
        case .paused: return "pause.fill"
        case .finished: return "bell.fill"
        default: return "timer"
        }
    }

    private var tint: Color {
        switch timer.phase {
        case .paused: return Color.gray
        case .finished: return Color.green
        default: return Color.white
        }
    }

    private var label: String {
        if timer.phase == .finished {
            return "Done"
        }
        return TimerManager.clockString(timer.remainingSeconds)
    }
}

// MARK: - Open notch tab

struct NotchTimerView: View {
    @ObservedObject var timer = TimerManager.shared

    @State private var showCustom = false
    @State private var customMinutes = 25
    @State private var customSeconds = 0

    private let presets = [5, 10, 15, 30]

    var body: some View {
        Group {
            switch timer.phase {
            case .idle:
                if showCustom {
                    customPicker
                } else {
                    presetPicker
                }
            case .running, .paused:
                runningView
            case .finished:
                finishedView
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.smooth(duration: 0.25), value: timer.phase)
        .animation(.smooth(duration: 0.25), value: showCustom)
    }

    // MARK: Idle: presets

    private var presetPicker: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                ForEach(presets, id: \.self) { minutes in
                    Button {
                        timer.start(seconds: TimeInterval(minutes * 60))
                    } label: {
                        VStack(spacing: 0) {
                            Text("\(minutes)")
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                            Text("min")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color.gray)
                        }
                        .frame(width: 72, height: 54)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.12))
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            Button {
                showCustom = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "slider.horizontal.3")
                    Text("Custom time")
                }
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 14)
                .frame(height: 28)
                .background(Capsule().fill(Color.white.opacity(0.12)))
                .contentShape(Capsule())
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    // MARK: Idle: custom time

    private var customPicker: some View {
        VStack(spacing: 10) {
            HStack(spacing: 22) {
                stepperRow(value: $customMinutes, unit: "min", range: 0...180, step: 1, bigStep: 5)
                stepperRow(value: $customSeconds, unit: "sec", range: 0...55, step: 5, bigStep: 15)
            }

            HStack(spacing: 10) {
                Button {
                    showCustom = false
                } label: {
                    pill("Back")
                }
                .buttonStyle(PlainButtonStyle())

                Button {
                    let total = customMinutes * 60 + customSeconds
                    if total > 0 {
                        timer.start(seconds: TimeInterval(total))
                        showCustom = false
                    }
                } label: {
                    pill("Start", prominent: true)
                }
                .buttonStyle(PlainButtonStyle())
                .opacity(customMinutes * 60 + customSeconds > 0 ? 1 : 0.4)
            }

            Text("Tip: hold ⌥ while clicking for bigger steps")
                .font(.system(size: 9))
                .foregroundStyle(Color.gray)
        }
    }

    private func stepperRow(
        value: Binding<Int>, unit: String, range: ClosedRange<Int>, step: Int, bigStep: Int
    ) -> some View {
        HStack(spacing: 8) {
            stepButton("minus") {
                adjust(value, direction: -1, step: step, bigStep: bigStep, range: range)
            }

            VStack(spacing: 0) {
                Text(String(format: "%02d", value.wrappedValue))
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(unit)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.gray)
            }
            .frame(width: 44)

            stepButton("plus") {
                adjust(value, direction: 1, step: step, bigStep: bigStep, range: range)
            }
        }
    }

    private func adjust(
        _ value: Binding<Int>, direction: Int, step: Int, bigStep: Int, range: ClosedRange<Int>
    ) {
        let amount = NSEvent.modifierFlags.contains(.option) ? bigStep : step
        let next = value.wrappedValue + direction * amount
        value.wrappedValue = min(range.upperBound, max(range.lowerBound, next))
    }

    private func stepButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .bold))
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.white.opacity(0.12)))
                .contentShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: Running / paused

    private var runningView: some View {
        HStack(spacing: 30) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: timer.fractionLeft)
                    .stroke(
                        timer.phase == .paused ? Color.gray : Color.accentColor,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: timer.remainingSeconds)
                Text(TimerManager.clockString(timer.remainingSeconds))
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 12)
            }
            .frame(width: 100, height: 100)

            HStack(spacing: 14) {
                roundButton(timer.phase == .paused ? "play.fill" : "pause.fill") {
                    if timer.phase == .paused {
                        timer.resume()
                    } else {
                        timer.pause()
                    }
                }
                roundButton("xmark") {
                    timer.cancel()
                }
            }
        }
    }

    private func roundButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 42, height: 42)
                .background(Circle().fill(Color.white.opacity(0.12)))
                .contentShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: Finished

    private var finishedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell.fill")
                .font(.system(size: 28))
                .foregroundStyle(Color.green)
            Text("Time's up")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
            Button {
                timer.cancel()
            } label: {
                pill("Done", prominent: true)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    // MARK: Shared

    private func pill(_ title: String, prominent: Bool = false) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 18)
            .frame(height: 28)
            .background(Capsule().fill(prominent ? Color.accentColor : Color.white.opacity(0.12)))
            .contentShape(Capsule())
    }
}
