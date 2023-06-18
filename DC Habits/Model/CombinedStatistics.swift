//
//  CombinedStatistics.swift
//  DC Habits
//
//  Created by Nazar on 04.03.2023.
//

import Foundation

struct CombinedStatistics {
    let userStatistics: [UserStatistics]
    let habitStatistics: [HabitStatistics]
}

extension CombinedStatistics: Codable { }
