//
//  FollowedUserCollectionViewCell.swift
//  DC Habits
//
//  Created by Nazar on 04.03.2023.
//

import UIKit

class FollowedUserCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet var primaryTextLabel: UILabel!
    @IBOutlet var secondaryTextLabel: UILabel!
    
    @IBOutlet var separatorLineView: UIView!
    @IBOutlet var separatorLineHeightConstant: NSLayoutConstraint!
    
    override func awakeFromNib() {
        separatorLineHeightConstant.constant = 1 / UITraitCollection.current.displayScale
    }
    
}
