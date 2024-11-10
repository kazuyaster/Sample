//
//  PreviewView.swift
//  Sample
//
//  Created by 小田和哉 on 2024/11/10.
//

import UIKit
import AVFoundation
import Vision

class PreviewView: UIView {
    let targetLayerName = "box"

    var session: AVCaptureSession? {
        get {
            return (self.layer as? AVCaptureVideoPreviewLayer)?.session
        }
        set {
            (self.layer as? AVCaptureVideoPreviewLayer)?.session = newValue
            if let layer = self.layer as? AVCaptureVideoPreviewLayer {
                layer.videoGravity = AVLayerVideoGravity.resizeAspect
            }
        }
    }

    var barcodes: [VNRectangleObservation] = [] {
        didSet {
            self.setNeedsDisplay()
        }
    }

    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }

    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)

        self.layer.sublayers?
            .filter { $0.name == targetLayerName }
            .forEach { $0.removeFromSuperlayer() }

        guard let previewLayer = self.layer as? AVCaptureVideoPreviewLayer else {
            return
        }

        for barcode in barcodes {
            /// VNRectangleObservation が持っている座標系がY軸反転しているのでアフィン変換しておく
            let t = CGAffineTransform(translationX: 0, y: 1)
                .scaledBy(x: 1, y: -1)
            let tl = previewLayer.layerPointConverted(fromCaptureDevicePoint: barcode.topLeft.applying(t))
            let tr = previewLayer.layerPointConverted(fromCaptureDevicePoint: barcode.topRight.applying(t))
            let bl = previewLayer.layerPointConverted(fromCaptureDevicePoint: barcode.bottomLeft.applying(t))
            let br = previewLayer.layerPointConverted(fromCaptureDevicePoint: barcode.bottomRight.applying(t))
            let l = rectangle(UIColor.green, topLeft: tl, topRight: tr, bottomLeft: bl, bottomRight: br)
            self.layer.addSublayer(l)
        }
    }

    func rectangle(_ color: UIColor, topLeft: CGPoint, topRight: CGPoint, bottomLeft: CGPoint, bottomRight: CGPoint) -> CALayer {
        let lineWidth: CGFloat = 2
        let path: CGMutablePath = CGMutablePath()
        path.move(to: topLeft)
        path.addLine(to: topRight)
        path.addLine(to: bottomRight)
        path.addLine(to: bottomLeft)
        path.addLine(to: topLeft)
        let layer = CAShapeLayer()
        layer.name = targetLayerName
        layer.fillColor = UIColor.clear.cgColor
        layer.strokeColor = color.cgColor
        layer.lineWidth = lineWidth
        layer.lineJoin = CAShapeLayerLineJoin.miter
        layer.path = path
        return layer
    }
}
