//
//  SystemMonitorFeature.swift
//  boringNotch
//
//  A small, read-only CPU / memory monitor: the sampler (Mach host statistics),
//  the "System" tab shown when the notch is open, and an optional compact
//  indicator next to the closed notch (off by default).
//
//  Privacy/safety notes:
//  - Uses only public, local macOS APIs (host_statistics / host_statistics64).
//  - No network, no files, no logging, no new entitlements.
//  - Sampling runs only while something is actually showing the numbers.
//

import Darwin
import Defaults
import SwiftUI

extension Defaults.Keys {
    /// Show "CPU xx% / RAM x/y GB" next to the closed notch. Default: off.
    static let systemMonitorInClosedNotch = Key<Bool>("systemMonitorInClosedNotch", default: false)
}

// MARK: - Sampler

@MainActor
final class SystemMonitor: ObservableObject {
    static let shared = SystemMonitor()

    /// 0...1
    @Published private(set) var cpuUsage: Double = 0
    /// Bytes
    @Published private(set) var memoryUsed: UInt64 = 0
    /// Bytes
    @Published private(set) var memoryTotal: UInt64 = ProcessInfo.processInfo.physicalMemory

    var memoryFraction: Double {
        guard memoryTotal > 0 else { return 0 }
        return min(1, Double(memoryUsed) / Double(memoryTotal))
    }

    private var observers = 0
    private var timer: Timer?
    private var lastTicks: (busy: UInt64, total: UInt64)?

    private init() {}

    // Views call these from onAppear / onDisappear. Sampling only runs while
    // at least one view is visible.
    func beginObserving() {
        observers += 1
        if observers == 1 {
            sample()
            timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.sample() }
            }
        }
    }

    func endObserving() {
        observers = max(0, observers - 1)
        if observers == 0 {
            timer?.invalidate()
            timer = nil
            lastTicks = nil
        }
    }

    private func sample() {
        sampleCPU()
        sampleMemory()
    }

    private func sampleCPU() {
        var info = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, reboundPointer, &count)
            }
        }
        guard result == KERN_SUCCESS else { return }

        let user = UInt64(info.cpu_ticks.0)
        let system = UInt64(info.cpu_ticks.1)
        let idle = UInt64(info.cpu_ticks.2)
        let nice = UInt64(info.cpu_ticks.3)
        let busy = user + system + nice
        let total = busy + idle

        if let last = lastTicks, total > last.total {
            let deltaBusy = Double(busy - last.busy)
            let deltaTotal = Double(total - last.total)
            cpuUsage = min(1, max(0, deltaBusy / deltaTotal))
        }
        lastTicks = (busy, total)
    }

    private func sampleMemory() {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, reboundPointer, &count)
            }
        }
        guard result == KERN_SUCCESS else { return }

        let pageSize = UInt64(vm_kernel_page_size)
        // Same idea as Activity Monitor's "Memory Used": app memory + wired + compressed.
        let appPages = UInt64(max(0, Int64(stats.internal_page_count) - Int64(stats.purgeable_count)))
        let usedPages = appPages + UInt64(stats.wire_count) + UInt64(stats.compressor_page_count)
        memoryUsed = usedPages * pageSize
        memoryTotal = ProcessInfo.processInfo.physicalMemory
    }

    // MARK: Formatting

    nonisolated static func gigabytes(_ bytes: UInt64, decimals: Int = 1) -> String {
        let value = Double(bytes) / 1_073_741_824
        return String(format: "%.\(decimals)f", value)
    }

    nonisolated static func percent(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded()))%"
    }
}

// MARK: - Closed notch indicator

enum SystemMonitorLayout {
    static let sideWidth: CGFloat = 74
}

/// Compact indicator next to the closed notch: CPU on the left, RAM on the right.
struct SystemMonitorLiveActivity: View {
    let notchWidth: CGFloat
    let height: CGFloat

    @ObservedObject var monitor = SystemMonitor.shared

    var body: some View {
        HStack {
            HStack(spacing: 4) {
                Image(systemName: "cpu")
                    .font(.system(size: 11, weight: .semibold))
                Text(SystemMonitor.percent(monitor.cpuUsage))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            .frame(width: SystemMonitorLayout.sideWidth, alignment: .center)

            Rectangle()
                .fill(.black)
                .frame(width: notchWidth - cornerRadiusInsets.closed.top)

            HStack(spacing: 4) {
                Image(systemName: "memorychip")
                    .font(.system(size: 11, weight: .semibold))
                Text("\(SystemMonitor.gigabytes(monitor.memoryUsed, decimals: 0))/\(SystemMonitor.gigabytes(monitor.memoryTotal, decimals: 0))")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            .frame(width: SystemMonitorLayout.sideWidth, alignment: .center)
        }
        .foregroundStyle(.white)
        .lineLimit(1)
        .frame(height: height, alignment: .center)
        .onAppear { monitor.beginObserving() }
        .onDisappear { monitor.endObserving() }
    }
}

// MARK: - Open notch tab

struct NotchSystemView: View {
    @ObservedObject var monitor = SystemMonitor.shared
    @Default(.systemMonitorInClosedNotch) private var showInClosedNotch

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(spacing: 10) {
                HStack(spacing: 18) {
                    gauge(
                        title: "CPU",
                        fraction: monitor.cpuUsage,
                        value: SystemMonitor.percent(monitor.cpuUsage),
                        detail: "\(ProcessInfo.processInfo.activeProcessorCount) cores",
                        tint: tint(for: monitor.cpuUsage)
                    )
                    gauge(
                        title: "RAM",
                        fraction: monitor.memoryFraction,
                        value: SystemMonitor.percent(monitor.memoryFraction),
                        detail: "\(SystemMonitor.gigabytes(monitor.memoryUsed)) / \(SystemMonitor.gigabytes(monitor.memoryTotal, decimals: 0)) GB",
                        tint: tint(for: monitor.memoryFraction)
                    )
                }

                Toggle(isOn: $showInClosedNotch) {
                    Text("Show next to closed notch")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.gray)
                }
                .toggleStyle(.switch)
                .controlSize(.mini)
                .tint(Color.accentColor)
            }
            .frame(width: 250)

            DeviceBatteryListView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { monitor.beginObserving() }
        .onDisappear { monitor.endObserving() }
    }

    private func tint(for fraction: Double) -> Color {
        if fraction >= 0.9 { return .red }
        if fraction >= 0.7 { return .orange }
        return Color.accentColor
    }

    private func gauge(title: String, fraction: Double, value: String, detail: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: max(0.001, fraction))
                    .stroke(tint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.smooth(duration: 0.6), value: fraction)
                VStack(spacing: 0) {
                    Text(value)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text(title)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color.gray)
                }
            }
            .frame(width: 76, height: 76)

            Text(detail)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.gray)
                .lineLimit(1)
        }
        .frame(width: 110)
    }
}
