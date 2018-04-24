//
//  CaldendarExtension.swift
//  cs390final
//
//  Created by Jucong He on 4/23/18.
//  Copyright © 2018 JucongHe. All rights reserved.
//

import Foundation
import EventKit
import SwiftyJSON

extension ViewController {
    func getTodayEvent() -> String{
        print("Getting event")
        var today = Date()
        var tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .none
        
        today = dateFormatter.date(from: dateFormatter.string(from: today))!
        tomorrow = dateFormatter.date(from: dateFormatter.string(from: tomorrow))!
        let calendars = eventStore.calendars(for: .event)
        let predicate = eventStore.predicateForEvents(withStart: today, end: tomorrow, calendars: calendars)
        
        var eventInfo: [Dictionary<String, [String]>] = []
        for event in eventStore.events(matching: predicate) {
            dateFormatter.dateFormat = "hh:mm a"
            let startDateStr = dateFormatter.string(from: event.startDate)
            let endDateStr = dateFormatter.string(from: event.endDate)
            eventInfo.append([event.title:[startDateStr, endDateStr]])
        }
        let json = JSON(eventInfo)
        return json.rawString()!
    }
}
