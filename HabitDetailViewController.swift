//
//  HabitDetailViewController.swift
//  DC Habits
//
//  Created by Nazar on 22.02.2023.
//

import UIKit

struct UserStatsAndIsVisible: Hashable {
    let stats: [UserCount]
    var isVisible: Bool
    
    func hash(into hasher: inout Hasher) {
            // Include the hash values of the properties that should affect the hash value
            hasher.combine(stats)
            hasher.combine(isVisible)
        }
}

class HabitDetailViewController: UIViewController {
    
    typealias DataSourseType = UICollectionViewDiffableDataSource<ViewModel.Section, ViewModel.Item>

    var habitStatisticsRequestTask: Task<Void, Never>? = nil
    deinit { habitStatisticsRequestTask?.cancel() }

    @IBOutlet var nameLabel: UILabel!
    @IBOutlet var categoryLabel: UILabel!
    @IBOutlet var infoLabel: UILabel!
    @IBOutlet var collectionView: UICollectionView!
    
    var habit: Habit!
    
    var updateTimer: Timer?
    
    var dataSource: DataSourseType!
    var model = Model()
    
    enum ViewModel {
        enum Section {
            case leaders(count: Int)
            case remaining
        }
        
        enum Item: Comparable {
            case single(_ stat: UserCount)
            case multiple(_ stats: UserStatsAndIsVisible)
            
            static func == (lhs: Item, rhs: Item) -> Bool {
                switch (lhs, rhs) {
                case (.multiple(let lItem), .multiple(let rItem)):
                    return lItem == rItem
                case (.single(let lCount), .single(let rCount)):
                    return lCount.user == rCount.user
                default:
                    return false
                }
            }
            
            static func <(_ lhs: Item, rhs: Item) -> Bool {
                switch (lhs, rhs) {
                case (.single(let lCount), .single(let rCount)):
                    return lCount.count < rCount.count
                case (.multiple(let lCounts), .multiple(let rCounts)):
                    return lCounts.stats.first!.count < rCounts.stats.first!.count
                case (.single(let lCounts), .multiple(let rCounts)):
                    return lCounts.count < rCounts.stats.first!.count
                case (.multiple(let lCounts), .single(let rCounts)):
                    return lCounts.stats.first!.count < rCounts.count
                }
            }
        }
    }
    
    struct Model {
        var habitStatistics: HabitStatistics?
        var userCounts: [UserCount] {
            habitStatistics?.userCounts ?? []
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
        nameLabel.text = habit.name
        categoryLabel.text = habit.category.name
        infoLabel.text = habit.info
        
        dataSource = createDataSource()
        collectionView.dataSource = dataSource
        
        collectionView.collectionViewLayout = createLayout()
        
        update()
        collectionView.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder: has not been implemented")
    }
   
    init?(coder: NSCoder, habit: Habit) {
        self.habit = habit
        super.init(coder: coder)
    }
    
    func update() {
        habitStatisticsRequestTask?.cancel()
        habitStatisticsRequestTask = Task {
            if let statistics = try? await
                HabitStatisticsRequest(habitNames: [habit.name]).send(), statistics.count > 0 {
                self.model.habitStatistics = statistics[0]
            } else {
                self.model.habitStatistics = nil
            }
            
            self.updateCollectionView()
            
            habitStatisticsRequestTask = nil
        }
    }
    
    func updateCollectionView() {
        
        let allItems = (self.model.habitStatistics?.userCounts.map {
            ViewModel.Item.single($0)
        } ?? []).sorted(by: <)
        
        let itemsCountWithDuplicate = filterToGetDuplicateItemCounts(from: allItems)
        
        var singleAndMultipleItems = [HabitDetailViewController.ViewModel.Item]()
        
        singleAndMultipleItems.append(contentsOf: getSingleItems(from: allItems, itemsCountWithDuplicate: itemsCountWithDuplicate))
        
        singleAndMultipleItems.append(contentsOf: getMultipleItems(with: itemsCountWithDuplicate))
    
        singleAndMultipleItems.sort(by: >)
       
        dataSource.applySnapshotUsing(sectionIDs: [.remaining], itemsBySection: [.remaining: singleAndMultipleItems])
    }
    
    
    
