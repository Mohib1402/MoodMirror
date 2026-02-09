//
//  CameraView.swift
//  MoodMirror
//
//  SwiftUI camera view for capturing selfies
//

import SwiftUI
import AVFoundation

/// Camera view with preview and capture button
struct CameraView: View {
    @StateObject private var cameraManager = CameraManager()
    @State private var hasStartedCamera = false
    
    let onCapture: (UIImage) -> Void
    let onCancel: () -> Void
    
    init(onCapture: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void = {}) {
        self.onCapture = onCapture
        self.onCancel = onCancel
    }
    
    var body: some View {
        ZStack {
            // Camera preview background
            Color.black.ignoresSafeArea()
            
            // Only show preview after session is configured
            if cameraManager.isConfigured {
                CameraPreviewView(session: cameraManager.session)
                    .ignoresSafeArea()
            }
            
            // Overlay UI
            VStack {
                // Top bar
                HStack {
                    Button {
                        onCancel()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    
                    Spacer()
                }
                .padding()
                
                Spacer()
                
                // Error or loading state
                if !cameraManager.isSessionRunning {
                    VStack(spacing: 16) {
                        if let error = cameraManager.error {
                            Text(error.localizedDescription)
                                .font(.body)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding()
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                            
                            if case .notAuthorized = error {
                                Button("Open Settings") {
                                    if let url = URL(string: UIApplication.openSettingsURLString) {
                                        UIApplication.shared.open(url)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        } else if hasStartedCamera {
                            ProgressView()
                                .tint(.white)
                            Text("Starting camera...")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    }
                    .padding()
                }
                
                Spacer()
                
                // Capture button
                if cameraManager.isSessionRunning {
                    VStack(spacing: 16) {
                        Text("Position your face in the frame")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                        
                        Button {
                            HapticManager.shared.mediumImpact()
                            cameraManager.capturePhoto()
                        } label: {
                            Circle()
                                .strokeBorder(.white, lineWidth: 3)
                                .frame(width: 70, height: 70)
                                .overlay(
                                    Circle()
                                        .fill(.white)
                                        .frame(width: 60, height: 60)
                                )
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            hasStartedCamera = true
            cameraManager.start()
        }
        .onDisappear {
            cameraManager.stop()
        }
        .onChange(of: cameraManager.capturedImage) { oldValue, newValue in
            if let image = newValue {
                onCapture(image)
            }
        }
    }
}

/// UIViewRepresentable that displays camera preview
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        view.backgroundColor = .black
        return view
    }
    
    func updateUIView(_ uiView: VideoPreviewView, context: Context) {
        // Session is already set
    }
}

/// Custom UIView that uses AVCaptureVideoPreviewLayer as its layer
class VideoPreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}

// MARK: - Preview

#Preview {
    CameraView { image in
        print("Captured image: \(image.size)")
    }
}
