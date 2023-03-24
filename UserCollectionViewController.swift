//
//  UserCollectionViewController.swift
//  DC Habits
//
//  Created by Nazar on 22.02.2023.
//

import UIKit
import Foundation

class TextCell: UICollectionViewCell {
    let label = UILabel()
    static let reuseIdentifier = "text-cell-reuse-identifier"
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }
    required init?(coder: NSCoder) {
        fatalError("not implemented")
    }
}

extension TextCell {
    func configure() {
        label.translatesAutoresizingMaskIntoConstraints = false
        label.adjustsFontForContentSizeCategory = true
        contentView.addSubview(label)
        label.font = UIFont.preferredFont(forTextStyle: .caption1)
       
        let inset = CGFloat(10)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: inset),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -inset),
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: inset),
            label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -inset)
        ])
    }
}

class UserCollectionViewController: UICollectionViewController {

    //Keep track of async tasks so they can be cancelled when appropriate
    var usersRequestTask: Task<Void, Never>? = nil
    deinit { usersRequestTask?.cancel() }
    
    static let badgeElementKind = "badge-element-kind"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureHierarchy()
        dataSource = createDataSource()
        collectionView.dataSource = dataSource
        collectionView.collectionViewLayout = createLayout()
        
        update()
    }

    typealias DataSourceType = UICollectionViewDiffableDataSource<ViewModel.Section, ViewModel.Item>
    
    var dataSource: DataSourceType!
    var model = Model()
    var users: [UserCollectionViewController.ViewModel.Item] = []
    
    enum ViewModel {
        typealias Section = Int
        
        struct Item: Hashable {
            let user: User
            var isFollowed: Bool
            
            func hash(into hasher: inout Hasher) {
                hasher.combine(user)
            }
            
            static func ==(_ lhs: Item, _ rhs: Item) -> Bool {
                return lhs.user == rhs.user
            }
        }
    }
    
    func update() {
        usersRequestTask?.cancel()
        usersRequestTask = Task {
            if let users = try? await UserRequest().send() {
                self.model.userByID = users
            } else {
                self.model.userByID = [:]
            }
            self.updateCollectionView()
            
            usersRequestTask = nil
        }
    }
    
    func updateCollectionView() {
        
         users = model.userByID.values.sorted().reduce(into: [ViewModel.Item]()) {
            partial, user in
            partial.append(ViewModel.Item(user: user, isFollowed: model.followedUsers.contains(user)))
        }
        
        let itemsBySection = [0: users]
        
        dataSource.applySnapshotUsing(sectionIDs: [0], itemsBySection: itemsBySection)
        dataSource.applySnapshotUsing(sectionIDs: [0], itemsBySection: itemsBySection)
      
    }
    
    func createDataSource() -> DataSourceType {
        let dataSource = DataSourceType(collectionView: collectionView) { collectionView, indexPath, item in
            //Get a cell of the desired kind
           guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TextCell.reuseIdentifier, for: indexPath) as? TextCell else { fatalError("Cannot create new cell") }
    
            cell.label.text = item.user.name

            cell.label.textAlignment = .center
            cell.label.font = UIFont.preferredFont(forTextStyle: .title3)
           
            var backgroundConfiguration = UIBackgroundConfiguration.clear()
            
            backgroundConfiguration.backgroundColor = item.user.color?.uiColor ?? UIColor.systemGray4
            backgroundConfiguration.cornerRadius = 8
            cell.backgroundConfiguration = backgroundConfiguration
           
            return cell
        }
        
        dataSource.supplementaryViewProvider = {
            //I going to have reference to mySELF, but it is going to be WEAK / optional
            [weak self] (collectionView: UICollectionView, kind: String, indexPath: IndexPath) -> UICollectionReusableView? in
            
            guard let self = self, let model = self.dataSource.itemIdentifier(for: indexPath) else { return nil }
            
            let hasBadge = model.isFollowed
            
            //get a supplementary view of the desired kind
            
            if let badgeView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: BadgeSupplementaryView.reuseIdentifier, for: indexPath) as? BadgeSupplementaryView {
                
                //set the badge as its label (and hide the view if the user hasn't folowed by current user)
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
        
        let badgeAnchor = NSCollectionLayoutAnchor(edges: [.bottom, .trailing], fractionalOffset: CGPoint(x: 0.001, y: -0.001))
        
        let badgeSize = NSCollectionLayoutSize(widthDimension: .absolute(15), heightDimension: .absolute(15))
        
        let badge = NSCollectionLayoutSupplementaryItem(layoutSize: badgeSize, elementKind: UserCollectionViewController.badgeElementKind, containerAnchor: badgeAnchor)
        
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalHeight(1), heightDimension: .fractionalHeight(1))
        let item = NSCollectionLayoutItem(layoutSize: itemSize,supplementaryItems: [badge])
        
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalWidth(0.45))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: 2)
        group.interItemSpacing = .fixed(20)
        
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 20
        section.contentInsets = NSDirectionalEdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)
        
        return UICollectionViewCompositionalLayout(section: section)
    }
    
    struct Model {
        var userByID = [String:User]()
        var followedUsers: [User] {
            return Array(userByID.filter {
                Settings.shared.followedUserIDs.contains($0.key)
            }.values)
        }
    }
    
    
    override func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        
        let identifier = NSString(string: "\(users)")
        print(users[indexPath.item].user.id)
        return UIContextMenuConfiguration(identifier: identifier, previewProvider: { [self] in
           return UserPreviewViewController(userID: users[indexPath.item].user.id)
        }, actionProvider: { (elements) -> UIMenu? in
           
            var favoriteToggle: UIAction
            
            guard let item = self.dataSource.itemIdentifier(for: indexPath) else { return nil }
            
            
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
            return UIMenu(title: "", image: nil, options: [], children: [favoriteToggle])
        })
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
        collectionView.register(TextCell.self, forCellWithReuseIdentifier: TextCell.reuseIdentifier)
        collectionView.register(BadgeSupplementaryView.self, forSupplementaryViewOfKind: UserCollectionViewController.badgeElementKind, withReuseIdentifier: BadgeSupplementaryView.reuseIdentifier)
        view.addSubview(collectionView)
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        collectionView.delegate = self
        
        self.performSegue(withIdentifier: "UserDetail", sender: indexPath)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        update()
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
       
        view.backgroundColor = .green
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFit
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        imageView.frame = view.bounds
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(imageView)
      
        let width = 174
        let height = 174
        preferredContentSize = CGSize(width: width, height: height)
    }
}

