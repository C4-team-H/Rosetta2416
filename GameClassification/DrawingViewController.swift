//
//  DrawingViewController.swift
//  GameClassification
//
//  Created by Antigravity on 13/07/26.
//

import UIKit
import PencilKit
import CoreML

class DrawingViewController: UIViewController {

    // MARK: - Callbacks
    var onSuccess: (() -> Void)?
    var onCancel: (() -> Void)?

    // MARK: - UI Components
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.15, green: 0.18, blue: 0.25, alpha: 1.0) // Slate dark blue card
        view.layer.cornerRadius = 20
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.5
        view.layer.shadowOffset = CGSize(width: 0, height: 10)
        view.layer.shadowRadius = 15
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "TANTANGAN: GAMBAR PESAWAT"
        label.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Gambarkan pesawat (airplane) menggunakan jari/stylus Anda pada kanvas putih di bawah."
        label.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        label.textColor = UIColor.white.withAlphaComponent(0.7)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let canvasView: PKCanvasView = {
        let canvas = PKCanvasView()
        canvas.backgroundColor = .white
        canvas.layer.cornerRadius = 12
        canvas.layer.masksToBounds = true
        canvas.layer.borderWidth = 1.0
        canvas.layer.borderColor = UIColor.lightGray.cgColor
        canvas.translatesAutoresizingMaskIntoConstraints = false
        return canvas
    }()

    private let buttonStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 15
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(" Batal", for: .normal)
        button.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor(red: 0.74, green: 0.25, blue: 0.25, alpha: 1.0) // Slate red
        button.layer.cornerRadius = 10
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let clearButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(" Hapus", for: .normal)
        button.setImage(UIImage(systemName: "trash.fill"), for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor(red: 0.25, green: 0.45, blue: 0.74, alpha: 1.0) // Slate blue
        button.layer.cornerRadius = 10
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let submitButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(" Kirim", for: .normal)
        button.setImage(UIImage(systemName: "paperplane.fill"), for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor(red: 0.15, green: 0.68, blue: 0.38, alpha: 1.0) // Success green
        button.layer.cornerRadius = 10
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if #available(iOS 13.0, *) {
            overrideUserInterfaceStyle = .light
        }
        
        view.backgroundColor = UIColor.black.withAlphaComponent(0.65) // Dark overlay background
        
        setupViews()
        setupCanvas()
        setupActions()
    }

    // MARK: - Layout Setup
    private func setupViews() {
        view.addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(subtitleLabel)
        containerView.addSubview(canvasView)
        containerView.addSubview(buttonStackView)
        
        buttonStackView.addArrangedSubview(cancelButton)
        buttonStackView.addArrangedSubview(clearButton)
        buttonStackView.addArrangedSubview(submitButton)
        
        // Auto Layout Constraints
        NSLayoutConstraint.activate([
            // Card Container (Responsive: lebar tetap pada iPad, melar tapi berjarak pada iPhone)
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: min(500, view.bounds.width - 40)),
            containerView.heightAnchor.constraint(equalToConstant: min(600, view.bounds.height - 60)),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            // Subtitle
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            // Canvas View (Square drawing area inside card)
            canvasView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 20),
            canvasView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            canvasView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            canvasView.bottomAnchor.constraint(equalTo: buttonStackView.topAnchor, constant: -20),
            
            // Button Stack View
            buttonStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            buttonStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            buttonStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -24),
            buttonStackView.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func setupCanvas() {
        // Setup PencilKit inking tool
        canvasView.tool = PKInkingTool(.pen, color: .black, width: 6.0)
        
        // Allow finger drawing (supports simulator/touch device input)
        if #available(iOS 14.0, *) {
            canvasView.drawingPolicy = .anyInput
        } else {
            canvasView.allowsFingerDrawing = true
        }
    }

    private func setupActions() {
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        clearButton.addTarget(self, action: #selector(clearTapped), for: .touchUpInside)
        submitButton.addTarget(self, action: #selector(submitTapped), for: .touchUpInside)
    }

    // MARK: - Actions
    @objc private func cancelTapped() {
        dismiss(animated: true) { [weak self] in
            self?.onCancel?()
        }
    }

    @objc private func clearTapped() {
        canvasView.drawing = PKDrawing()
    }

    @objc private func submitTapped() {
        // 1. Validasi jika canvas kosong
        guard !canvasView.drawing.bounds.isEmpty else {
            showAlert(title: "Kanvas Kosong", message: "Silakan gambar pesawat terlebih dahulu sebelum menekan Kirim.")
            return
        }
        
        // Disable tombol untuk mencegah klik ganda selama klasifikasi
        submitButton.isEnabled = false
        
        // 2. Render gambar dengan latar belakang putih murni
        guard let drawingImage = renderDrawingWithWhiteBackground() else {
            showAlert(title: "Kesalahan", message: "Gagal memproses gambar coretan.")
            submitButton.isEnabled = true
            return
        }
        
        // 3. Konversi ke CVPixelBuffer berukuran 360x360
        guard let pixelBuffer = convertToPixelBuffer(image: drawingImage) else {
            showAlert(title: "Kesalahan", message: "Gagal membuat pixel buffer gambar.")
            submitButton.isEnabled = true
            return
        }
        
        // 4. Lakukan klasifikasi menggunakan CoreML model
        do {
            let config = MLModelConfiguration()
            let model = try HandwritingGameClassification(configuration: config)
            let input = HandwritingGameClassificationInput(image: pixelBuffer)
            
            let output = try model.prediction(input: input)
            let predictedLabel = output.target.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let probability = output.targetProbability[output.target] ?? 0.0
            
            print("Predicted Class: \(predictedLabel), Confidence: \(probability)")
            
            // Verifikasi label: model TU Berlin menghasilkan kelas 'airplane'
            if predictedLabel == "airplane" {
                showSuccessAlert()
            } else {
                showFailureAlert(predictedLabel: predictedLabel, confidence: probability)
            }
            
        } catch {
            print("CoreML Error: \(error)")
            let nsError = error as NSError
            let detail = "Domain: \(nsError.domain)\nCode: \(nsError.code)\nMessage: \(nsError.localizedDescription)\nUserInfo: \(nsError.userInfo)"
            showAlert(title: "Gagal Prediksi", message: "Terjadi kesalahan saat memproses model ML:\n\n\(detail)")
            submitButton.isEnabled = true
        }
    }

    // MARK: - Image Processing Helpers
    
    // Merender coretan (PKDrawing) di atas latar putih solid (bukan transparan)
    private func renderDrawingWithWhiteBackground() -> UIImage? {
        let drawingBounds = canvasView.bounds
        
        // Memaksa light mode trait collection agar coretan dirender sebagai warna hitam (bukan putih karena dark mode)
        var drawingImage: UIImage? = nil
        if #available(iOS 13.0, *) {
            UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
                drawingImage = canvasView.drawing.image(from: drawingBounds, scale: 1.0)
            }
        } else {
            drawingImage = canvasView.drawing.image(from: drawingBounds, scale: 1.0)
        }
        
        guard let image = drawingImage else { return nil }
        
        UIGraphicsBeginImageContextWithOptions(drawingBounds.size, true, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        // Isi dengan warna putih solid
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: drawingBounds.size))
        
        // Gambar lukisan di atasnya
        image.draw(in: CGRect(origin: .zero, size: drawingBounds.size))
        
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    // Mengonversi dan meresize image menjadi CVPixelBuffer 360x360
    private func convertToPixelBuffer(image: UIImage) -> CVPixelBuffer? {
        let targetSize = CGSize(width: 360, height: 360)
        
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
        ] as CFDictionary
        
        var pixelBuffer: CVPixelBuffer? = nil
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(targetSize.width), Int(targetSize.height), kCVPixelFormatType_32BGRA, attrs, &pixelBuffer)
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(buffer)
        
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: pixelData,
            width: Int(targetSize.width),
            height: Int(targetSize.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        )
        
        guard let ctx = context else {
            CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
            return nil
        }
        
        // Membalik sistem koordinat CGContext agar sesuai dengan UIKit
        ctx.translateBy(x: 0, y: targetSize.height)
        ctx.scaleBy(x: 1.0, y: -1.0)
        
        UIGraphicsPushContext(ctx)
        image.draw(in: CGRect(origin: .zero, size: targetSize))
        UIGraphicsPopContext()
        CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        
        return buffer
    }

    // MARK: - Alerts
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    private func showSuccessAlert() {
        let alert = UIAlertController(title: "Berhasil!", message: "Luar biasa! Gambar Anda dikenali sebagai Pesawat Terbang (Airplane). Tantangan selesai!", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Lanjutkan", style: .default, handler: { [weak self] _ in
            self?.dismiss(animated: true) {
                self?.onSuccess?()
            }
        }))
        present(alert, animated: true, completion: nil)
    }

    private func showFailureAlert(predictedLabel: String, confidence: Double) {
        let percentage = Int(confidence * 100)
        let humanFriendlyLabel: String
        
        // Menyesuaikan beberapa label umum untuk respon yang ramah pengguna
        switch predictedLabel {
        case "flying bird": humanFriendlyLabel = "Burung Terbang"
        case "space shuttle": humanFriendlyLabel = "Pesawat Ulang Alik"
        case "blimp": humanFriendlyLabel = "Balon Udara Blimp"
        case "helicopter": humanFriendlyLabel = "Helikopter"
        case "dragon": humanFriendlyLabel = "Naga"
        case "shark": humanFriendlyLabel = "Hiu"
        default: humanFriendlyLabel = predictedLabel
        }
        
        let message = "Maaf, gambar Anda lebih mirip dengan \"\(humanFriendlyLabel)\" (kecocokan \(percentage)%).\n\nSilakan bersihkan kanvas dan cobalah menggambar pesawat terbang yang lebih jelas!"
        
        let alert = UIAlertController(title: "Kurang Tepat", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Coba Lagi", style: .default, handler: { [weak self] _ in
            self?.submitButton.isEnabled = true
            self?.clearTapped()
        }))
        present(alert, animated: true, completion: nil)
    }
}
