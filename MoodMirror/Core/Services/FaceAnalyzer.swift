//
//  FaceAnalyzer.swift
//  MoodMirror
//
//  Vision framework face detection and analysis
//

import Vision
import UIKit

/// Errors that can occur during face analysis
enum FaceAnalysisError: Error, LocalizedError {
    case noFaceDetected
    case multipleFacesDetected
    case imageProcessingFailed
    case analysisError(Error)
    
    var errorDescription: String? {
        switch self {
        case .noFaceDetected:
            return "No face detected in the image. Please ensure your face is clearly visible."
        case .multipleFacesDetected:
            return "Multiple faces detected. Please ensure only your face is in the frame."
        case .imageProcessingFailed:
            return "Failed to process the image."
        case .analysisError(let error):
            return "Face analysis failed: \(error.localizedDescription)"
        }
    }
}

/// Result of face analysis
struct FaceAnalysisResult {
    let faceDescription: String
    let confidence: Float
    let croppedFaceImage: UIImage
    let boundingBox: CGRect
}

/// Face analyzer using Vision framework
final class FaceAnalyzer {
    
    /// Analyze face in image and return description
    func analyzeFace(in image: UIImage) async throws -> FaceAnalysisResult {
        guard let cgImage = image.cgImage else {
            throw FaceAnalysisError.imageProcessingFailed
        }
        
        // Create face detection request
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
            throw FaceAnalysisError.analysisError(error)
        }
        
        // Get results
        guard let results = request.results, !results.isEmpty else {
            throw FaceAnalysisError.noFaceDetected
        }
        
        // Ensure only one face
        guard results.count == 1 else {
            throw FaceAnalysisError.multipleFacesDetected
        }
        
        let faceObservation = results[0]
        
        // Get face bounding box
        let boundingBox = faceObservation.boundingBox
        
        // Convert normalized rect to image coordinates
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        let faceRect = VNImageRectForNormalizedRect(boundingBox, Int(imageSize.width), Int(imageSize.height))
        
        // Crop face from image
        guard let croppedCGImage = cgImage.cropping(to: faceRect) else {
            throw FaceAnalysisError.imageProcessingFailed
        }
        let croppedImage = UIImage(cgImage: croppedCGImage)
        
        // Generate face description for Gemini
        let description = generateFaceDescription(from: faceObservation, imageSize: imageSize)
        
        return FaceAnalysisResult(
            faceDescription: description,
            confidence: faceObservation.confidence,
            croppedFaceImage: croppedImage,
            boundingBox: faceRect
        )
    }
    
    /// Generate natural language description of face for Gemini
    private func generateFaceDescription(from observation: VNFaceObservation, imageSize: CGSize) -> String {
        let boundingBox = observation.boundingBox
        
        // Calculate face size relative to image
        let faceArea = boundingBox.width * boundingBox.height
        let imageArea: CGFloat = 1.0 // normalized coordinates
        let faceRatio = faceArea / imageArea
        
        // Determine face size description
        let sizeDescription: String
        if faceRatio > 0.3 {
            sizeDescription = "close-up"
        } else if faceRatio > 0.15 {
            sizeDescription = "medium distance"
        } else {
            sizeDescription = "far away"
        }
        
        // Determine face position
        let centerX = boundingBox.midX
        let centerY = boundingBox.midY
        
        let horizontalPosition: String
        if centerX < 0.4 {
            horizontalPosition = "left side"
        } else if centerX > 0.6 {
            horizontalPosition = "right side"
        } else {
            horizontalPosition = "center"
        }
        
        let verticalPosition: String
        if centerY < 0.4 {
            verticalPosition = "lower"
        } else if centerY > 0.6 {
            verticalPosition = "upper"
        } else {
            verticalPosition = "middle"
        }
        
        // Build description
        var description = "Face detected at \(sizeDescription)"
        
        if horizontalPosition != "center" || verticalPosition != "middle" {
            description += " in the \(verticalPosition) \(horizontalPosition) of frame"
        }
        
        description += ". Confidence: \(Int(observation.confidence * 100))%."
        
        return description
    }
    
    /// Prepare image for Gemini API (resize and compress)
    func prepareImageForAPI(_ image: UIImage, maxSizeKB: Int = 500) -> Data? {
        // Target size for API
        let targetSize = CGSize(width: 512, height: 512)
        
        // Resize image
        let resizedImage = resizeImage(image, to: targetSize)
        
        // Compress to JPEG with quality adjustment
        var compressionQuality: CGFloat = 0.8
        var imageData = resizedImage.jpegData(compressionQuality: compressionQuality)
        
        // Reduce quality until size is acceptable
        while let data = imageData, data.count > maxSizeKB * 1024, compressionQuality > 0.1 {
            compressionQuality -= 0.1
            imageData = resizedImage.jpegData(compressionQuality: compressionQuality)
        }
        
        return imageData
    }
    
    /// Resize image maintaining aspect ratio
    private func resizeImage(_ image: UIImage, to targetSize: CGSize) -> UIImage {
        let size = image.size
        
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        
        // Use the smaller ratio to maintain aspect ratio
        let scaleFactor = min(widthRatio, heightRatio)
        
        let scaledSize = CGSize(
            width: size.width * scaleFactor,
            height: size.height * scaleFactor
        )
        
        // Use scale 1.0 to avoid 2x/3x retina scaling
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        
        let renderer = UIGraphicsImageRenderer(size: scaledSize, format: format)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: scaledSize))
        }
        
        return resizedImage
    }
    
    /// Convert image to base64 string for API
    func imageToBase64(_ image: UIImage) -> String? {
        guard let imageData = prepareImageForAPI(image) else {
            return nil
        }
        return imageData.base64EncodedString()
    }
}
