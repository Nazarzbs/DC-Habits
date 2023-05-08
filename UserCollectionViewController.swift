//
//  UserCollectionViewController.swift
//  DC Habits
//
//  Created by Nazar on 22.02.2023.
//

import UIKit
import Foundation

class UserCollectionViewController: UICollectionViewController {

    //Keep track of async tasks so they can be cancelled when appropriate
    var usersRequestTask: Task<Void, Never>? = nil
    var imageRequestTask:Task<Void, Never>? = nil
    
    deinit {
        usersRequestTask?.cancel()
        imageRequestTask?.cancel()
    }
    
    static let badgeElementKind = "badge-element-kind"

    
    override func viewDidLoad() {
        super.viewDidLoad()
                
        configureHierarchy()
        dataSource = createDataSource()
        collectionView.dataSource = dataSource
        collectionView.collectionViewLayout = createLayout()
        imageRequest()
        update()
    }

    typealias DataSourceType = UICollectionViewDiffableDataSource<ViewModel.Section, ViewModel.Item>
    
    var dataSource: DataSourceType!
    var model = Model()
    
    enum ViewModel {
        typealias Section = Int
        
        struct Item: Hashable {
            let user: User
            let isFollowed: Bool
            let userImage: UIImage
            
            func hash(into hasher: inout Hasher) {
                hasher.combine(user)
                hasher.combine(isFollowed)
                hasher.combine(userImage)
            }
            
            static func ==(_ lhs: Item, _ rhs: Item) -> Bool {
                return lhs.user == rhs.user && lhs.isFollowed == rhs.isFollowed && lhs.userImage == rhs.userImage
            }
        }
    }
    
    struct Model {
        var userImage = [String: UIImage]()
        
        var usersByID = [String: User]()
        var followedUsers: [User] {
            return Array(usersByID.filter {
                Settings.shared.followedUserIDs.contains($0.key)
            }.values)
        }
    }
    
     func update() {
        usersRequestTask?.cancel()
        usersRequestTask = Task {
            if let users = try? await UserRequest().send() {
                self.model.usersByID = users
                imageRequest()
               
            } else {
                self.model.usersByID = [:]
                imageRequest()
            }
           
            usersRequestTask = nil
        }
    }
    
    func imageRequest() {
        imageRequestTask?.cancel()
       
            self.imageRequestTask = Task {
                for userId in self.model.usersByID.keys {
                    if let image = try? await ImageRequest(imageID: userId).send()  {
                        if userId == "ActiveUser" {
                            self.model.userImage[userId] = UIImage(systemName: "person")!
                        } else {
                            self.model.userImage[userId] = image
                            
                        }
                    }
                }
                imageRequestTask = nil
                self.updateCollectionView()
            }
    }
    
    func updateCollectionView() {
        
        let users = model.usersByID.values.sorted().reduce(into: [ViewModel.Item]()) {
            partial, user in
            partial.append(ViewModel.Item(user: user, isFollowed: model.followedUsers.contains(user), userImage: model.userImage[user.id] ?? UIImage(systemName: "person")!))
        }
        
        let itemsBySection = [0: users]
        
        dataSource.applySnapshotUsing(sectionIDs: [0], itemsBySection: itemsBySection)
            
    }
    
    func createDataSource() -> DataSourceType {
        let dataSource = DataSourceType(collectionView: collectionView) { collectionView, indexPath, item in
            //Get a cell of the desired kind
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: UserColectionViewCell.reuseIdentifier, for: indexPath) as? UserColectionViewCell else { fatalError("Cannot create new cell") }

            var backgroundConfiguration = UIBackgroundConfiguration.clear()
         
            backgroundConfiguration.backgroundColor = item.user.color?.uiColor ?? UIColor.systemGray4
            
            cell.backgroundConfiguration = backgroundConfiguration
            cell.configure(with: item.userImage, and: item.user.name)
            cell.layer.cornerRadius = 30
            return cell
        }
        