    func createDataSource1() -> DataSourseType {
        return DataSourseType(collectionView: collectionView) {
            (collectionView, indexPath, grouping) -> UICollectionViewCell? in
            
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "UserCount", for: indexPath) as! UICollectionViewListCell
            
            var content = cell.defaultContentConfiguration()
        
            content.prefersSideBySideTextAndSecondaryText = true
            
            switch grouping {
            case .single(let userStat):
                
                content.text = userStat.user.name
                content.secondaryText = "\(userStat.count)"
                content.textProperties.font = .preferredFont(forTextStyle: .headline)
                content.secondaryTextProperties.font = .preferredFont(forTextStyle: .body)
                cell.contentConfiguration = content
                
                
            case .multiple(let usersStat):
                
                content.textProperties.alignment = .center

                content.text = "\(usersStat.stats.count) more have the same count of:  \(usersStat.stats.first!.count)"
                content.textProperties.numberOfLines = -1
               
                if usersStat.isVisible {
                var secondaryText: String = "\n"
                content.text = "\(usersStat.stats.count) more have the same count: "
                for user in usersStat.stats {
                        
                    secondaryText.append("\(user.user.name) of \(usersStat.stats.first!.count)\n")
                    }
                    content.secondaryText = secondaryText
                }
                
                content.secondaryTextProperties.font = .preferredFont(forTextStyle: .headline)
                content.textProperties.font = .preferredFont(forTextStyle: .body)
                cell.contentConfiguration = content
            }
            return cell
        }
    }
    
    func createDataSource() -> DataSourseType {
        collectionView.register(HabitDetailCollectionViewCell.self, forCellWithReuseIdentifier: "myCell")
        
        return DataSourseType(collectionView: collectionView) {
            (collectionView, indexPath, grouping) -> UICollectionViewCell? in
            
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "myCell", for: indexPath) as! HabitDetailCollectionViewCell
               
               // Configure the cell's content using the grouping object
               switch grouping {
               case .single(let userStat):
                   cell.leftLabel.text = userStat.user.name
                   cell.rightLabel.text = "\(userStat.count)"
                   cell.rightLabel.textAlignment = .right
                   cell.leftLabel.textAlignment = .left
                   cell.bottomLabel.text = ""
                   cell.leftLabel.numberOfLines = 1
                   cell.rightLabel.numberOfLines = 1
                   
                   cell.leftLabel.font = .preferredFont(forTextStyle: .headline)

                   cell.rightLabel.font = .preferredFont(forTextStyle: .headline)
                   
               case .multiple(let usersStat):
                   cell.leftLabel.text = "\(usersStat.stats.count) more have the same count of: "
                   cell.rightLabel.text = "\(usersStat.stats.first!.count)"
                   
                   cell.leftLabel.font = .preferredFont(forTextStyle: .body)
                   cell.rightLabel.font = .preferredFont(forTextStyle: .body)
                 
                   if usersStat.isVisible {
                       var bottomText: String = ""
                       cell.leftLabel.text = "\(usersStat.stats.count) more have the same count of: "
                       cell.rightLabel.text = "\(usersStat.stats.first!.count)"
                       for user in usersStat.stats {
                           bottomText.append("\n\(user.user.name)")
                       }
                       cell.bottomLabel.numberOfLines = 0
                       cell.bottomLabel.text = bottomText
                       
                       cell.bottomLabel.font = .preferredFont(forTextStyle: .headline)
                       
                   } else {
                       cell.bottomLabel.text = ""
                   }
               }
               
               return cell
        }
    }

    func createLayout() -> UICollectionViewCompositionalLayout {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(44))

        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 12)

        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(44))

        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: 1)

        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 20, leading: 0, bottom: 20, trailing: 0)

        return UICollectionViewCompositionalLayout(section: section)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        update()
        
        updateTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            self.update()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        updateTimer?.invalidate()
        updateTimer = nil
    }
}

