//
//  WebcamManager.swift
//  boringNotch
//
//  Camera-free build: the mirror feature has been removed on purpose.
//  This stub keeps the same public shape as the original manager so the rest
//  of the app compiles, but it never touches AVCaptureDevice, never asks for
//  camera permission and never starts a capture session. The app's
//  entitlements no longer include camera access either.
//

import AVFoundation
import SwiftUI

class WebcamManager: NSObject, ObservableObject {
    static let shared = WebcamManager()

    /// Always nil: there is no capture session in this build.
    @Published private(set) var previewLayer: AVCaptureVideoPreviewLayer? = nil
    /// Always false.
    @Published private(set) var isSessionRunning: Bool = false
    /// Stays `.notDetermined` so no "access denied" alerts are shown anywhere.
    @Published private(set) var authorizationStatus: AVAuthorizationStatus = .notDetermined
    /// Always false, which hides every camera-related control in the UI.
    @Published private(set) var cameraAvailable: Bool = false

    private override init() {
        super.init()
    }

    func checkAndRequestVideoAuthorization() {
        // Intentionally does nothing: no camera permission is ever requested.
    }

    func checkCameraAvailability() {
        cameraAvailable = false
    }

    func startSession() {
        // Intentionally does nothing.
    }

    func stopSession() {
        // Intentionally does nothing.
    }
}
