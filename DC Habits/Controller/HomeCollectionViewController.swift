//
//  HomeCollectionViewController.swift
//  DC Habits
//
//  Created by Nazar on 22.02.2023.
//

import UIKit
import RiveRuntime
import UserNotifications

enum SupplementaryItemType {
    case collectionSupplementaryView
    case layoutDecorationView
}

protocol SupplementaryItem {
    associatedtype ViewClass: UICollectionReusableView

    var itemType: SupplementaryItemType { get }

    var reuseIdentifier: String { get }
    var viewKind: String { get }
    var viewClass: ViewClass.Type { get }
}

extension SupplementaryItem {
    func register(on collectionView: UICollectionView) {
        switch itemType {
        case .collectionSupplementaryView:
            collectionView.register(viewClass.self, forSupplementaryViewOfKind: viewKind, withReuseIdentifier: reuseIdentifier)
        case .layoutDecorationView:
            collectionView.collectionViewLayout.register(viewClass.self, forDecorationViewOfKind: viewKind)
        }
    }
}

class SectionBackgroundView: UICollectionReusableView {
    override func didMoveToSuperview() {
        backgroundColor = .clear
    }
}

class HomeCollectionViewController: UICollectionViewController {

    // keep track of async tasks so they can be cancelled when appropriate.
    var userRequestTask: Task<Void, Never>? = nil
    var habitRequestTask: Task<Void, Never>? = nil
    var imageRequestTask: Task<Void, Never>? = nil
    var combinedStatisticsRequestTask: Task<Void, Never>? = nil
    deinit {
        userRequestTask?.cancel()
        habitRequestTask?.cancel()
        imageRequestTask?.cancel()
        combinedStatisticsRequestTask?.cancel()
    }
    
    enum SupplementaryView: String, CaseIterable, SupplementaryItem {
        case leaderboardSectionHeader
        case leaderboardBackground
        case followedUsersSectionHeader
        
        var reuseIdentifier: String {
            return rawValue
        }
                
        var viewKind: String {
            return rawValue
        }
        
        var viewClass: UICollectionReusableView.Type {
            switch self {
            case .leaderboardBackground:
                return SectionBackgroundView.self
            default:
                return NamedSectionHeaderView.self
            }
        }
        
        var itemType: SupplementaryItemType {
            switch self {
            case .leaderboardBackground:
                return .layoutDecorationView
            default:
                return .collectionSupplementaryView
            }
        }
    }

    typealias DataSourceType = UICollectionViewDiffableDataSource<ViewModel.Section, ViewModel.Item>

    enum ViewModel {
        enum Section: Hashable {
            case leaderboard
            case followedUsers
        }

        enum Item: Hashable {
            case leaderboardHabit(name: String, leadingUserRanking: String?, secondaryUserRanking: String?)
            case followedUser(_ user: User, message: String, userImage: UIImage)
            
            func hash(into hasher: inout Hasher) {
                switch self {
                case .leaderboardHabit(let name, _, _):
                    hasher.combine(name)
                case .followedUser(let User, _, _):
                    hasher.combine(User)
                }
            }
            
            static func ==(_ lhs: Item, _ rhs: Item) -> Bool {
                switch (lhs, rhs) {
                case (.leaderboardHabit(let lName, _, _), .leaderboardHabit(let rName, _, _)):
                    return lName == rName
                case (.followedUser(let lUser, _, _), .followedUser(let rUser, _, _)):
                    return lUser == rUser
                default:
                    return false
                }
            }
        }
    }

    struct Model {
        var usersByID = [String: User]()
        var habitsByName = [String: Habit]()
        var usersImage = [String: UIImage]()
        var habitStatistics = [HabitStatistics]()
        var userStatistics = [UserStatistics]()
        var currentUserIsOvertakenByFollowedUser = [User:Bool]()
       

        var currentUser: User {
            return Settings.shared.currentUser
        }

        var users: [User] {
            return Array(usersByID.values)
        }

        var habits: [Habit] {
            return Array(habitsByName.values)
        }

        var followedUsers: [User] {
            return Array(usersByID.filter { Settings.shared.followedUserIDs.contains($0.key) }.values)
        }

        var favoriteHabits: [Habit] {
            return Settings.shared.favoriteHabits
        }

