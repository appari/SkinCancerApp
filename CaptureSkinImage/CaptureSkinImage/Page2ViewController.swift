import UIKit
import Vision
import CoreMedia
import Foundation
import Photos

extension CGPoint {
    func scaled(to imageSize: CGSize) -> CGPoint {
        // Ensure the coordinates are scaled relative to the image's width and height
        return CGPoint(x: self.x * imageSize.width, y: self.y * imageSize.height)
    }
}

class Page2ViewController: UIViewController {
    
    // MARK: - UI Properties
    @IBOutlet weak var videoPreview: UIView!
    @IBOutlet weak var captureButton: UIButton!
    @IBOutlet weak var saveImageButton: UIButton!
    @IBOutlet weak var restartSession: UIButton!
    
    var detectedImage: UIImage?
    weak var delegate: ImagePathDelegate?
    
    // MARK: - AV Property
    var videoCapture: VideoCapture!
    var lastCapturedPixelBuffer: CVPixelBuffer?
    
    // MARK: - Rectangle Layer
    private var fixedRectLayer = CAShapeLayer()
    private var isTapped = false
    
    // MARK: - View Controller Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup camera
        setUpCamera()
        
        // Setup capture button action
        captureButton.addTarget(self, action: #selector(captureButtonPressed(_:)), for: .touchUpInside)
        styleButton(captureButton, withColor: .systemRed)
        
        // Setup save image button action
        saveImageButton.addTarget(self, action: #selector(saveImageButtonPressed(_:)), for: .touchUpInside)
        styleButton(saveImageButton, withColor: .systemGreen)
        
        // Restart Session
        restartSession.addTarget(self, action: #selector(restartSessionPressed(_:)), for: .touchUpInside)
        styleButton(restartSession, withColor: .systemBlue)
        
        let pinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        videoPreview.addGestureRecognizer(pinchGestureRecognizer)
        
        // Set background color
        view.backgroundColor = .systemGray6
        
        // Draw a fixed rectangle on the screen
        drawFixedRectangle()
    }

    private func styleButton(_ button: UIButton, withColor color: UIColor) {
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 10
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.3
        button.layer.shadowOffset = CGSize(width: 0, height: 5)
        button.layer.shadowRadius = 10
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.videoCapture.start()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.videoCapture.stop()
    }

    // MARK: - SetUp Video
    func setUpCamera() {
        videoCapture = VideoCapture()
        videoCapture.delegate = self
        videoCapture.fps = 30
        videoCapture.setUp(sessionPreset: .vga640x480) { success in
            if success {
                if let previewLayer = self.videoCapture.previewLayer {
                    self.videoPreview.layer.addSublayer(previewLayer)
                    self.resizePreviewLayer()
                }
                self.videoCapture.start()
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let previewLayer = videoCapture?.previewLayer {
            previewLayer.frame = videoPreview.bounds
            videoPreview.layer.insertSublayer(previewLayer, at: 0)
        }
    }

    func resizePreviewLayer() {
        videoCapture.previewLayer?.frame = videoPreview.bounds
    }

    fileprivate func animateButton(_ viewToAnimate: UIView) {
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.5, options: .curveEaseIn, animations: {
            viewToAnimate.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        }) { (_) in
            UIView.animate(withDuration: 0.15, delay: 0, usingSpringWithDamping: 0.4, initialSpringVelocity: 2, options: .curveEaseIn, animations: {
                viewToAnimate.transform = CGAffineTransform(scaleX: 1, y: 1)
            }, completion: nil)
        }
    }

    // MARK: - Capture Button
    @objc func captureButtonPressed(_ sender: UIButton) {
        animateButton(sender)
        guard let pixelBuffer = lastCapturedPixelBuffer else {
            print("No captured pixel buffer available")
            return
        }

        self.isTapped = true
        // Use the fixedRectLayer's frame to crop the image from the pixel buffer
        let fixedRect = fixedRectLayer.frame
//        // Crop the image based on the fixed rectangle
        if let croppedImage = cropImageFromPixelBuffer(using: fixedRect, from: pixelBuffer) {
            self.detectedImage = croppedImage
            print("Image captured and cropped with the fixed rectangle")
        } else {
            print("Failed to crop image")
        }
//        self.detectRectangle(in: pixelBuffer)
        // Stop video capture after the image is captured
        self.videoCapture.stop()
    }

    @objc func saveImageButtonPressed(_ sender: UIButton) {
        animateButton(sender)
        guard let detectedImage = self.detectedImage else {
            print("No detected image available. Capture the image first.")
            return
        }
        let default_folder_name = "defaultFolder"
        let default_image_name = "defaultImage"
//        let alert = UIAlertController(title: "Save Image", message: "Enter folder and image name:", preferredStyle: .alert)
//        alert.addTextField { textField in
//            textField.placeholder = default_folder_name
//        }
//        alert.addTextField { textField in
//            textField.placeholder = default_image_name
//        }
//
//        let saveAction = UIAlertAction(title: "Save", style: .default) { [weak self] _ in
//            if let folderName = alert.textFields?[0].text,
//               let imageName = alert.textFields?[1].text {
//                self?.saveImageToDocuments(image: detectedImage, folderName: folderName, imageName: imageName)
//            } else {
//                print("Folder name is empty")
//            }
//        }
//
//        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
//        alert.addAction(saveAction)
//        alert.addAction(cancelAction)
//        present(alert, animated: true, completion: nil)
        
        
        self.saveImageToDocuments(image: detectedImage, folderName: default_folder_name, imageName: default_image_name)
        
    }
    
    // MARK: - Draw Fixed Rectangle

    private func drawFixedRectangle() {
        // Define the size of the rectangle (proportional to the videoPreview bounds)
        let rectWidth: CGFloat = videoPreview.bounds.width * 0.8
        let rectHeight: CGFloat = videoPreview.bounds.height * 0.4
        
        // Create a CGRect for the fixed rectangle, centered in videoPreview
        let rect = CGRect(x: (videoPreview.bounds.width - rectWidth) / 2,
                          y: (videoPreview.bounds.height - rectHeight) / 2,
                          width: rectWidth,
                          height: rectHeight)
        
        // Create the fixed rectangle layer
        fixedRectLayer = CAShapeLayer()
        fixedRectLayer.frame = rect
        fixedRectLayer.cornerRadius = 10
        fixedRectLayer.opacity = 1
        fixedRectLayer.borderColor = UIColor.systemYellow.cgColor
        fixedRectLayer.borderWidth = 4.0
        fixedRectLayer.shadowColor = UIColor.black.cgColor
        fixedRectLayer.shadowOpacity = 0.5
        fixedRectLayer.shadowOffset = CGSize(width: 0, height: 2)
        fixedRectLayer.shadowRadius = 5
        
        // Remove any existing rectangle layers and add the new one
        videoPreview.layer.sublayers?.removeAll(where: { $0 is CAShapeLayer })
        videoPreview.layer.addSublayer(fixedRectLayer)
    }


    
    // MARK: - Helper Functions
    func imageFromPixelBuffer(_ pixelBuffer: CVPixelBuffer) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            return UIImage(cgImage: cgImage)
        }
        return nil
    }
    
    func cropImageFromPixelBuffer(using rect: CGRect, from buffer: CVImageBuffer) -> UIImage? {
        // Convert CVImageBuffer to CIImage
        let ciImage = CIImage(cvImageBuffer: buffer)
        
        // Calculate the image size (buffer size)
        let imageSize = ciImage.extent.size
        
        // Convert the CGRect from the videoPreview's coordinate system to CIImage's coordinate system.
        // Flip the Y-axis of the rectangle because CoreImage's origin is bottom-left, but UIKit's origin is top-left.
        let croppingRect = CGRect(
            x: rect.origin.x * imageSize.width / videoPreview.bounds.width,
            y: (videoPreview.bounds.height - rect.maxY) * imageSize.height / videoPreview.bounds.height,
            width: rect.size.width * imageSize.width / videoPreview.bounds.width,
            height: rect.size.height * imageSize.height / videoPreview.bounds.height
        )
        
        // Crop the CIImage using the corrected cropping rectangle
        let croppedCIImage = ciImage.cropped(to: croppingRect)
        
        // Create a CIContext to convert CIImage to CGImage
        let context = CIContext()
        
        // Create CGImage from the cropped CIImage
        guard let cgImage = context.createCGImage(croppedCIImage, from: croppedCIImage.extent) else {
            print("Failed to create CGImage")
            return nil
        }
        
        // Convert the CGImage to UIImage
        let output = UIImage(cgImage: cgImage)
        
        // Return the final cropped image
        return output
    }

    func saveImageToDocuments(image: UIImage, folderName: String = "DefaultFolder", imageName: String = "DefaultImage") {
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        // Append "Study_" to the folder name
        let folderURL = documentsDirectory.appendingPathComponent("study_\(folderName)")

        do {
            if !fileManager.fileExists(atPath: folderURL.path) {
                try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
            }
            
            // Get list of existing files in the folder
            let files = try fileManager.contentsOfDirectory(atPath: folderURL.path)
            
            // Filter out files with the "skinimage_" prefix to count them
            let imageCount = files.filter { $0.hasPrefix("skinimage_") }.count
            
            // Append "skinimage_" to the image name and add an auto-incremented number
            let numberedImageName = "skinimage_\(imageCount + 1)_\(imageName).png"
            let imageURL = folderURL.appendingPathComponent(numberedImageName)
            
            if let data = image.pngData() {
                try data.write(to: imageURL)
                print("Image saved at path: \(imageURL.path)")
                
                DispatchQueue.main.async {
                    self.getImagePath(for: imageURL) { path in
                        if let path = path {
                            self.notifyImagePathCaptured(path)
                            self.showSuccessAlert(message: "Image saved successfully at path: \(path)")
                        } else {
                            self.showFailureAlert(message: "Failed to retrieve image path.")
                        }
                    }
                }
            } else {
                print("Failed to convert image to PNG data")
                self.showFailureAlert(message: "Failed to convert image to PNG data")
            }
        } catch {
            print("Error saving image to folder: \(error.localizedDescription)")
            self.showFailureAlert(message: "Error saving image: \(error.localizedDescription)")
        }
    }



    private func getImagePath(for imageURL: URL, completion: @escaping (String?) -> Void) {
        completion(imageURL.path)
    }

    private func notifyImagePathCaptured(_ path: String) {
        delegate?.didReceiveImagePath(path, from: self)
    }

    private func showSuccessAlert(message: String) {
        showAlert(title: "Success", message: message)
    }

    private func showFailureAlert(message: String) {
        showAlert(title: "Failure", message: message)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default, handler: nil)
        alert.addAction(action)
        present(alert, animated: true, completion: nil)
    }

