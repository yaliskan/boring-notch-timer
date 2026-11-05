//
//  DeviceBatteryFeature.swift
//  boringNotch
//
//  Battery levels of connected Bluetooth accessories (AirPods, Magic Keyboard,
//  Magic Mouse, Magic Trackpad, Beats, game controllers, ...), shown in the
//  "System" tab next to the CPU / RAM gauges.
//
//  How it works, and why it needs no permission:
//  macOS publishes battery information for connected accessories in the
//  IORegistry (the same data System Settings > Bluetooth shows). This file
//  reads those entries with the public IOKit API. It never opens a Bluetooth
//  connection, never scans for devices and never uses CoreBluetooth or
//  IOBluetooth, so no Bluetooth permission or entitlement is involved.
//  Only accessories that report their battery to macOS appear here; iPhones
//  and iPads do not (macOS offers no public API for that).
//
//  Read-only and local: no network, no files, no logging.
//

import Defaults
import IOKit
import SwiftUI

// MARK: - Model

struct BluetoothDeviceBattery: Identifiable, Equatable {
    struct Level: Equatable {
        let label: String   // "", "L", "R" or "Case"
        let percent: Int
    }

    let id: String
    let name: String
    let symbol: String
    let levels: [Level]

    /// Lowest level, used for sorting and for the summary colour.
    var minimumPercent: Int { levels.map(\.percent).min() ?? 0 }
}

// MARK: - Reader

@MainActor
final class DeviceBatteryMonitor: ObservableObject {
    static let shared = DeviceBatteryMonitor()

    @Published private(set) var devices: [BluetoothDeviceBattery] = []

    private var observers = 0
    private var timer: Timer?

    private init() {}

    func beginObserving() {
        observers += 1
        if observers == 1 {
            refresh()
            // Battery levels change slowly; every 10 s is plenty.
            timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            }
        }
    }

    func endObserving() {
        observers = max(0, observers - 1)
        if observers == 0 {
            timer?.invalidate()
            timer = nil
        }
    }

    func refresh() {
        let found = Self.readDevices()
        if found != devices {
            devices = found
        }
    }

    // MARK: IORegistry

    nonisolated private static let serviceClass = "AppleDeviceManagementHIDEventService"

    nonisolated private static func readDevices() -> [BluetoothDeviceBattery] {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching(serviceClass), &iterator) == KERN_SUCCESS else {
            return []
        }
        defer { IOObjectRelease(iterator) }

        var result: [BluetoothDeviceBattery] = []
        var seen = Set<String>()

        var entry = IOIteratorNext(iterator)
        while entry != 0 {
            defer {
                IOObjectRelease(entry)
                entry = IOIteratorNext(iterator)
            }

            var unmanaged: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(entry, &unmanaged, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                  let properties = unmanaged?.takeRetainedValue() as? [String: Any]
            else { continue }

            // Only wireless accessories: skip the built-in keyboard/trackpad and wired devices.
            let transport = properties["Transport"] as? String ?? ""
            let isBluetooth = transport == "Bluetooth" || (properties["BluetoothDevice"] as? Bool ?? false)
            guard isBluetooth else { continue }

            var levels: [BluetoothDeviceBattery.Level] = []
            if let left = percent(properties["BatteryPercentLeft"]) { levels.append(.init(label: "L", percent: left)) }
            if let right = percent(properties["BatteryPercentRight"]) { levels.append(.init(label: "R", percent: right)) }
            if let box = percent(properties["BatteryPercentCase"]) { levels.append(.init(label: "Case", percent: box)) }
            if levels.isEmpty, let single = percent(properties["BatteryPercent"]) {
                levels.append(.init(label: "", percent: single))
            }
            guard !levels.isEmpty else { continue }

            let address = properties["DeviceAddress"] as? String
                ?? properties["SerialNumber"] as? String
                ?? UUID().uuidString
            guard !seen.contains(address) else { continue }
            seen.insert(address)

            let rawName = (properties["Product"] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
            let name = rawName.isEmpty ? "Bluetooth device" : rawName

            result.append(
                BluetoothDeviceBattery(
                    id: address,
                    name: name,
                    symbol: symbol(for: name, properties: properties),
                    levels: levels
                )
            )
        }

        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    nonisolated private static func percent(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber else { return nil }
        let level = number.intValue
        // Some drivers report 0 or values > 100 while a reading is unavailable.
        guard (1...100).contains(level) else { return nil }
        return level
    }

    nonisolated private static func symbol(for name: String, properties: [String: Any]) -> String {
        let lower = name.lowercased()
        if lower.contains("airpods max") { return "airpodsmax" }
        if lower.contains("airpods pro") { return "airpodspro" }
        if lower.contains("airpods") { return "airpods" }
        if lower.contains("beats") { return "beats.headphones" }
        if lower.contains("keyboard") { return "keyboard" }
        if lower.contains("mouse") { return "magicmouse" }
        if lower.contains("trackpad") { return "rectangle.and.hand.point.up.left.fill" }
        if lower.contains("controller") || lower.contains("gamepad") { return "gamecontroller" }
        if lower.contains("headphone") || lower.contains("headset") || lower.contains("buds") { return "headphones" }
        if properties["BatteryPercentLeft"] != nil || properties["BatteryPercentCase"] != nil { return "airpods" }
        return "dot.radiowaves.left.and.right"
    }
}

// MARK: - View

/// The device list shown in the System tab.
struct DeviceBatteryListView: View {
    @ObservedObject var monitor = DeviceBatteryMonitor.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "wave.3.right")
                    .font(.system(size: 10, weight: .semibold))
                Text("Bluetooth devices")
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
            }
            .foregroundStyle(Color.gray)

            if monitor.devices.isEmpty {
                VStack(spacing: 4) {
                    Image(systemName: "wave.3.right.circle")
                        .font(.system(size: 20))
                    Text("No connected devices report a battery level")
                        .font(.system(size: 10))
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(Color.gray)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical) {
                    VStack(spacing: 6) {
                        ForEach(monitor.devices) { device in
                            deviceRow(device)
                        }
                    }
                }
                .scrollIndicators(.never)
            }
        }
        .onAppear { monitor.beginObserving() }
        .onDisappear { monitor.endObserving() }
    }

    private func deviceRow(_ device: BluetoothDeviceBattery) -> some View {
        HStack(spacing: 10) {
            Image(systemName: device.symbol)
                .font(.system(size: 15))
                .frame(width: 22)

            Text(device.name)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 6)

            HStack(spacing: 8) {
                ForEach(device.levels, id: \.label) { level in
                    HStack(spacing: 3) {
                        if !level.label.isEmpty {
                            Text(level.label)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(Color.gray)
                        }
                        // Same battery glyph the app already uses for the Mac's own battery.
                        BatteryView(
                            levelBattery: Float(level.percent),
                            isPluggedIn: false,
                            isCharging: false,
                            isInLowPowerMode: false,
                            batteryWidth: 22,
                            isForNotification: false
                        )
                        Text("\(level.percent)%")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }
}
