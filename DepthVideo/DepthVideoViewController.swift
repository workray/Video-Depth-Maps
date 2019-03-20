//
//  ViewController.swift
//  DepthVideo
//
//  Created by Mobdev125 on 3/20/19.
//  Copyright © 2019 Mobdev125. All rights reserved.
//

import UIKit
import AVFoundation

class DepthVideoViewController: UIViewController {
    
    @IBOutlet weak var previewView: UIImageView!
    @IBOutlet weak var previewModeControl: UISegmentedControl!
    @IBOutlet weak var filterControl: UISegmentedControl!
    @IBOutlet weak var filterControlView: UIView!
    @IBOutlet weak var depthSlider: UISlider!
    
    var sliderValue: CGFloat = 0.0
    var previewMode = PreviewMode.original
    var filter = FilterType.comic
    
    let session = AVCaptureSession()
    
    let dataOutputQueue = DispatchQueue(label: "video data queue",
                                        qos: .userInitiated,
                                        attributes: [],
                                        autoreleaseFrequency: .workItem)
    
    var background: CIImage?
    var depthMap: CIImage?
    var mask: CIImage?
    
    var scale: CGFloat = 0.0
    
    var depthFilters = DepthImageFilters()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let bgImage = UIImage(named: "earth_rise.jpg") {
            background = CIImage(image: bgImage)
        }
        
        filterControlView.isHidden = true
        depthSlider.isHidden = true
        
        previewMode = PreviewMode(rawValue: previewModeControl.selectedSegmentIndex) ?? .original
        filter = FilterType(rawValue: filterControl.selectedSegmentIndex) ?? .comic
        sliderValue = CGFloat(depthSlider.value)
        
        configureCaptureSession()
        
        session.startRunning()
    }
    
    override var shouldAutorotate: Bool {
        return false
    }
}

// MARK: - Helper Methods

extension DepthVideoViewController {
    
    func configureCaptureSession() {
        
        guard let camera = AVCaptureDevice.default(.builtInDualCamera,
                                                   for: .video,
                                                   position: .unspecified) else {
                                                    
                                                    fatalError("No depth video camera available")
        }
        
        session.sessionPreset = .photo
        
        do {
            let cameraInput = try AVCaptureDeviceInput(device: camera)
            session.addInput(cameraInput)
        } catch {
            fatalError(error.localizedDescription)
        }
        
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: dataOutputQueue)
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        
        session.addOutput(videoOutput)
        
        let videoConnection = videoOutput.connection(with: .video)
        videoConnection?.videoOrientation = .portrait
        
        let depthOutput = AVCaptureDepthDataOutput()
        depthOutput.setDelegate(self, callbackQueue: dataOutputQueue)
        depthOutput.isFilteringEnabled = true
        session.addOutput(depthOutput)
        let depthConnection = depthOutput.connection(with: .depthData)
        depthConnection?.videoOrientation = .portrait

        let outputRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        let videoRect = videoOutput.outputRectConverted(fromMetadataOutputRect: outputRect)
        let depthRect = depthOutput.outputRectConverted(fromMetadataOutputRect: outputRect)
        
        scale = max(videoRect.width, videoRect.height) / max(depthRect.width, depthRect.height)
        do {
            try camera.lockForConfiguration()
            if let frameDuration = camera.activeDepthDataFormat?
                .videoSupportedFrameRateRanges.first?.minFrameDuration {
                camera.activeVideoMinFrameDuration = frameDuration
            }
            camera.unlockForConfiguration()
        } catch {
            fatalError(error.localizedDescription)
        }
    }
}

// MARK: - Capture Video Data Delegate Methods

extension DepthVideoViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        let image = CIImage(cvPixelBuffer: pixelBuffer!)
        
        let previewImage: CIImage
        
        switch previewMode {
        case .original:
            previewImage = image
        case .depth:
            previewImage = depthMap ?? image
        case .mask:
            previewImage = mask ?? image
        default:
            previewImage = image
        }
        
        let displayImage = UIImage(ciImage: previewImage)
        DispatchQueue.main.async { [weak self] in
            self?.previewView.image = displayImage
        }
    }
}

// MARK: - Slider Methods

extension DepthVideoViewController {
    
    @IBAction func sliderValueChanged(_ sender: UISlider) {
        sliderValue = CGFloat(depthSlider.value)
    }
}

// MARK: - Segmented Control Methods

extension DepthVideoViewController {
    
    @IBAction func previewModeChanged(_ sender: UISegmentedControl) {
        
        previewMode = PreviewMode(rawValue: previewModeControl.selectedSegmentIndex) ?? .original
        
        if previewMode == .mask || previewMode == .filtered {
            filterControlView.isHidden = false
            depthSlider.isHidden = false
        } else {
            filterControlView.isHidden = true
            depthSlider.isHidden = true
        }
    }
    
    @IBAction func filterTypeChanged(_ sender: UISegmentedControl) {
        filter = FilterType(rawValue: filterControl.selectedSegmentIndex) ?? .comic
    }
}

// MARK: - Capture Depth Data Delegate Methods

extension DepthVideoViewController: AVCaptureDepthDataOutputDelegate {
    
    func depthDataOutput(_ output: AVCaptureDepthDataOutput,
                         didOutput depthData: AVDepthData,
                         timestamp: CMTime,
                         connection: AVCaptureConnection) {
        if previewMode == .original {
            return
        }
        
        var convertedDepth: AVDepthData
        if depthData.depthDataType != kCVPixelFormatType_DisparityFloat32 {
            convertedDepth = depthData.converting(toDepthDataType: kCVPixelFormatType_DisparityFloat32)
        } else {
            convertedDepth = depthData
        }
        let pixelBuffer = convertedDepth.depthDataMap
        pixelBuffer.clamp()
        let depthMap = CIImage(cvPixelBuffer: pixelBuffer)
        if previewMode == .mask || previewMode == .filtered {
            switch filter {
            default:
                mask = depthFilters.createHighPassMask(for: depthMap,
                                                       withFocus: sliderValue,
                                                       andScale: scale)
            }
        }
        DispatchQueue.main.async { [weak self] in
            self?.depthMap = depthMap
        }
    }
}
