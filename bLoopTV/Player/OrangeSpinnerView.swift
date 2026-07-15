//
//  OrangeSpinnerView.swift
//  VuaPhimBui
//
//  Created by Monster on 21/7/25.
//
import UIKit

class OrangeSpinnerView: UIView {
    private let shapeLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayer()
        startAnimating()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayer()
        startAnimating()
    }

    private func setupLayer() {
        let lineWidth: CGFloat = 4
        let radius = min(bounds.width, bounds.height) / 2 - lineWidth

        let circularPath = UIBezierPath(arcCenter: center,
                                        radius: radius,
                                        startAngle: 0,
                                        endAngle: .pi * 1.5,
                                        clockwise: true)

        shapeLayer.path = circularPath.cgPath
        shapeLayer.strokeColor = (UIColor(named: "VArtThemeColor") ?? .systemOrange).cgColor
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.lineWidth = lineWidth
        shapeLayer.lineCap = .round

        layer.addSublayer(shapeLayer)
    }

    func startAnimating() {
        isHidden = false
        let rotation = CABasicAnimation(keyPath: "transform.rotation")
        rotation.fromValue = 0
        rotation.toValue = CGFloat.pi * 2
        rotation.duration = 1.0
        rotation.repeatCount = .infinity
        layer.add(rotation, forKey: "rotate")
    }

    func stopAnimating() {
        isHidden = true
        layer.removeAnimation(forKey: "rotate")
    }
}