extension HabitDetailViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView,
                        didSelectItemAt indexPath: IndexPath) {
        
        guard let items = dataSource.itemIdentifier(for: indexPath) else {
            collectionView.deselectItem(at: indexPath, animated: true)
            return
        }
        
        var nextItemsIndexPath: IndexPath
        
        switch items {
        case .multiple(var userStats):
            userStats.isVisible.toggle()
            
            let newItem = ViewModel.Item.multiple(userStats)
            var snapshot = dataSource.snapshot()
            
            snapshot.deleteItems([items])
            if indexPath.row > 0 {
                nextItemsIndexPath = IndexPath(row: indexPath.row - 1, section: indexPath.section)
                guard let nextItems = dataSource.itemIdentifier(for: nextItemsIndexPath) else {
                    return }
                snapshot.insertItems([newItem], afterItem: nextItems)
            } else {
                nextItemsIndexPath = IndexPath(row: 1, section: indexPath.section)
                guard let nextItems = dataSource.itemIdentifier(for: nextItemsIndexPath) else {
                    return }
                snapshot.insertItems([newItem], beforeItem: nextItems)
            }
            snapshot.reconfigureItems([newItem])
            dataSource.apply(snapshot, animatingDifferences: true)
           
        default:
            break
        }
        collectionView.deselectItem(at: indexPath, animated: true)
    }
}

extension HabitDetailViewController.ViewModel.Section: Hashable {
    func hash(into hasher: inout Hasher) {
        switch self {
        case .leaders(let count):
            hasher.combine("leaders")
            hasher.combine(count)
        case .remaining:
            hasher.combine("remaining")
        }
    }
}

extension HabitDetailViewController.ViewModel.Item: Hashable {
    func hash(into hasher: inout Hasher) {
        switch self {
        case .single(let stat):
            hasher.combine("single")
            hasher.combine(stat)
        case .multiple(let stats):
            hasher.combine("multiple")
            //By using stat including isVisible we get different hash value and it aloud snapshot to differentiate the newItem and the old one
            hasher.combine(stats)
        }
    }
}

extension  HabitDetailViewController {
    func getMultipleItems(with itemsCountWithDuplicate: [Int]) -> [HabitDetailViewController.ViewModel.Item] {
        var multipleItems = [HabitDetailViewController.ViewModel.Item]()
        for duplicateCount in itemsCountWithDuplicate {
            var isVisible = false
            let multipleItem = (self.model.habitStatistics!.userCounts.filter { $0.count == duplicateCount})
            
            isVisibleFromSnapshot().map {
                if $0.stats.first?.count == duplicateCount {
                    isVisible = $0.isVisible
                }
            }
            
            multipleItems.append(ViewModel.Item.multiple(UserStatsAndIsVisible(stats: multipleItem, isVisible: isVisible)))
        }
        return multipleItems
    }
    
    func isVisibleFromSnapshot() -> [UserStatsAndIsVisible] {
        var currentUserStatsAndIsVisible = [UserStatsAndIsVisible]()
        
        // Get the current snapshot of the data source
        let snapshot = self.dataSource.snapshot()
        // Loop through all the sections in the snapshot
        for sectionIndex in 0..<snapshot.numberOfSections {
            // Get the section identifier for the current section
            let sectionIdentifier = snapshot.sectionIdentifiers[sectionIndex]
            // Loop through all the items in the current section
            for itemIndex in 0..<snapshot.numberOfItems(inSection: sectionIdentifier) {
                // Get the item identifier for the current item
                let itemIdentifier = snapshot.itemIdentifiers(inSection: sectionIdentifier)[itemIndex]
                switch itemIdentifier {
                case .multiple(let item):
                    currentUserStatsAndIsVisible.append(item)
                case .single(_):
                    break
                }
            }
        }
        return currentUserStatsAndIsVisible
    }
    
    func getSingleItems(from allItems: [HabitDetailViewController.ViewModel.Item], itemsCountWithDuplicate: [Int]) -> [HabitDetailViewController.ViewModel.Item] {
        var singleItems = [HabitDetailViewController.ViewModel.Item]()
        for item in allItems {
            switch item {
            case .single(let item):
                if !itemsCountWithDuplicate.contains(item.count){
                    singleItems.append(ViewModel.Item.single(item))
                }
            case .multiple(_):
                break
            }
        }
     return singleItems
    }
    
    func filterToGetDuplicateItemCounts(from items: [HabitDetailViewController.ViewModel.Item]) -> [Int] {
        var itemsCount = [Int]()
        for item in items {
            switch item {
            case .single(let item):
                itemsCount.append(item.count)
            default:
                break
            }
        }
        
        var frequencyDict: [Int: Int] = [:]
        
        for count in itemsCount {
            frequencyDict[count, default: 0] += 1
        }
        
        itemsCount = itemsCount.filter {
            frequencyDict[$0, default: 0] != 1
        }
       let multipleCount = Set(itemsCount)
        
        return Array(multipleCount)
    }
}


