import UIKit
import Vision
import AVFoundation

class ViewController : UIViewController {

    @IBOutlet weak var previewView: PreviewView!

    fileprivate let session = AVCaptureSession()
    fileprivate let sessionQueue = DispatchQueue(label: "com.unifa-e.qrcodereader")
    fileprivate var permissionStatus: AVAuthorizationStatus = .authorized

    //swiftlint:disable function_body_length
    override func viewDidLoad() {
        super.viewDidLoad()
        session.sessionPreset = AVCaptureSession.Preset.photo
        previewView.session = session

        switch AVCaptureDevice.authorizationStatus(for: AVMediaType.video) {
        case .authorized: break
        case .notDetermined:
            self.sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video) { [weak self] (granted) in
                if !granted {
                    self?.permissionStatus = .denied
                }
                self?.sessionQueue.resume()
            }
            break
        default:
            permissionStatus = .denied
            break
        }

        sessionQueue.async { [unowned self] in
            guard self.permissionStatus == .authorized else {
                return
            }
            self.session.beginConfiguration()

            do {
                let videoDevice = ViewController.device(with: .video, preferringPosition: .back)
                let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice!)
                guard self.session.canAddInput(videoDeviceInput) else {
                    return
                }
                self.session.addInput(videoDeviceInput)
                DispatchQueue.main.async {
                    guard let preview = self.previewView.layer as? AVCaptureVideoPreviewLayer else {
                        return
                    }
                    let statusBarOrientation = UIApplication.shared.statusBarOrientation
                    var videoOrientation: AVCaptureVideoOrientation = .portrait
                    if statusBarOrientation != .unknown {
                        videoOrientation = AVCaptureVideoOrientation(interfaceOrientaion: statusBarOrientation)
                    }
                    preview.connection?.videoOrientation = videoOrientation
                }

                let videoDataOutput = AVCaptureVideoDataOutput()
                videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]

                /// Dicard if th data output queue is blocked (as we process the still image)
                videoDataOutput.alwaysDiscardsLateVideoFrames = true
                videoDataOutput.setSampleBufferDelegate(self, queue: self.sessionQueue)

                self.session.addOutput(videoDataOutput)
            } catch {

            }
            self.session.commitConfiguration()
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        sessionQueue.async {
            if self.permissionStatus == .authorized {
                self.session.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if self.session.isRunning {
            self.session.stopRunning()
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        guard let previewView: AVCaptureVideoPreviewLayer = self.previewView?.layer as? AVCaptureVideoPreviewLayer else {
            return
        }
        let orientation = UIDevice.current.orientation
        if orientation.isPortrait || orientation.isLandscape {
            if self.permissionStatus == .authorized {
                previewView.connection?.videoOrientation = AVCaptureVideoOrientation(rawValue: orientation.rawValue)!
            }
        }
        previewView.frame.size = size
    }

    class func device(with mediaType: AVMediaType, preferringPosition position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let devices = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualCamera, .builtInWideAngleCamera], mediaType: mediaType, position: position).devices
        var captureDevice: AVCaptureDevice? = devices.first
        for device in devices where device.position == position {
            captureDevice = device
            break
        }
        return captureDevice
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    }
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        let handler = VNSequenceRequestHandler()
        let barcodesDetectionRequest = VNDetectBarcodesRequest { [weak self] (request, error) in
            if let error = error {
                NSLog("%@, %@", #function, error.localizedDescription)
            }
            guard let results = request.results else { return }
            guard let observation = results.first as? VNDetectedObjectObservation else { return }
            guard observation.confidence > 0.3 else { return }

            let text = results.flatMap { $0 as? VNBarcodeObservation }
                .flatMap { $0.payloadStringValue }
                .joined(separator: ", ")
            DispatchQueue.main.async {
                let barcodes: [VNBarcodeObservation] = results.flatMap { $0 as? VNBarcodeObservation }
                NSLog("barcodes: %d, %@", barcodes.count, text)
                self?.previewView.barcodes = barcodes
            }
        }
        let s = Date()
        try? handler.perform([barcodesDetectionRequest], on: pixelBuffer)
        NSLog("time: %lf s", -s.timeIntervalSinceNow)
    }
}

// MARK: - AVCaptureVideoOrientation

fileprivate extension AVCaptureVideoOrientation {
    var interfaceOrientation: UIInterfaceOrientation {
        switch self {
        case .landscapeLeft:        return .landscapeLeft
        case .landscapeRight:       return .landscapeRight
        case .portrait:             return .portrait
        case .portraitUpsideDown:   return .portraitUpsideDown

        }
    }

    init(interfaceOrientaion: UIInterfaceOrientation) {
        switch interfaceOrientaion {
        case .landscapeRight:       self = .landscapeRight
        case .landscapeLeft:        self = .landscapeLeft
        case .portrait:             self = .portrait
        case .portraitUpsideDown:   self = .portraitUpsideDown
        default:                    self = .portrait
        }
    }
}