        var nonFavoriteHabits: [Habit] {
            return habits.filter { !favoriteHabits.contains($0) }
        }
    }

    var items: [HomeCollectionViewController.ViewModel.Item]!
    
    var model = Model() {
        didSet {
            spinner.stopAnimating()
            collectionView.isHidden = false
            UIView.animate(withDuration: 0.3) {
                self.collectionView.alpha = 1
            }
        }
    }
       
    var dataSource: DataSourceType!
    
    
    static let shared = HomeCollectionViewController()
    
    var updateTimer: Timer?
    
    let notificationCenter = UNUserNotificationCenter.current()
    
    private let spinner: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView()
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.hidesWhenStopped = true
        return spinner
    }()
    
    private func addConstraints() {
        NSLayoutConstraint.activate([
            spinner.heightAnchor.constraint(equalToConstant: 100),
            spinner.widthAnchor.constraint(equalToConstant: 100),
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }
    
    //MARK: - ViewDidload
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(spinner)
        spinner.startAnimating()
        addConstraints()
        
        notificationCenter.requestAuthorization(options: [.alert, .sound]) { (permissionGranted, error) in
            if (!permissionGranted) {
                print("Permission Denied")
            }
        }

        dataSource = createDataSource()
        collectionView.alpha = 0
        collectionView.isHidden = true
        collectionView.dataSource = dataSource
        collectionView.collectionViewLayout = createLayout()
        
        for supplementaryView in SupplementaryView.allCases {
            supplementaryView.register(on: collectionView)
        }
        
        imageRequest()

        userRequestTask = Task {
            if let users = try? await UserRequest().send() {
                self.model.usersByID = users
            }
            self.updateCollectionView()

            userRequestTask = nil
        }

        habitRequestTask = Task {
            if let habits = try? await HabitRequest().send() {
                self.model.habitsByName = habits
            }
            self.updateCollectionView()

            habitRequestTask = nil
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        imageRequest()
        update()
     
        updateTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
            self.update()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        updateTimer?.invalidate()
        updateTimer = nil
    }

    func createDataSource() -> DataSourceType {
        let dataSource = DataSourceType(collectionView: collectionView) { (collectionView, indexPath, item) -> UICollectionViewCell? in
            switch item {
            case .leaderboardHabit(let name, let leadingUserRanking, let secondaryUserRanking):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "LeaderboardHabit", for: indexPath) as! LeaderboardHabitCollectionViewCell
                cell.habitNameLabel.text = name
                cell.leaderLabel.text = leadingUserRanking
                cell.secondaryLabel.text = secondaryUserRanking
                
                cell.contentView.layer.cornerRadius = 8
                cell.layer.shadowRadius = 3
                cell.layer.shadowColor = UIColor.systemIndigo.cgColor
                cell.layer.shadowOffset = CGSize(width: 0, height: 2)
                cell.layer.shadowOpacity = 1
                cell.layer.masksToBounds = false
                
                return cell
            case .followedUser(let user, let message, let userImage):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FollowedUser", for: indexPath) as! FollowedUserCollectionViewCell
                cell.primaryTextLabel.text = user.name
                cell.secondaryTextLabel.text = message
                cell.usersImage.image = userImage
                cell.usersImage.layer.cornerRadius = min(cell.usersImage.frame.width, cell.usersImage.frame.height) / 2
                cell.usersImage.clipsToBounds = true
                cell.contentView.layer.cornerRadius = 15
                cell.layer.shadowRadius = 3
                cell.layer.shadowColor = UIColor.systemIndigo.cgColor
                cell.layer.shadowOffset = CGSize(width: 0, height: 2)
                cell.layer.shadowOpacity = 1
                cell.layer.masksToBounds = false
                if indexPath.item == collectionView.numberOfItems(inSection: indexPath.section) - 1 {
                    cell.separatorLineView.isHidden = true
                } else {
                    cell.separatorLineView.isHidden = false
                }
                return cell
            }
        }
        
        dataSource.supplementaryViewProvider = { (collectionView, kind, indexPath) in
            guard let elementKind = SupplementaryView(rawValue: kind) else { return nil }
            
            let view = collectionView.dequeueReusableSupplementaryView(ofKind: elementKind.viewKind, withReuseIdentifier: elementKind.reuseIdentifier, for: indexPath)

            switch elementKind {
            case .leaderboardSectionHeader:
                let header = view as! NamedSectionHeaderView
                header.nameLabel.text = "Leaderboard"
                header.nameLabel.font = UIFont.preferredFont(forTextStyle: .largeTitle)
                header.alignLabelToTop()
                header.backgroundColor = UIColor(displayP3Red: 255.0 / 255.0, green: 255.0 / 255.0, blue: 0, alpha: 1)
                return header
            case .followedUsersSectionHeader:
                let header = view as! NamedSectionHeaderView
                header.nameLabel.text = "Following"
                header.nameLabel.font = UIFont.preferredFont(forTextStyle: .title2)
                header.backgroundColor = UIColor(displayP3Red: 230.0 / 255.0, green: 230.0 / 255.0, blue: 255.0 / 255.0, alpha: 1)
                header.alignLabelToYCenter()
                return header
            default:
                return nil
            }
        }

        return dataSource
    }

    func createLayout() -> UICollectionViewCompositionalLayout {
        let layout = UICollectionViewCompositionalLayout { (sectionIndex, environment) -> NSCollectionLayoutSection? in
            switch self.dataSource.snapshot().sectionIdentifiers[sectionIndex] {
            case .leaderboard:
                let leaderboardItemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(0.3))
                let leaderboardItem = NSCollectionLayoutItem(layoutSize: leaderboardItemSize)

                let verticalTrioSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.75), heightDimension: .fractionalWidth(0.75))
                let leaderboardVerticalTrio = NSCollectionLayoutGroup.vertical(layoutSize: verticalTrioSize, subitem: leaderboardItem, count: 3)
                leaderboardVerticalTrio.interItemSpacing = .fixed(10)

                let leaderboardSection = NSCollectionLayoutSection(group: leaderboardVerticalTrio)
                
                let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(60))
                let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: SupplementaryView.leaderboardSectionHeader.viewKind, alignment: .top)
                
                let background = NSCollectionLayoutDecorationItem.background(elementKind: SupplementaryView.leaderboardBackground.viewKind)
                
                leaderboardSection.boundarySupplementaryItems = [header]
                leaderboardSection.decorationItems = [background]
                leaderboardSection.supplementariesFollowContentInsets = false
                
                leaderboardSection.interGroupSpacing = 30

                leaderboardSection.orthogonalScrollingBehavior = .continuous
                leaderboardSection.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20)

                return leaderboardSection
            case .followedUsers:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(100))
                let followedUserItem = NSCollectionLayoutItem(layoutSize: itemSize)
                
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(100))
                
                let followedUserGroup = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: followedUserItem, count: 1)
                
                followedUserGroup.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8)
                followedUserGroup.interItemSpacing = .fixed(25)

                let followedUserSection = NSCollectionLayoutSection(group: followedUserGroup)
                followedUserSection.interGroupSpacing = 25
                let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.06), heightDimension: .absolute(40))
                let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: SupplementaryView.followedUsersSectionHeader.viewKind, alignment: .top)
                
                followedUserSection.boundarySupplementaryItems = [header]
                followedUserSection.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 8, bottom: 0, trailing: 8)
                return followedUserSection
            }
        }

        return layout
    }

    func update() {
        combinedStatisticsRequestTask?.cancel()
        combinedStatisticsRequestTask = Task {
            if let combinedStatistics = try? await CombinedStatisticsRequest().send() {
                self.model.userStatistics = combinedStatistics.userStatistics
                self.model.habitStatistics = combinedStatistics.habitStatistics
            } else {
                self.model.userStatistics = []
                self.model.habitStatistics = []
            }
            self.updateCollectionView()
        
            combinedStatisticsRequestTask = nil
        }
    }
    
    static let formatter: NumberFormatter = {
        var f = NumberFormatter()
        f.numberStyle = .ordinal
        return f
    }()

    func ordinalString(from number: Int) -> String {
        return Self.formatter.string(from: NSNumber(integerLiteral: number + 1))!
    }
    
    func updateCollectionView() {
        var sectionIDs = [ViewModel.Section]()
        
        let leaderboardItems = model.habitStatistics.filter { statistic in
            return model.favoriteHabits.contains { $0.name == statistic.habit.name }
        }.sorted { $0.habit.name < $1.habit.name }.reduce(into: [ViewModel.Item]()) { partial, statistic in
            // Rank the user counts from highest to lowest.
            let rankedUserCounts = statistic.userCounts.sorted { $0.count > $1.count }
            
            // Find the index of the current user's count, keeping in mind that it won't exist if the user hasn't logged that habit yet.
            let myCountIndex = rankedUserCounts.firstIndex { $0.user.id == self.model.currentUser.id }
            
            func userRankingString(from userCount: UserCount) -> String {
                var name = userCount.user.name
                var ranking = ""

                if userCount.user.id == self.model.currentUser.id {
                    name = "You"
                    ranking = " (\(ordinalString(from: myCountIndex!)))"
                }

                return "\(name) \(userCount.count)" + ranking
            }
            
            var leadingRanking: String?
            var secondaryRanking: String?
            
            // Examine the number of user counts for the statistic:
            switch rankedUserCounts.count {
            case 0:
                // If 0, set the leader label to "Nobody Yet!" and leave the secondary label `nil`.
                leadingRanking = "Nobody yet!"
            case 1:
                // If 1, set the leader label to the only user and count.
                let onlyCount = rankedUserCounts.first!
                leadingRanking = userRankingString(from: onlyCount)
            default:
                // Otherwise, do the following:
                // Set the leader label to the user count at index 0.
                leadingRanking = userRankingString(from: rankedUserCounts[0])
                
                // Check whether the index of the current user's count exists and is not 0.
                if let myCountIndex = myCountIndex, myCountIndex != rankedUserCounts.startIndex {
                    // If true, the user's count and ranking should be displayed in the secondary label.
                    secondaryRanking = userRankingString(from: rankedUserCounts[myCountIndex])
                } else {
                    // If false, the second-place user count should be displayed.
                    secondaryRanking = userRankingString(from: rankedUserCounts[1])
                }
            }
            
            let leaderboardItem = ViewModel.Item.leaderboardHabit(name: statistic.habit.name, leadingUserRanking: leadingRanking, secondaryUserRanking: secondaryRanking)

            partial.append(leaderboardItem)
        }
        
        sectionIDs.append(.leaderboard)
        items = leaderboardItems
        var itemsBySection = [ViewModel.Section.leaderboard: leaderboardItems]
        
        var followedUserItems = [ViewModel.Item]()
        func loggedHabitNames(for user: User) -> Set<String> {
            var names = [String]()

            if let stats = model.userStatistics.first(where: { $0.user == user }) {
                names = stats.habitCounts.map { $0.habit.name }
            }

            return Set(names)
        }

        // Get the current user's logged habits and extract the favorites.
        let currentUserLoggedHabits = loggedHabitNames(for: model.currentUser)
        let favoriteLoggedHabits = Set(model.favoriteHabits.map { $0.name }).intersection(currentUserLoggedHabits)

        // Loop through all the followed users.
      
        for followedUser in model.followedUsers.sorted(by: { $0.name < $1.name }) {
           
            let message: String
            let followedUserLoggedHabits = loggedHabitNames(for: followedUser)
          
            let userImage = model.usersImage[followedUser.id] ?? UIImage(systemName: "person")

            // If the users have a habit in common:
            let commonLoggedHabits = followedUserLoggedHabits.intersection(currentUserLoggedHabits)

            if commonLoggedHabits.count > 0 {
                // Pick the habit to focus on.
                let habitName: String
                //get habits that is your favorite and in your followed users.
                let commonFavoriteLoggedHabits = favoriteLoggedHabits.intersection(commonLoggedHabits)

                if commonFavoriteLoggedHabits.count > 0 {
                    habitName = commonFavoriteLoggedHabits.sorted().first!
                } else {
                    habitName = commonLoggedHabits.sorted().first!
                }
                // Get the full statistics (all the user counts) for that habit
                let habitStats = model.habitStatistics.first { $0.habit.name == habitName }!
               
                // Get the ranking for each user
                let rankedUserCounts = habitStats.userCounts.sorted { $0.count > $1.count }
                let currentUserRanking = rankedUserCounts.firstIndex { $0.user == model.currentUser }!
                let followedUserRanking = rankedUserCounts.firstIndex { $0.user == followedUser }!
                
                // Construct the message depending on who's leading.
                if currentUserRanking < followedUserRanking {
                    if model.currentUserIsOvertakenByFollowedUser[followedUser] == true {
                        print("\(followedUser.name) now is behind you in \(habitName)!")
                        userNotificationLocal(notificationTitle: "\(followedUser.name) now is behind you in \(habitName)!")

                    } else {
                        print("Keep going!")
                    }
                    
                    model.currentUserIsOvertakenByFollowedUser[followedUser] = false
                  
                    message = "Currently #\(ordinalString(from: followedUserRanking)), behind you (#\(ordinalString(from: currentUserRanking))) in \(habitName).\nSend them a friendly reminder!"
                } else if currentUserRanking > followedUserRanking {
                    
                    if model.currentUserIsOvertakenByFollowedUser[followedUser] == false {
                        print("\(followedUser.name) is overtaking you in \(habitName)!")
                        userNotificationLocal(notificationTitle: "\(followedUser.name) is overtaking you in \(habitName)!")

                    } else {
                        print("Keep going!")
                    }
                    
                    model.currentUserIsOvertakenByFollowedUser[followedUser] = true
                  
                    message = "Currently #\(ordinalString(from: followedUserRanking)), ahead of you (#\(ordinalString(from: currentUserRanking))) in \(habitName).\nYou might catch up with a little extra effort!"
                } else {
                    message = "You're tied at \(ordinalString(from: followedUserRanking)) in \(habitName)! Now's your chance to pull ahead."
                }

            // Otherwise if the followed user has logged at least one habit:
            } else if followedUserLoggedHabits.count > 0 {
                // Get a (deterministic) arbitrary habit name
                let habitName = followedUserLoggedHabits.sorted().first!

                // Get the full statistics (all the user counts) for that habit
                let habitStats = model.habitStatistics.first { $0.habit.name == habitName }!

                // Get the user's ranking for that habit
                let rankedUserCounts = habitStats.userCounts.sorted { $0.count > $1.count }
                let followedUserRanking = rankedUserCounts.firstIndex { $0.user == followedUser }!

                message = "Currently #\(ordinalString(from: followedUserRanking)), in \(habitName).\nMaybe you should give this habit a look."
                
            // Otherwise this user hasn't done anything.
            } else {
                message = "This user doesn't seem to have done much yet. Check in to see if they need any help getting started."
            }
            
            followedUserItems.append(.followedUser(followedUser, message: message, userImage: userImage!))
        }
        
        sectionIDs.append(.followedUsers)
        itemsBySection[.followedUsers] = followedUserItems
        
        dataSource.applySnapshotUsing(sectionIDs: sectionIDs, itemsBySection: itemsBySection)
    }
}

