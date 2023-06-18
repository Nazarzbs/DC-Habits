//
//  BadgeSupplementaryView.swift
//  DC Habits
//
//  Created by Nazar on 12.03.2023.
//

import Foundation
import UIKit

class BadgeSupplementaryView: UICollectionViewCell {
    static let reuseIdentifier = "badge-reuse-identifier"
    let label = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Not implemented")
    }
    
    override var frame: CGRect {
        didSet {
            configureBorder()
        }
    }
    
    override var bounds: CGRect {
        didSet {
            configureBorder()
        }
    }
}

extension BadgeSupplementaryView {
    func configure() {
        label.translatesAutoresizingMaskIntoConstraints = false
        label.adjustsFontForContentSizeCategory = true
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.textAlignment = .center
        label.textColor = .black
        backgroundColor = .green
        configureBorder()
    }
    func configureBorder() {
        let radius = bounds.width / 3.5
        layer.cornerRadius = radius
        layer.borderColor = UIColor.black.cgColor
        layer.borderWidth = 0.5
    }
}
