//
//  CameraManager.swift
//  MoodMirror
//
//  AVFoundation camera manager for capturing selfies
//

import AVFoundation
import UIKit
import SwiftUI
import Combine

/// Errors that can occur during camera operations
enum CameraError: Error, LocalizedError {
    case notAuthorized
    case deviceNotAvailable
    case captureError(Error)
    case sessionConfigurationFailed
    case simulatorNotSupported
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Camera access is required. Please enable it in Settings."
        case .deviceNotAvailable:
            return "Camera is not available on this device."
        case .captureError(let error):
            return "Failed to capture photo: \(error.localizedDescription)"
        case .sessionConfigurationFailed:
            return "Failed to configure camera session."
        case .simulatorNotSupported:
            return "Camera is not supported on the iOS Simulator. Please test on a real device."
        }
    }
}

/// Simple camera manager - all session work on dedicated queue
final class CameraManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var isAuthorized = false
    @Published var capturedImage: UIImage?
    @Published var isSessionRunning = false
    @Published var error: CameraError?
    @Published var isConfigured = false
    
    // MARK: - Session Properties (accessed only on sessionQueue)
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var videoDeviceInput: AVCaptureDeviceInput?
    
    // MARK: - Threading
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    
    // MARK: - Computed Properties
    var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    override init() {
        super.init()
    }
    
    // MARK: - Public Methods
    
    /// Main entry point - checks permission, configures, and starts session
    func start() {
        // Simulator check
        if isSimulator {
            DispatchQueue.main.async {
                self.error = .simulatorNotSupported
            }
            return
        }
        
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            DispatchQueue.main.async { self.isAuthorized = true }
            configureAndStart()
            
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.isAuthorized = granted
                    if !granted {
                        self.error = .notAuthorized
                    }
                }
                if granted {
                    self.configureAndStart()
                }
            }
            
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.isAuthorized = false
                self.error = .notAuthorized
            }
            
        @unknown default:
            DispatchQueue.main.async {
                self.isAuthorized = false
            }
        }
    }
    
    /// Configure and start in one sequential operation
    private func configureAndStart() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Skip if already configured
            guard !self.session.isRunning else {
                DispatchQueue.main.async {
                    self.isSessionRunning = true
                    self.isConfigured = true
                }
                return
            }
            
            // Configure session
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo
            
            // Get front camera
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
                self.session.commitConfiguration()
                DispatchQueue.main.async { self.error = .deviceNotAvailable }
                return
            }
            
            do {
                let videoInput = try AVCaptureDeviceInput(device: videoDevice)
                
                if self.session.canAddInput(videoInput) {
                    self.session.addInput(videoInput)
                    self.videoDeviceInput = videoInput
                } else {
                    self.session.commitConfiguration()
                    DispatchQueue.main.async { self.error = .sessionConfigurationFailed }
                    return
                }
                
                // Add photo output
                if self.session.canAddOutput(self.photoOutput) {
                    self.session.addOutput(self.photoOutput)
                    
                    // Mirror front camera
                    if let connection = self.photoOutput.connection(with: .video) {
                        if connection.isVideoMirroringSupported {
                            connection.isVideoMirrored = true
                        }
                    }
                } else {
                    self.session.commitConfiguration()
                    DispatchQueue.main.async { self.error = .sessionConfigurationFailed }
                    return
                }
                
                self.session.commitConfiguration()
                
                // Set configured flag and wait for UI to update before starting
                DispatchQueue.main.sync {
                    self.isConfigured = true
                }
                
                // Small delay to let preview layer attach
                Thread.sleep(forTimeInterval: 0.1)
                
                // Now start the session (still on sessionQueue)
                self.session.startRunning()
                
                let running = self.session.isRunning
                DispatchQueue.main.async {
                    self.isSessionRunning = running
                }
                
            } catch {
                self.session.commitConfiguration()
                DispatchQueue.main.async { self.error = .sessionConfigurationFailed }
            }
        }
    }
    
    /// Stop the capture session
    func stop() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            if self.session.isRunning {
                self.session.stopRunning()
            }
            
            DispatchQueue.main.async {
                self.isSessionRunning = false
            }
        }
    }
    
    /// Capture a photo
    func capturePhoto() {
        if isSimulator {
            DispatchQueue.main.async { self.error = .simulatorNotSupported }
            return
        }
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            let settings = AVCapturePhotoSettings()
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                self.error = .captureError(error)
            }
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            return
        }
        
        DispatchQueue.main.async {
            self.capturedImage = image
        }
    }
}
