//
//  UserDetailViewController.swift
//  DC Habits
//
//  Created by Nazar on 22.02.2023.
//

import UIKit

class UserDetailViewController: UIViewController {
    
    typealias DataSourseType = UICollectionViewDiffableDataSource<ViewModel.Section, ViewModel.Item>
    
    typealias DataSourceTypeForSortedHabit = UICollectionViewDiffableDataSource<ViewModelForHabitSortedByCountAndRank.SectionForHabitSortedByCountAndRank, ViewModelForHabitSortedByCountAndRank.ItemByCount>
    
    enum SectionHeader: String {
        case kind = "SectinHeader"
        case reuse = "HeaderView"
        
        var identifier: String {
            return rawValue
        }
    }
    
    enum ViewModel {
        enum Section: Hashable, Comparable {
            case leading
            case category(_ category: Category)
            
            static func < (lhs: Section, rhs: Section) -> Bool {
                switch (lhs, rhs) {
                case (.leading, .category), (.leading, .leading):
                    return true
                case (.category, .leading):
                    return false
                case (category(let category1), category(let category2)):
                    return category1.name > category2.name
                }
            }
        }
        typealias Item = HabitCount
    }
    
    struct Model {
        var userStats: UserStatistics?
        var leadingStats: UserStatistics?
        
        var habitStatistics = [HabitStatistics]()
        
        var habitRank: HabitRank?
    }
    
    var updateTimer: Timer?
    
    var imageRequestTask:Task<Void, Never>? = nil
    var userStatisticsRequestTask:Task<Void, Never>? = nil
    var habitLeadStatisticsRequestTask:Task<Void, Never>? = nil
    
    var habitStatisticsRequestTask: Task<Void, Never>? = nil
    
    deinit {
        imageRequestTask?.cancel()
        userStatisticsRequestTask?.cancel()
        habitLeadStatisticsRequestTask?.cancel()
    }
    
    var dataSource: DataSourseType!
    var dataSourceForHabitSortedByCountAndRank: DataSourceTypeForSortedHabit!

    var model = Model()
    var user: User!
    var previousSection: Int! = 0
    
    var barButton: UIBarButtonItem!
    var isFollowed: Bool
    
    func toggleFollowed() -> UIImage {
        switch isFollowed {
        case true:
            return UIImage(named: "circleCheckMark2")!
        case false:
            return UIImage(named: "circleCheckMark1")!
        }
    }
    
    @IBOutlet var profileImageView: UIImageView!
    @IBOutlet var userNameLabel: UILabel!
    @IBOutlet var bioLabel: UILabel!
    @IBOutlet var collectionView: UICollectionView!
    
    @IBOutlet var segmentControl: UISegmentedControl!
    
//MARK: viewDidLoad
    override func viewDidLoad() {
        super.viewDidLoad()
        barButton = UIBarButtonItem(image: toggleFollowed(), style: .done, target: self, action: #selector(toggleFollowedButtonTapped))
       
        navigationItem.rightBarButtonItem = barButton
        imageRequestTask = Task {
            if let image = try? await ImageRequest(imageID: user.id).send() {
                self.profileImageView.image = image
            }
              imageRequestTask = nil
        }
        
        userNameLabel.text = user.name
        bioLabel.text = user.bio
        
        collectionView.register(NamedSectionHeaderView.self, forSupplementaryViewOfKind: SectionHeader.kind.identifier, withReuseIdentifier: SectionHeader.reuse.identifier)
        
        dataSource = createDataSource()
        collectionView.dataSource = dataSource
        collectionView.collectionViewLayout = createLayout()
        view.backgroundColor = user.color?.uiColor ?? .white
                
        let tabBarAppearence = UITabBarAppearance()
        tabBarAppearence.backgroundColor = .quaternarySystemFill
        tabBarController?.tabBar.scrollEdgeAppearance = tabBarAppearence
        let navBarAppearence = UINavigationBarAppearance()
        navBarAppearence.backgroundColor = .quaternarySystemFill
        navigationItem.scrollEdgeAppearance = navBarAppearence
        
        update()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder: ) has not been implemented")
    }
    
    init?(coder: NSCoder, user: User, isFollowed: Bool) {
        self.isFollowed = isFollowed
        self.user = user
        super.init(coder: coder)
    }
    
    @objc func toggleFollowedButtonTapped() {
        
        Settings.shared.toggleFollowed(user: user)
        isFollowed.toggle()
        barButton.image = toggleFollowed()
        }
    