        dataSource.supplementaryViewProvider = {
            //I going to have reference to mySELF, but it is going to be WEAK / optional
            [weak self] (collectionView: UICollectionView, kind: String, indexPath: IndexPath) -> UICollectionReusableView? in
            
            guard let self = self, let model = self.dataSource.itemIdentifier(for: indexPath) else { return nil }
            
            let hasBadge = model.isFollowed
            
            //get a supplementary view of the desired kind
            
            if let badgeView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: BadgeSupplementaryView.reuseIdentifier, for: indexPath) as? BadgeSupplementaryView {
                
                //set the badge as its label (and hide the view if the user hasn't followed by current user)
                badgeView.isHidden = !hasBadge
                badgeView.label.text = "✓"
                badgeView.label.adjustsFontForContentSizeCategory = false
              
                //return the view
                return badgeView
            } else {
                fatalError("Cannot create new supplementary")
            }
        }
        return dataSource
        
    }
    
    func createLayout() -> UICollectionViewCompositionalLayout {
        
        let badgeAnchor = NSCollectionLayoutAnchor(edges: [.top, .trailing], fractionalOffset: CGPoint(x: -0.5, y: 0.4))
        
        let badgeSize = NSCollectionLayoutSize(widthDimension: .absolute(20), heightDimension: .absolute(20))
        
        let badge = NSCollectionLayoutSupplementaryItem(layoutSize: badgeSize, elementKind: UserCollectionViewController.badgeElementKind, containerAnchor: badgeAnchor)
        
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))
        let item = NSCollectionLayoutItem(layoutSize: itemSize,supplementaryItems: [badge])
       
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalWidth(0.47))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: 2)
        group.interItemSpacing = .fixed(20)
        
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 20
        section.contentInsets = NSDirectionalEdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)
        
        return UICollectionViewCompositionalLayout(section: section)
    }
    
    override func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        
        // Get the item for the current cell from the data source
            guard let item = self.dataSource.itemIdentifier(for: indexPath) else { return nil }

        // Create a unique identifier for the context menu configuration
            let identifier = NSString(string: "\(item.user.id)")
        
        // Create the context menu configuration with the item's identifier and preview provider
            let configuration = UIContextMenuConfiguration(identifier: identifier, previewProvider: { () -> UIViewController? in
                
        // Return a view controller that provides a preview of the item being long-pressed
                return UserPreviewViewController(userID: item.user.id)
        }, actionProvider: { (elements) -> UIMenu? in
           
            var favoriteToggle: UIAction
            
            if item.user.id != Settings.shared.currentUser.id {
                favoriteToggle = UIAction(title: item.isFollowed ? "Unfollow" : "Follow") { [self] (action) in
                    Settings.shared.toggleFollowed(user: item.user)
                   
                    self.updateCollectionView()
                   
                }
            } else {
                favoriteToggle = UIAction(title: "You can't follow Yourself!") { (action) in
                    return
                }
            }
            return UIMenu(title: "\(item.user.name)", image: nil, options: [], children: [favoriteToggle])
        })
        
        return configuration
    }
    
    override func viewWillAppear(_ animated: Bool) {
        updateCollectionView()
    }
    
    
    @IBSegueAction private func showUserDetail(coder: NSCoder, sender: Any?) -> UserDetailViewController? {
        guard let indexPath = collectionView.indexPathsForSelectedItems?.first else {
            return nil
        }
        guard let item = dataSource.itemIdentifier(for: indexPath ) else { return nil }
      
        return UserDetailViewController(coder: coder, user: item.user, isFollowed: item.isFollowed)
    }
}

extension UserCollectionViewController {
    func configureHierarchy() {
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: createLayout())
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemBackground
        collectionView.register(UserColectionViewCell.self, forCellWithReuseIdentifier: UserColectionViewCell.reuseIdentifier)
        collectionView.register(BadgeSupplementaryView.self, forSupplementaryViewOfKind: UserCollectionViewController.badgeElementKind, withReuseIdentifier: BadgeSupplementaryView.reuseIdentifier)
        view.addSubview(collectionView)
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        collectionView.delegate = self
        
        self.performSegue(withIdentifier: "UserDetail", sender: indexPath)
    }
}

/// A view controller used for previewing and when an item is selected
private class UserPreviewViewController: UIViewController {
   
    var userID: String
    var imageRequestTask:Task<Void, Never>? = nil
    
    private let imageView = UIImageView()

    init(userID: String) {
        self.userID = userID
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        imageRequestTask = Task {
            if let userImage = try? await ImageRequest(imageID: userID).send()  {
                self.imageView.image = userImage
            }
              imageRequestTask = nil
        }
       
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFill
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        imageView.frame = view.bounds
        imageView.translatesAutoresizingMaskIntoConstraints = false
       
        view.addSubview(imageView)
        preferredContentSize = CGSize(width: 140, height: 140)
    }
}