//MARK: Extension of the HomeCollectionViewController

extension HomeCollectionViewController {
    
    override func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {

            updateTimer?.invalidate()

            let user = getUser(indexPath: indexPath)
            let habit = getHabit(indexPath: indexPath)
            
            let identifier = "\(user.name)" as NSString
            
        return UIContextMenuConfiguration(identifier: identifier, previewProvider: nil) { [self] suggestedAction in
            
            //create an actions for looking into user detail
            let userDetail = userDetailContextAction(user: user)
            
            //create an actions for looking into habit detail
            let habitDetail = habitDetailContextAction(habit: habit)
            
            //create an actions for follow and unfollow
            let follow = followAndUnfollowUserContextAction(user: user)
            
            let cancel = cancelContextAction()
            
            return UIMenu(title: "", children: [userDetail, habitDetail, follow, cancel])
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            let user = getUser(indexPath: indexPath)
            showUserDetailViewController(user: user)
        } else if indexPath.section == 1 {
            let habit = getHabit(indexPath: indexPath)
            showHabitDetailViewController(habit: habit)
        }
    }
    
    func imageRequest() {
        
        for followedUser in Settings.shared.followedUserIDs {
            
            imageRequestTask = Task {
                if let image = try? await ImageRequest(imageID: followedUser).send()  {
                    
                    model.usersImage[followedUser] = image
                }
            }
            imageRequestTask = nil
        }
    }

