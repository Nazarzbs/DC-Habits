//
//  UserColectionViewCell.swift
//  DC Habits
//
//  Created by Nazar on 16.04.2023.
//

import UIKit

class UserColectionViewCell: UICollectionViewCell {
    static let reuseIdentifier: String = "User-collection-view-cell-reuse-identifier"
    
    //lazy
        var userImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true

        return imageView
    }()
    
    var userNameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18)
        label.numberOfLines = 0
        label.textColor = .systemGroupedBackground
        label.textAlignment = .center
        label.text = "Error"
        label.sizeToFit()
       
        return label
    }()
    
    override init (frame: CGRect) {
        super.init (frame: frame)
        setupView()
    }
        required init?(coder: NSCoder) {
            fatalError("init(coder: has not been implemented" )
        }
    
    func configure(with image: UIImage, and label: String) {
        self.userImageView.image = image
        self.userNameLabel.text = label
    }
    
    private func setupView() {
        
        self.contentView.addSubview(userImageView)
        self.contentView.addSubview(userNameLabel)
        
        userImageView.translatesAutoresizingMaskIntoConstraints = false
        userNameLabel.translatesAutoresizingMaskIntoConstraints = false

        contentView.clipsToBounds = true
       
        clipsToBounds = true
      
        NSLayoutConstraint.activate([
            userImageView.topAnchor.constraint(equalTo: self.contentView.layoutMarginsGuide.topAnchor),
            userImageView.bottomAnchor.constraint(equalTo: self.contentView.layoutMarginsGuide.bottomAnchor, constant: -60),
            userImageView.leadingAnchor.constraint(equalTo: self.contentView.layoutMarginsGuide.leadingAnchor),
            userImageView.trailingAnchor.constraint(equalTo: self.contentView.layoutMarginsGuide.trailingAnchor),
            
            userImageView.heightAnchor.constraint(equalToConstant: 50),
            userImageView.widthAnchor.constraint(equalToConstant: 50),
            
            userNameLabel.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor, constant: 20),
            userNameLabel.trailingAnchor.constraint(equalTo: self.contentView.trailingAnchor, constant: -20),
            userNameLabel.topAnchor.constraint(equalTo: self.userImageView.bottomAnchor, constant: 8),
            userNameLabel.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor),
        ])
    }
}