    func update() {
        
        userStatisticsRequestTask?.cancel()
        userStatisticsRequestTask = Task {
            if let userStats = try? await UserStatisticsRequest(userIDs: [user.id]).send(), userStats.count > 0 {
                self.model.userStats = userStats[0]
            } else {
                self.model.userStats = nil
            }

            userStatisticsRequestTask = nil
        }
        
        habitLeadStatisticsRequestTask?.cancel()
        habitLeadStatisticsRequestTask = Task {
            if let userStats = try? await
                HabitLeadStatisticsRequest(userID: user.id).send() {
                self.model.leadingStats = userStats
            } else {
                self.model.leadingStats = nil
            }
            
            habitLeadStatisticsRequestTask = nil
        }
        
        habitStatisticsRequestTask = Task {
            if let combinedStatistics = try? await CombinedStatisticsRequest().send() {
                self.model.habitStatistics = combinedStatistics.habitStatistics
            }
           
            habitStatisticsRequestTask = nil
        }
        
        if let segmentControl = segmentControl {
            let selectedSegmentIndex = segmentControl.selectedSegmentIndex
            switch selectedSegmentIndex {
            case 0:
                //category
                self.updateCollectionView()
            case 1, 2:
                //current position
                self.updateCollectionViewForHabitSortedByCountAndRank()
            default:
                break
            }
        }
    }
    
    func updateCollectionView() {
        guard let userStatistics = model.userStats, let leadingStatistiscs = model.leadingStats else { return }
        var itemsBySection = userStatistics.habitCounts.reduce(into: [ViewModel.Section: [ViewModel.Item]]()) { partial, habitCount in
            let section: ViewModel.Section
            
            if leadingStatistiscs.habitCounts.contains(habitCount) {
                section = .leading
            } else {
                section = .category(habitCount.habit.category)
            }
            partial[section, default: []].append(habitCount)
        }
        itemsBySection = itemsBySection.mapValues { $0.sorted() }
        let sectionIDs = itemsBySection.keys.sorted()
        
        dataSource.applySnapshotUsing(sectionIDs: sectionIDs, itemsBySection: itemsBySection)
    }
    
    func createDataSource() -> DataSourseType {
        let dataSource = DataSourseType(collectionView: collectionView) { [self]
            (collectionView, indexPath, habitStat) -> UICollectionViewCell? in
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "HabitCount", for: indexPath) as! UICollectionViewListCell
            
            var content = UIListContentConfiguration.subtitleCell()
            content.text = habitStat.habit.name
            content.secondaryText = "\(habitStat.count)"
           
            content.prefersSideBySideTextAndSecondaryText = true
            content.textProperties.font = .preferredFont(forTextStyle: .headline)
            content.secondaryTextProperties.font = .preferredFont(forTextStyle: .body)
            cell.contentConfiguration = content
            
            cell.layer.cornerRadius = 5
            cell.contentView.layer.backgroundColor = getCategoryColor(hue: habitStat.habit.category.color.hue)
           
            return cell
        }
        
        dataSource.supplementaryViewProvider = { (collectionView, category, indexPath) in
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: SectionHeader.kind.identifier, withReuseIdentifier: SectionHeader.reuse.identifier, for: indexPath) as! NamedSectionHeaderView
            
            let section = dataSource.snapshot().sectionIdentifiers[indexPath.section]
            switch section {
            case .leading:
                header.nameLabel.text = "Leading"
            case .category(let category):
                header.nameLabel.text = category.name
            }
            return header
        }
        return dataSource
    }
    
    func createLayout() -> UICollectionViewCompositionalLayout {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 6, bottom: 0, trailing: 6)
        
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(44))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: 1)
        group.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0)
        
        let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(36))

        let sectionHeader = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: SectionHeader.kind.identifier, alignment: .top)
        sectionHeader.pinToVisibleBounds = true
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 0, bottom: 20, trailing: 0)
        section.boundarySupplementaryItems = [sectionHeader]
        
        return UICollectionViewCompositionalLayout(section: section)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.update()
            
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [self] _ in
            
            self.update()
            }
        }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    @IBAction func didChangeSegment(_ sender: UISegmentedControl) {
        if sender.selectedSegmentIndex == 0 {
            dataSource = createDataSource()
            collectionView.dataSource = dataSource
            collectionView.collectionViewLayout = createLayout()
            update()
            previousSection = 0
        } else if sender.selectedSegmentIndex == 1 {
        
            if previousSection == 0 {
                dataSourceForHabitSortedByCountAndRank = crateDataSourceForHabitSortedByCountAndRank()
                collectionView.dataSource = dataSourceForHabitSortedByCountAndRank
                collectionView.collectionViewLayout = createLayoutForHabitSortedByCountAndByRank()
                self.update()
                previousSection = 1
            }
        } else if sender.selectedSegmentIndex == 2 {
            if previousSection == 0 {
                dataSourceForHabitSortedByCountAndRank = crateDataSourceForHabitSortedByCountAndRank()
                collectionView.dataSource = dataSourceForHabitSortedByCountAndRank
                collectionView.collectionViewLayout = createLayoutForHabitSortedByCountAndByRank()
                self.update()
                previousSection = 2
            }
        }
    }
}

