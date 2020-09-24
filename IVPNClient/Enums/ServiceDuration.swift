//
//  ServiceDuration.swift
//  IVPN iOS app
//  https://github.com/ivpn/ios-app
//
//  Created by Juraj Hilje on 2020-05-05.
//  Copyright (c) 2020 Privatus Limited.
//
//  This file is part of the IVPN iOS app.
//
//  The IVPN iOS app is free software: you can redistribute it and/or
//  modify it under the terms of the GNU General Public License as published by the Free
//  Software Foundation, either version 3 of the License, or (at your option) any later version.
//
//  The IVPN iOS app is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
//  or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
//  details.
//
//  You should have received a copy of the GNU General Public License
//  along with the IVPN iOS app. If not, see <https://www.gnu.org/licenses/>.
//

import Foundation

enum ServiceDuration: CaseIterable {
    
    case week
    case month
    case year
    case twoYears
    case threeYears
    
    func activeUntilFrom(date: Date) -> Date {
        var dateComponent = DateComponents()
        
        switch self {
        case .week:
            dateComponent.day = 7
        case .month:
            dateComponent.month = 1
        case .year:
            dateComponent.year = 1
        case .twoYears:
            dateComponent.year = 2
        case .threeYears:
            dateComponent.year = 3
        }
        
        return Calendar.current.date(byAdding: dateComponent, to: date) ?? date
    }
    
    func willBeActiveUntilFrom(date: Date) -> String {
        return activeUntilFrom(date: date).formatDate()
    }
    
}
