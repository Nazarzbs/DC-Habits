//
//  HabitCollectionViewController.swift
//  DC Habits
//
//  Created by Nazar on 22.02.2023.
//

import UIKit

private let reuseIdentifier = "Cell"

let favoriteHabitColor = UIColor(displayP3Red: 255.0 / 255.0, green: 255.0 / 255.0, blue: 153 / 255.0, alpha: 1)

class HabitCollectionViewController: UICollectionViewController {
    
    
    
    var habitsRequestTask: Task<Void, Never>? = nil
    deinit { habitsRequestTask?.cancel() }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        dataSource = createDataSource()
        collectionView.dataSource = dataSource
        collectionView.collectionViewLayout = createLayout()
        collectionView.register(NamedSectionHeaderView.self, forSupplementaryViewOfKind: SectionHeader.kind.identifier, withReuseIdentifier: SectionHeader.reuse.identifier)
        
    }

    typealias DataSourceType = UICollectionViewDiffableDataSource<ViewModel.Section, ViewModel.Item>
    
    enum ViewModel {
        enum Section: Hashable, Comparable {
            case favorites
            case category(_ category: Category)
            
            static func < (lhs: Section, rhs: Section) -> Bool {
                switch (lhs, rhs) {
                case (.category(let l), category(let r)):
                    return l.name < r.name
                case (.favorites, _):
                    return true
                case (_, favorites):
                    return false
                }
            }
            
            var sectionColor: UIColor {
                switch self {
                case .favorites:
                    return favoriteHabitColor
                case .category(let cetegory):
                    return cetegory.color.uiColor
                }
            }
        }
        typealias Item = Habit
    }
    
    enum SectionHeader: String {
        case kind = "SectionHeader"
        case reuse = "HeaderView"
        
        var identifier: String {
            return rawValue
        }
    }
    
    struct Model {
        var habitsByName = [String: Habit]()
        var favoriteHabits: [Habit] {
            return Settings.shared.favoriteHabits
        }
    }
    
    var dataSource: DataSourceType!
    var model = Model()
    
    func update() {
        habitsRequestTask?.cancel()
        habitsRequestTask = Task {
            if let habits = try? await HabitRequest().send() {
                self.model.habitsByName = habits
            } else {
                    self.model.habitsByName = [:]
                }
                self.updateCollectionView()
                
                habitsRequestTask = nil
            }
        }
    
    func updateCollectionView() {
        
        var itemsBySection = model.habitsByName.values.reduce(into: [ViewModel.Section: [ViewModel.Item]]()) { partial, habit in
            let item = habit
            
            let section: ViewModel.Section
            if model.favoriteHabits.contains(habit) {
                section = .favorites
            } else {
                section = .category(habit.category)
            }
            
            partial[section, default: []].append(item)
            }
        itemsBySection = itemsBySection.mapValues {
            $0.sorted()
        }
        
        let sectionIDs = itemsBySection.keys.sorted()
        dataSource.applySnapshotUsing(sectionIDs: sectionIDs, itemsBySection: itemsBySection)
        }
    
  func configureCell(withItem cell: UICollectionViewListCell, _ item: HabitCollectionViewController.ViewModel.Item) {
        var content = cell.defaultContentConfiguration()
        content.text = item.name
        cell.contentConfiguration = content
    }
    
    func createDataSource() -> DataSourceType {
        
        
        let dataSource = DataSourceType(collectionView: collectionView) {
            (collectionView, indexPath, item) in
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Habit", for: indexPath) as! UICollectionViewListCell
            
            self.configureCell(withItem: cell, item)
            
            return cell
        }
        
        dataSource.supplementaryViewProvider = { (collectionView, kind, indexPath) in
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: SectionHeader.kind.rawValue, withReuseIdentifier: SectionHeader.reuse.rawValue, for: indexPath) as! NamedSectionHeaderView
            
            let section = dataSource.snapshot().sectionIdentifiers[indexPath.section]
            switch section {
            case .favorites:
                header.nameLabel.text = "Favorites"
                header.backgroundColor = section.sectionColor
            case .category(let category):
                header.nameLabel.text = category.name
                header.backgroundColor = section.sectionColor
            }
            return header
        }
        return dataSource
    }
    
    func createLayout() -> UICollectionViewCompositionalLayout {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(44))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: 1)
        let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(36))
        let sectionHeader = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: "SectionHeader", alignment: .top)
        sectionHeader.pinToVisibleBounds = true
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10)
        section.boundarySupplementaryItems = [sectionHeader]
        return UICollectionViewCompositionalLayout(section: section)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        update()
    }
    
    override func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let config = UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let item = self.dataSource.itemIdentifier(for: indexPath)!
            
            let favoriteToggle = UIAction(title: self.model.favoriteHabits.contains(item) ? "Unfavorite" : "Favorite") {
                (action) in
                Settings.shared.toggleFavorite(item)
                self.updateCollectionView()
            }
            return UIMenu(title: "", image: nil, identifier: nil, options: [], children: [favoriteToggle])
        }
    return config
    }
   
    @IBSegueAction func showHabitDetail(_ coder: NSCoder, sender: Any?) -> HabitDetailViewController? {
        guard let cell = sender,
              let indexPath = collectionView.indexPath(for: cell as! UICollectionViewCell),
                let item = dataSource.itemIdentifier(for: indexPath) else {
            return nil
        }
        return HabitDetailViewController(coder: coder, habit: item)
    }
}
