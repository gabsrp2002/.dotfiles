#!/usr/bin/env swift
// Background CoreWLAN scanner loop for SketchyBar's Wi-Fi popup.
// NOTE: Must be executed via `swift wifi_scanner.swift` rather than compiled into an
// ad-hoc binary with `swiftc`, because macOS CoreWLAN redacts `n.ssid` to `nil` for
// binaries lacking Apple's `swift-frontend` signature/entitlements. Keeping the
// `while` loop inside this single Swift invocation avoids re-JITing on every 3s scan.

import Foundation
import CoreWLAN

let tracker = "/tmp/sketchybar_rift_popup_open"
let cache = "/tmp/sketchybar_wifi_scan.tsv"
let script = ProcessInfo.processInfo.environment["SCRIPT_PATH"] ?? ""

func isWifiPopupOpen() -> Bool {
    guard let s = try? String(contentsOfFile: tracker, encoding: .utf8) else { return false }
    return s.trimmingCharacters(in: .whitespacesAndNewlines) == "wifi"
}

while isWifiPopupOpen() {
    if let iface = CWWiFiClient.shared().interface(),
       let nets = try? iface.scanForNetworks(withName: nil) {
        var best: [String: (Int, Bool)] = [:]
        for n in nets {
            guard let s = n.ssid, !s.isEmpty else { continue }
            let r = n.rssiValue
            guard r >= -86 && r < 0 else { continue }
            let o = n.supportsSecurity(.none)
            if best[s] == nil || r > best[s]!.0 {
                best[s] = (r, o)
            }
        }
        var lines = ""
        for (s, info) in best.sorted(by: { $0.value.0 > $1.value.0 }) {
            lines += "\(s)\t\(info.0)\t\(info.1 ? 1 : 0)\n"
        }
        if !lines.isEmpty && isWifiPopupOpen() {
            try? lines.write(toFile: cache, atomically: true, encoding: .utf8)
            if !script.isEmpty {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: script)
                p.arguments = ["render_once"]
                try? p.run()
                p.waitUntilExit()
            }
        }
    }
    Thread.sleep(forTimeInterval: 3.0)
}
