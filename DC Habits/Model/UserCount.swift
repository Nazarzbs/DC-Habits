//
//  UserCount.swift
//  DC Habits
//
//  Created by Nazar on 27.02.2023.
//

import Foundation

struct UserCount {
    let user: User
    let count: Int
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(user)
    }
    
    static func ==(_ lhs: UserCount, _ rhs: UserCount) -> Bool {
        return lhs.user == rhs.user
    }
}

extension UserCount: Codable {
    
}

extension UserCount: Hashable {
}
