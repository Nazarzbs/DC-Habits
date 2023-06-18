//
//  UserStatistics.swift
//  DC Habits
//
//  Created by Nazar on 18.06.2023.
//

import Foundation

struct UserStatistics {
    let user: User
    let habitCounts: [HabitCount]
}

extension UserStatistics: Codable {
    
}