    func userDetailContextAction(user: User) -> UIAction {
        let detail = UIAction(title: "Check \(user.name) profile", image: UIImage(systemName: "person.crop.rectangle")) { action in
            self.showUserDetailViewController(user: user)
        }
        return detail
    }
    
    func followAndUnfollowUserContextAction(user: User) -> UIAction {
        var image: UIImage
        let title: String
        if !model.followedUsers.contains(user) {
            image = UIImage(systemName: "person.fill.checkmark")!
            title = "Follow: \(user.name)"
        } else {
            image = UIImage(systemName: "person.fill.xmark")!
            title = "Unfollow: \(user.name)"
        }
        
        let followOrUnfollow = UIAction(title: title , image: image) { [self] action in
            Settings.shared.toggleFollowed(user: user)
            update()
            imageRequest()
            updateTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
                self.update()
            }
        }
        return followOrUnfollow
    }
    
    func habitDetailContextAction(habit: Habit) -> UIAction {
        let detail = UIAction(title: "Give a look at \(habit.name) habit", image: UIImage(systemName: "figure.mind.and.body")) { action in
            self.showHabitDetailViewController(habit: habit)
        }
        return detail
    }
    
    func cancelContextAction() -> UIAction {
        let cancel = UIAction(title: "Cancel", image: UIImage(systemName: "xmark")) { [self] action in
            updateTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
                self.update()
            }
        }
        return cancel
    }
    
    func getHabit(indexPath: IndexPath) -> Habit {
        let items = self.dataSource.itemIdentifier(for: indexPath)
        var habitName: String = ""
        if case .followedUser(_ , let habit, _) = items {
            let components = habit.components(separatedBy: "in ")
            if components.count > 1 {
                habitName = components[1].components(separatedBy: ".").first!
            }
        } else if case .leaderboardHabit(let name , _, _) = items {
            habitName = name
        }
       
        let habit = model.habitsByName.values.filter { $0.name == habitName }.map { $0 }.first!
        return habit
    }
    
    func getUser(indexPath: IndexPath) -> User {
        let items = self.dataSource.itemIdentifier(for: indexPath)
        var userName: String = " "
        var user: User!
        if case .leaderboardHabit(_ , let item, _) = items {
            
            if let lastIndex = item!.lastIndex(of: " ") {
                userName = String(item!.prefix(upTo: lastIndex))
                user = model.users.filter { $0.name == userName }.map { $0 }.first!
            }
        } else if case .followedUser(let item, _, _) = items {
            user = item
        }
      
        return user
    }
    
    func showUserDetailViewController(user: User) {
        guard let vc = storyboard?.instantiateViewController(identifier: "UserDetail", creator: { coder in
         
            let isFollowed = Settings.shared.followedUserIDs.contains("\(user.id)")
            return UserDetailViewController(coder: coder, user: user, isFollowed: isFollowed)
        }) else {
            fatalError("Failed to load UserDetailViewController from story board")
        }
        
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func showHabitDetailViewController(habit: Habit) {
        guard let vc = storyboard?.instantiateViewController(identifier: "HabitDetail", creator: { coder in
            return HabitDetailViewController(coder: coder, habit: habit)
        }) else {
            fatalError("Failed to load HabitDetailViewController from story board")
        }
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func userNotificationLocal(notificationTitle: String) {
    
            self.notificationCenter.getNotificationSettings { (settings) in
                DispatchQueue.main.async {
                if (settings.authorizationStatus == .authorized) {
                    let content = UNMutableNotificationContent()
                    content.title = "Notification"
                    
                    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                    
                    self.notificationCenter.add(request) { (error) in
                        if (error != nil) {
                            print("Error" + error.debugDescription)
                            return
                        }
                    }
                    let ac = UIAlertController(title: notificationTitle, message: "", preferredStyle: .alert)
                    ac.addAction(UIAlertAction(title: "OK",style: .default))
                    ac.addAction(UIAlertAction(title: "Cancel",style: .cancel))
                    self.present(ac, animated: true)
                } else {
                    let ac = UIAlertController(title: "Enable Notifications?", message: "To use this feature you must enable notification in settings", preferredStyle: .alert)
                    let goToSettings = UIAlertAction(title: "Settings", style: .default) { (_) in
                        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
                            return }
                        if (UIApplication.shared.canOpenURL(settingsURL)) {
                            UIApplication.shared.open(settingsURL)
                        }
                    }
                    ac.addAction(goToSettings)
                    ac.addAction(UIAlertAction(title: "Cancel",style: .default))
                    self.present(ac, animated: true)
                    }
                }
            }
        }
    }