//MARK: EXTENTION
extension UserDetailViewController {
    enum ViewModelForHabitSortedByCountAndRank {
        enum SectionForHabitSortedByCountAndRank {
            case second
        }
        typealias ItemByCount = HabitRank
    }
    
    func crateDataSourceForHabitSortedByCountAndRank() -> DataSourceTypeForSortedHabit {
        let dataSource = DataSourceTypeForSortedHabit(collectionView: collectionView) { [self] (collectionView, indexPath, habitRank) -> UICollectionViewCell? in
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "HabitCount", for: indexPath) as! UICollectionViewListCell
            
            var content = UIListContentConfiguration.sidebarSubtitleCell()
            
            content.text = "#\(habitRank.rank) in \(habitRank.habitCount.habit.name)"
            
            content.secondaryText = "with score of \(habitRank.habitCount.count)"
           
            content.prefersSideBySideTextAndSecondaryText = true
            content.textProperties.font = .preferredFont(forTextStyle: .headline)
            content.secondaryTextProperties.font = .preferredFont(forTextStyle: .body)
            cell.layer.cornerRadius = 5
            cell.contentConfiguration = content
            
            cell.contentView.layer.backgroundColor = getCategoryColor(hue: habitRank.habitCount.habit.category.color.hue)
           
            cell.contentView.layer.shadowColor = getCategoryColor(hue: habitRank.habitCount.habit.category.color.hue)
           
            return cell
        }
        
        return dataSource
    }
    
    func createLayoutForHabitSortedByCountAndByRank() -> UICollectionViewCompositionalLayout {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1.1))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8)
            
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(50))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: 1)
        
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets =  NSDirectionalEdgeInsets(top: 6, leading: 0, bottom: 0, trailing: 0)
        
        return UICollectionViewCompositionalLayout(section: section)
    }
    
    func updateCollectionViewForHabitSortedByCountAndRank() {
        guard let userStatistics = model.userStats?.habitCounts else { return }
        
        var snapshot = NSDiffableDataSourceSnapshot<ViewModelForHabitSortedByCountAndRank.SectionForHabitSortedByCountAndRank, ViewModelForHabitSortedByCountAndRank.ItemByCount>()
        
        snapshot.appendSections([.second])

        var items = [HabitRank]()
        
        for statistics in userStatistics.sorted(by: { $0.habit > $1.habit }) {
            let habitStats = model.habitStatistics.first { $0.habit.name == statistics.habit.name }!
           
            let rankedUserCounts = habitStats.userCounts.sorted { $0.count > $1.count }
            
            let currentUserRanking = rankedUserCounts.firstIndex { $0.user == model.userStats?.user}!
            
            items.append(HabitRank(habitCount: statistics, rank: Int(currentUserRanking + 1)))
        }
        
        var sortedItems = [HabitRank]()
      
        if let segmentControl = segmentControl {
            let selectedSegmentIndex = segmentControl.selectedSegmentIndex
    
            switch selectedSegmentIndex {
            case 2:
                sortedItems = items.sorted { $0.rank < $1.rank }               
            case 1:
                sortedItems = items.sorted { $0.habitCount.count > $1.habitCount.count }
            default:
                break
            }
        }
        
        snapshot.appendItems(sortedItems)
        snapshot.reloadItems(sortedItems)
                        
        dataSourceForHabitSortedByCountAndRank.apply(snapshot, animatingDifferences: true, completion: nil)
    }
    
    func getCategoryColor(hue: Double) -> CGColor {
        let colorSaturation = Color(hue: hue, saturation: 0.5, brightness: 1)
        let color = colorSaturation.uiColor.cgColor
        let uiColor = UIColor(cgColor: color)
        let cgColor = uiColor.cgColor
        return cgColor
    }
}

