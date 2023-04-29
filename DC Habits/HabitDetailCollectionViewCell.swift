//
//  HabitDetailCollectionViewCell.swift
//  DC Habits
//
//  Created by Nazar on 29.04.2023.
//

import UIKit

class HabitDetailCollectionViewCell: UICollectionViewListCell {

        let leftLabel = UILabel()
        let rightLabel = UILabel()
        let bottomLabel = UILabel()

        override init(frame: CGRect) {
            super.init(frame: frame)

            // Create a vertical stack view to hold the left and right labels
            let leftRightStackView = UIStackView()
            leftRightStackView.axis = .horizontal
            
            leftRightStackView.alignment = .fill
            leftRightStackView.distribution = .fill

            // Add the left and right labels to the stack view
            leftRightStackView.addArrangedSubview(leftLabel)
            leftRightStackView.addArrangedSubview(rightLabel)

            // Create a vertical stack view to hold the left-right stack view and the bottom label
            let mainStackView = UIStackView()
            mainStackView.axis = .vertical
            mainStackView.distribution = .fill
            mainStackView.alignment = .fill

            // Add the left-right stack view and the bottom label to the main stack view
            mainStackView.addArrangedSubview(leftRightStackView)
            mainStackView.addArrangedSubview(bottomLabel)

            // Add the main stack view to the cell's content view
            contentView.addSubview(mainStackView)

            // Set up constraints for the main stack view
            mainStackView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                mainStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16.0),
                mainStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8.0),
                mainStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16.0),
                mainStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8.0)
            ])
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

//        override func updateConfiguration(using state: UICellConfigurationState) {
//            super.updateConfiguration(using: state)
//
//            // Configure the left, right, and bottom labels
//            leftLabel.text = "Left Text"
//            rightLabel.text = "Right Text"
//            bottomLabel.text = ""
//
//            // Apply any custom appearance changes to the labels here
//        }
    }

    

