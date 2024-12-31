import UIKit
import AVFoundation
import CoreVideo

public protocol VideoCaptureDelegate: AnyObject {
    func videoCapture(_ capture: VideoCapture, didCaptureVideoFrame: CVPixelBuffer?, timestamp: CMTime)
}

public class VideoCapture: NSObject {
    public var previewLayer: AVCaptureVideoPreviewLayer?
    public weak var delegate: VideoCaptureDelegate?
    var captureDevice: AVCaptureDevice?
    public var fps = 120 // Increased FPS
    
    var currentZoomFactor: CGFloat = 1.0
    let captureSession = AVCaptureSession()
    let videoOutput = AVCaptureVideoDataOutput()
    let queue = DispatchQueue(label: "com.highquality.camera-queue", qos: .userInteractive)
    
    var lastTimestamp = CMTime()
    
    public var isTorchEnabled: Bool = false
    public var isFlipCameraEnabled: Bool = true
    
    public func setUp(sessionPreset: AVCaptureSession.Preset = .hd4K3840x2160,
                      completion: @escaping (Bool) -> Void) {
        self.setUpCamera(sessionPreset: sessionPreset, completion: { success in
            completion(success)
        })
    }
    
    func setUpCamera(sessionPreset: AVCaptureSession.Preset, completion: @escaping (_ success: Bool) -> Void) {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = sessionPreset
        
        guard let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("Error: no video devices available")
            completion(false)
            return
        }
        self.captureDevice = captureDevice
        
        do {
            try captureDevice.lockForConfiguration()
            
            // Set highest frame rate available
            let formats = captureDevice.formats
            let maxFrameRate = formats.max { $0.videoSupportedFrameRateRanges[0].maxFrameRate < $1.videoSupportedFrameRateRanges[0].maxFrameRate }
            if let maxFormat = maxFrameRate {
                captureDevice.activeFormat = maxFormat
                captureDevice.activeVideoMinFrameDuration = CMTime(value: 1, timescale: Int32(fps))
                captureDevice.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: Int32(fps))
            }
            
            // Configure exposure
//            if captureDevice.isExposureModeSupported(.autoExpose) {
//                captureDevice.exposureMode = .autoExpose
//                let duration = CMTime(value: 1, timescale: 30) // Adjust as needed
//                let iso = AVCaptureDevice.currentISO
//                captureDevice.setExposureModeCustom(duration: duration, iso: iso, completionHandler: nil)
//            }
//            
//            // Configure white balance
//            if captureDevice.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
//                captureDevice.whiteBalanceMode = .continuousAutoWhiteBalance
//            }
            
            // Configure focus
            if captureDevice.isFocusModeSupported(.continuousAutoFocus) {
                captureDevice.focusMode = .continuousAutoFocus
            }
            
            // Optional: Enhance quality for low light (if supported)
            if captureDevice.isLowLightBoostSupported {
                let maxISO = captureDevice.activeFormat.maxISO
                let targetISO = min(maxISO, AVCaptureDevice.currentISO * 2)
                captureDevice.setExposureModeCustom(duration: captureDevice.exposureDuration, iso: targetISO, completionHandler: nil)
            }
            
            captureDevice.unlockForConfiguration()
        } catch {
            print("Error: Could not configure camera settings")
            completion(false)
            return
        }
        
        guard let videoInput = try? AVCaptureDeviceInput(device: captureDevice) else {
            print("Error: could not create AVCaptureDeviceInput")
            completion(false)
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        previewLayer.connection?.videoOrientation = .portrait
        self.previewLayer = previewLayer
        
        let settings: [String : Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32BGRA),
        ]
        
        videoOutput.videoSettings = settings
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        videoOutput.connection(with: AVMediaType.video)?.videoOrientation = .portrait
        
        captureSession.commitConfiguration()
        
        completion(true)
    }



    
    public func start() {
        if !captureSession.isRunning {
            captureSession.startRunning()
        }
    }
    
    public func stop() {
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }
    
    public func updateZoomFactor(scale: CGFloat) {
        guard let device = captureDevice else { return }
        do {
            try device.lockForConfiguration()
            
            // Smooth zoom animation
            let newZoomFactor = min(max(currentZoomFactor * scale, 1.0), device.activeFormat.videoMaxZoomFactor)
            device.videoZoomFactor = newZoomFactor
            currentZoomFactor = newZoomFactor
            
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Failed to update zoom factor: \(error)")
        }
    }
    
    func updateFocusAndExposure(at point: CGPoint) {
        guard let device = captureDevice else { return }
        do {
            try device.lockForConfiguration()
            
            if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.autoFocus) {
                device.focusPointOfInterest = point
                device.focusMode = .autoFocus
            }
            
            if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.autoExpose) {
                device.exposurePointOfInterest = point
                device.exposureMode = .autoExpose
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Failed to update focus and exposure: \(error)")
        }
    }
    
    public func focusOnTap(at point: CGPoint) {
        guard let previewLayer = previewLayer else { return }
        let convertedPoint = previewLayer.captureDevicePointConverted(fromLayerPoint: point)
        updateFocusAndExposure(at: convertedPoint)
    }
    
    public func toggleTorch() {
        guard let device = captureDevice, device.hasTorch else { return }
        
        do {
            try device.lockForConfiguration()
            if device.torchMode == .on {
                device.torchMode = .off
                isTorchEnabled = false
            } else {
                try device.setTorchModeOn(level: 1.0)
                isTorchEnabled = true
            }
            device.unlockForConfiguration()
        } catch {
            print("Error toggling torch: \(error)")
        }
    }
    
    public func flipCamera() {
        guard isFlipCameraEnabled else { return }
        
        captureSession.beginConfiguration()
        
        guard let currentInput = captureSession.inputs.first as? AVCaptureDeviceInput else { return }
        captureSession.removeInput(currentInput)
        
        let newPosition: AVCaptureDevice.Position = currentInput.device.position == .back ? .front : .back
        guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition) else { return }
        
        do {
            let newInput = try AVCaptureDeviceInput(device: newDevice)
            if captureSession.canAddInput(newInput) {
                captureSession.addInput(newInput)
                self.captureDevice = newDevice
            }
        } catch {
            print("Error flipping camera: \(error)")
        }
        
        captureSession.commitConfiguration()
    }
    
    public func addOverlay(_ overlay: CALayer) {
        guard let previewLayer = previewLayer else { return }
        overlay.frame = previewLayer.bounds
        previewLayer.insertSublayer(overlay, at: 1)
    }
}

extension VideoCapture: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let deltaTime = timestamp - lastTimestamp
        if deltaTime >= CMTimeMake(value: 1, timescale: Int32(fps)) {
            lastTimestamp = timestamp
            let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
            delegate?.videoCapture(self, didCaptureVideoFrame: imageBuffer, timestamp: timestamp)
        }
    }
    
    public func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Optionally handle dropped frames
    }
}
