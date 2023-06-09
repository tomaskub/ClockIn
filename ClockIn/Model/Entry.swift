//
//  Entry.swift
//  ClockIn
//
//  Created by Tomasz Kubiak on 4/2/23.
//

import Foundation

//front facing struct that seperates views from the coreData objects 

struct Entry: Identifiable, Hashable {
    var id: UUID
    var startDate: Date
    var finishDate: Date
    var workTimeInSeconds: Int
    var overTimeInSeconds: Int
    
    init(startDate: Date, finishDate: Date, workTimeInSec: Int, overTimeInSec: Int) {
        self.id = UUID()
        self.startDate = startDate
        self.finishDate = finishDate
        self.workTimeInSeconds = workTimeInSec
        self.overTimeInSeconds = overTimeInSec
    }
    
    ///Initialize with current date for start and finish, work time and overtime is set to 0
    init() {
        self.init(startDate: Date(), finishDate: Date(), workTimeInSec: 0, overTimeInSec: 0)
    }
}
