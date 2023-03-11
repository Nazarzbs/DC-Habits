//
//  LoggedHabit.swift
//  DC Habits
//
//  Created by Nazar on 04.03.2023.
//

import Foundation

struct LoggedHabit {
    let userID: String
    let habitName: String
    let timestamp: Date
}

extension LoggedHabit: Codable { } 