    @objc func restartSessionPressed(_ sender: UIButton) {
        self.videoCapture.start()  // Restart the video session
        self.isTapped = false
    }
    
    @objc func handlePinch(_ sender: UIPinchGestureRecognizer) {
        guard let videoCapture = videoCapture else { return }
        if sender.state == .changed {
            videoCapture.updateZoomFactor(scale: sender.scale)
            sender.scale = 1.0
        }
    }
    
    
}

// MARK: - VideoCaptureDelegate
extension Page2ViewController: VideoCaptureDelegate {
    func videoCapture(_ capture: VideoCapture, didCaptureVideoFrame pixelBuffer: CVPixelBuffer?, timestamp: CMTime) {
        guard let pixelBuffer = pixelBuffer, !isTapped else {
            return
        }
        lastCapturedPixelBuffer = pixelBuffer
    }
    
    private func detectRectangle(in image: CVPixelBuffer) {
        
        let rect = fixedRectLayer.frame
        
        if self.isTapped {
            self.isTapped = false
            self.detectedImage = self.imageExtraction(using: rect, from: image)
        }
    }
    
    private func imageExtraction(using rect: CGRect, from buffer: CVImageBuffer) -> UIImage? {
        // Create CIImage from buffer
        var ciImage = CIImage(cvImageBuffer: buffer)
        
        // Validate CIImage extent
        let imageSize = ciImage.extent.size
        if imageSize.width.isInfinite || imageSize.height.isInfinite {
            print("Invalid CIImage extent: \(ciImage.extent)")
            return nil
        }
        
        print("Valid CIImage extent: \(ciImage.extent)")
        print("Input rect: \(rect.minX)")
        
        // Scale points to match image size
        let topLeft = CGPoint(x: rect.minX, y: rect.minY).scaled(to: imageSize)
        let topRight = CGPoint(x: rect.maxX, y: rect.minY).scaled(to: imageSize)
        let bottomLeft = CGPoint(x: rect.minX, y: rect.maxY).scaled(to: imageSize)
        let bottomRight = CGPoint(x: rect.maxX, y: rect.maxY).scaled(to: imageSize)
        print("Top Left: \(topLeft)")
        print("Top Right: \(topRight)")
        print("Bottom Left: \(bottomLeft)")
        print("Bottom Right: \(bottomRight)")

        // Apply perspective correction
        ciImage = ciImage.applyingFilter("CIPerspectiveCorrection", parameters: [
            "inputTopLeft": CIVector(cgPoint: topLeft),
            "inputTopRight": CIVector(cgPoint: topRight),
            "inputBottomLeft": CIVector(cgPoint: bottomLeft),
            "inputBottomRight": CIVector(cgPoint: bottomRight)
        ])
        
        // Create context
        let context = CIContext(options: [.useSoftwareRenderer : true])
        
        // Create CGImage from corrected image
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            print("Failed to create CGImage")
            print("Corrected image extent: \(ciImage.extent)")
            return nil
        }
        
        // Return the final UIImage
        return UIImage(cgImage: cgImage)
    }

   
    
    

}
