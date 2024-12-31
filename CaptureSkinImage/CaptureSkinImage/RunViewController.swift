import UIKit
import Foundation

protocol ImagePathDelegate: AnyObject {
    func didReceiveImagePath(_ path: String, from controller: UIViewController)
}

class RunViewController: UIViewController {
    // UI Components
    @IBOutlet weak var runScriptButton: UIButton!
    @IBOutlet weak var resultLabel: UILabel!
    @IBOutlet weak var standardImageView: UIImageView!
    @IBOutlet weak var heatmapImage: UIImageView!
    @IBOutlet weak var riskImage: UIImageView!
    @IBOutlet weak var progressBar: UIProgressView!
    @IBOutlet weak var modelPicker: UIPickerView!

    // Activity Indicator
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let activityIndicatorBackgroundView = UIView()

    // Image paths
    var standardImagePath: String = ""

    // Model options
    let models = ["Adversarial Model", "Contrastive learning Model"]
    var selectedModel: String?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Initialize UI Components
        setupUI()
        setupActivityIndicator()
        setupModelPicker()
    }

    // MARK: - UI Setup
    private func setupUI() {
        runScriptButton.addTarget(self, action: #selector(runScriptButtonPressed(_:)), for: .touchUpInside)
        setupGradientBackground()
        styleRunScriptButton()
        styleResultLabel()
        styleImageViews()
        setupProgressBar()
    }
    
    private func setupActivityIndicator() {
        activityIndicatorBackgroundView.frame = view.bounds
        activityIndicatorBackgroundView.backgroundColor = UIColor(white: 0, alpha: 0.5)
        activityIndicatorBackgroundView.isHidden = true
        view.addSubview(activityIndicatorBackgroundView)
        
        activityIndicator.color = .white
        activityIndicator.center = view.center
        activityIndicatorBackgroundView.addSubview(activityIndicator)
    }
    
    // MARK: - Setup Background
    private func setupGradientBackground() {
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = view.bounds
        gradientLayer.colors = [
            UIColor(red: 0.85, green: 0.94, blue: 1.0, alpha: 1.0).cgColor,
            UIColor(red: 0.95, green: 0.98, blue: 1.0, alpha: 1.0).cgColor
        ]
        gradientLayer.locations = [0.0, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        view.layer.insertSublayer(gradientLayer, at: 0)
    }

    private func setupProgressBar() {
        progressBar.progress = 0.0
        progressBar.isHidden = true
    }

    private func setupModelPicker() {
        modelPicker.dataSource = self
        modelPicker.delegate = self
        selectedModel = models.first
    }

    private func styleRunScriptButton() {
        runScriptButton.backgroundColor = UIColor.systemBlue
        runScriptButton.setTitleColor(.white, for: .normal)
        runScriptButton.layer.cornerRadius = 10
        runScriptButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        runScriptButton.layer.shadowColor = UIColor.black.cgColor
        runScriptButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        runScriptButton.layer.shadowOpacity = 0.3
        runScriptButton.layer.shadowRadius = 4
    }

    private func styleResultLabel() {
        resultLabel.text = "Result will appear here"
        resultLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        resultLabel.textColor = UIColor.darkGray
        resultLabel.numberOfLines = 0
        resultLabel.textAlignment = .center
        resultLabel.layer.borderWidth = 0 // Remove border
        resultLabel.backgroundColor = .clear // Transparent background
    }

    private func styleImageViews() {
        riskImage.contentMode = .scaleAspectFit
        [ heatmapImage, standardImageView].forEach { imageView in
            imageView?.contentMode = .scaleAspectFit
            imageView?.layer.borderWidth = 0 // No visible border
            imageView?.backgroundColor = .white // Set background to white
            imageView?.layer.cornerRadius = 8 // Optional: Add rounded corners
            imageView?.layer.masksToBounds = true // Ensure content stays within bounds
        }
    }


    @IBAction func btnTapped(_ sender: UIView) {
        animateButton(sender)
        let storyboard = self.storyboard?.instantiateViewController(withIdentifier: "Page2ViewController") as! Page2ViewController
        storyboard.delegate = self
        self.navigationController?.pushViewController(storyboard, animated: true)
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

    @objc func runScriptButtonPressed(_ sender: UIButton) {
        animateButton(sender)
//        showActivityIndicator()
        sendPostRequest()
    }

    private func showActivityIndicator() {
        activityIndicatorBackgroundView.isHidden = false
        activityIndicator.startAnimating()
    }

    private func hideActivityIndicator() {
        activityIndicator.stopAnimating()
        activityIndicatorBackgroundView.isHidden = true
    }

    private func updateProgressBar(value: Float) {
        progressBar.isHidden = false
        progressBar.setProgress(value, animated: true)
        if value >= 1.0 {
            progressBar.isHidden = true
        }
    }

    func sendPostRequest() {
        guard let model = selectedModel else {
            handleError(message: "Model not selected")
            return
        }
        
        guard !standardImagePath.isEmpty,
              let standardImage = UIImage(contentsOfFile: standardImagePath),
              let standardImageData = standardImage.jpegData(compressionQuality: 1.0)?.base64EncodedString() else {
            handleError(message: "Image not found or invalid")
            return
        }
        
        let payload: [String: Any] = [
            "model": model,
            "standardImage": standardImageData
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
            let urlString = "https://d498-149-169-80-87.ngrok-free.app/predict"
            
            guard let url = URL(string: urlString) else {
                handleError(message: "Invalid URL")
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData
            
            // Track Progress
            let sessionConfig = URLSessionConfiguration.default
            sessionConfig.waitsForConnectivity = true
            let session = URLSession(configuration: sessionConfig, delegate: nil, delegateQueue: nil)

            let task = session.dataTask(with: request) { [weak self] data, response, error in
                if let error = error {
                    DispatchQueue.main.async {
                        self?.handleError(message: "Network error: \(error.localizedDescription)")
                    }
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                    DispatchQueue.main.async {
                        self?.handleError(message: "Server error or unexpected response")
                    }
                    return
                }
                
                if let data = data {
                    DispatchQueue.main.async {
                        self?.handleSuccessfulResponse(data: data)
                        self?.updateProgressBar(value: 1.0) // Full progress on success
                    }
                }
            }
            
            // Simulate Progress Updates
            DispatchQueue.main.async {
                self.updateProgressBar(value: 0.1) // Start
            }
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
                DispatchQueue.main.async {
                    self.progressBar.progress += 0.2
                    if self.progressBar.progress >= 0.9 {
                        timer.invalidate()
                    }
                }
            }
            
            task.resume()
        } catch {
            handleError(message: "Failed to create JSON payload: \(error.localizedDescription)")
        }
    }


    private func handleError(message: String) {
        resultLabel.text = "Error: \(message)"
        hideActivityIndicator()
    }

    private func handleSuccessfulResponse(data: Data?) {
            guard let data = data else {
                handleError(message: "No data received")
                return
            }
            
            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let outputValue = jsonResponse["output"] as? String,
                   let probability_value = jsonResponse["probability"] as? Double,
                   let overlayImageBase64 = jsonResponse["overlay_image"] as? String,
                   let riskImageBase64 = jsonResponse["risk_image"] as? String {
                    
                   let probability_value_rounded = (probability_value * 100).rounded() / 100
                    print("Success! Output: \(outputValue)")
                    resultLabel.text = "Predicted risk: \(outputValue) \n Probability: \(probability_value_rounded)"
                    
                    // Decode base64 overlay image string
                    if let overlayImageData = Data(base64Encoded: overlayImageBase64, options: .ignoreUnknownCharacters),
                       let overlayImage = UIImage(data: overlayImageData) {
                        // Display overlay image in standardImageView
                        heatmapImage.image = overlayImage
                        if let heatmapImageToResize = heatmapImage.image {
                            heatmapImage.image = resizeImage(heatmapImageToResize, targetSize: standardImageView.bounds.size)
                        }

                    } else {
                        handleError(message: "Failed to decode overlay image")
                    }
                    
                    // Decode base64 overlay image string
                    if let cancerRiskImageData = Data(base64Encoded: riskImageBase64, options: .ignoreUnknownCharacters),
                       let cancerRiskImage = UIImage(data: cancerRiskImageData) {
                        // Display overlay image in standardImageView
                        riskImage.image = cancerRiskImage
    //                    if let riskImageToResize = riskImage.image {
    //                        riskImage.image = resizeImage(riskImageToResize, targetSize: standardImageView.bounds.size)
    //                    }
                    } else {
                        handleError(message: "Failed to decode overlay image")
                    }
                } else {
                    handleError(message: "'output' or 'overlay_image' key not found or invalid format")
                }
            } catch {
                handleError(message: "Failed to parse JSON: \(error.localizedDescription)")
            }
        }
        
        private func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage? {
            UIGraphicsBeginImageContextWithOptions(targetSize, false, 0.0)
            image.draw(in: CGRect(origin: .zero, size: targetSize))
            let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return resizedImage
        }
}

// Model Picker Setup
extension RunViewController: UIPickerViewDataSource, UIPickerViewDelegate {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return models.count
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return models[row]
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        selectedModel = models[row]
    }
}

extension RunViewController: ImagePathDelegate {
    func didReceiveImagePath(_ path: String, from controller: UIViewController) {
        if controller is Page2ViewController {
            standardImagePath = path
            if let standardImage = UIImage(contentsOfFile: path) {
                standardImageView.image = standardImage
            }
        }
    }
}
