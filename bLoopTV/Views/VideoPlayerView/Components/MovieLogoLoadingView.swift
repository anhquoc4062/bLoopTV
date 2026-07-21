//
//  MovieLogoLoadingView.swift
//  bLoopTV
//
//  Lúc video đang tải trong player, hiện LOGO CỦA PHIM (clearLogo) nhịp thở — giống bản iOS.
//  Không có logo thì lùi về spinner cam.
//
//  Vì sao dựng bằng UIKit: nhịp thở làm bằng SwiftUI (.animation(value:) hoặc withAnimation kèm
//  repeatForever) đều bị gián đoạn, opacity rơi về ~0 nên logo chớp mất ở đáy. UIView.animate với
//  [.repeat, .autoreverse] chạy thẳng ở Core Animation, giữ alpha dao động đúng 0.4 <-> 1.0.
//

import SwiftUI
import UIKit
import SDWebImage

final class MovieLogoLoadingUIView: UIView {
    private let imageView = UIImageView()
    private let spinner = OrangeSpinnerView(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
    private var isBreathing = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSubviews()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) chưa dùng tới") }

    private func setupSubviews() {
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isHidden = true
        // Shadow bám theo alpha của logo (clearLogo là PNG nền trong suốt) nên logo trắng vẫn nổi
        // trên thumbnail sáng.
        imageView.layer.shadowColor = UIColor.black.cgColor
        imageView.layer.shadowOpacity = 0.7
        imageView.layer.shadowRadius = 14
        imageView.layer.shadowOffset = CGSize(width: 0, height: 2)
        addSubview(imageView)

        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.isHidden = true
        addSubview(spinner)

        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 440),
            imageView.heightAnchor.constraint(equalToConstant: 220),

            spinner.centerXAnchor.constraint(equalTo: centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: centerYAnchor),
            spinner.widthAnchor.constraint(equalToConstant: 60),
            spinner.heightAnchor.constraint(equalToConstant: 60)
        ])
    }

    func configure(logoUrlString: String?) {
        guard let urlString = logoUrlString, !urlString.isEmpty, let url = URL(string: urlString) else {
            showSpinner()
            return
        }

        imageView.sd_setImage(with: url, placeholderImage: nil, options: [.scaleDownLargeImages]) { [weak self] image, _, _, _ in
            guard let self else { return }
            if image != nil {
                self.showLogo()
            } else {
                // Không tải được logo thì vẫn phải có gì đó báo đang tải.
                self.showSpinner()
            }
        }
    }

    private func showLogo() {
        spinner.stopAnimating()
        spinner.isHidden = true
        imageView.isHidden = false
        startLogoBreathing()
    }

    private func showSpinner() {
        imageView.isHidden = true
        spinner.isHidden = false
        spinner.startAnimating()
    }

    // Ảnh cache có thể load xong TRƯỚC khi view vào window; UIView.animate lúc chưa ở trong window bị bỏ,
    // nên phải thử lại khi view thực sự vào hierarchy.
    override func didMoveToWindow() {
        super.didMoveToWindow()
        startLogoBreathing()
    }

    private func startLogoBreathing() {
        // Chỉ bắt đầu khi ĐÃ ở trong window và ảnh đã hiện — animate lúc chưa ở window sẽ không chạy mà
        // vẫn khoá isBreathing khiến logo đứng im.
        guard !isBreathing, window != nil, !imageView.isHidden else { return }
        isBreathing = true
        imageView.alpha = 0.4
        imageView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        UIView.animate(withDuration: 0.85, delay: 0,
                       options: [.repeat, .autoreverse, .curveEaseInOut, .allowUserInteraction]) {
            self.imageView.alpha = 1.0
            self.imageView.transform = .identity
        }
    }

    func stopLogoBreathing() {
        isBreathing = false
        imageView.layer.removeAllAnimations()
        imageView.transform = .identity
        imageView.alpha = 1.0
    }
}

struct MovieLogoLoadingView: UIViewRepresentable {
    let logoUrlString: String?

    func makeUIView(context: Context) -> MovieLogoLoadingUIView {
        let view = MovieLogoLoadingUIView()
        view.configure(logoUrlString: logoUrlString)
        return view
    }

    func updateUIView(_ uiView: MovieLogoLoadingUIView, context: Context) {}

    static func dismantleUIView(_ uiView: MovieLogoLoadingUIView, coordinator: ()) {
        uiView.stopLogoBreathing()
    }
}
