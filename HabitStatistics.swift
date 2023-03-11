//
//  HabitStatistics.swift
//  DC Habits
//
//  Created by Nazar on 27.02.2023.
//

import Foundation

struct HabitStatistics {
    let habit: Habit
    let userCounts: [UserCount]
}

extension HabitStatistics: Codable {
    
}
