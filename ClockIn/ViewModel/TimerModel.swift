//
//  TimerModel.swift
//  ClockIn
//
//  Created by Tomasz Kubiak on 3/28/23.
//

import SwiftUI

class TimerModel: NSObject, ObservableObject {
    
    // Timer countdown total values pulled from user defaults
    @AppStorage(K.UserDefaultsKeys.workTimeInSeconds) var timerTotalSeconds: Int = 28800
    @AppStorage(K.UserDefaultsKeys.maximumOverTimeAllowedInSeconds) var overtimeTotalSeconds: Int = 18000
    
    //MARK: DATA MANAGING PROPERTIES
    private var dataManager: DataManager
    private var startDate: Date?
    private var finishDate: Date?
    
    //MARK: TIMER PROPERTIES - PUBLISHED
    //Published progress properties for UI
    @Published var progress: CGFloat = 0.0
    @Published var overtimeProgress: CGFloat = 0.0
    //Value for display
    @Published var timerStringValue: String = "00:00"
    
    @Published var secondProgress: CGFloat = 0.0
    @Published var minuteProgress: CGFloat = 0.0
    
    //Timer state properties
    @Published var isStarted: Bool = false
    @Published var isRunning: Bool = false
    @Published var progressAfterFinish: Bool = true
    
    //MARK: COUNTDOWN TIMER PROPERTIES - PRIVATE
    private var timerProvider: Timer.Type = Timer.self
    private var timer: Timer?
    private var countSeconds: Int = 0
    private var currentHours: Int {
        return countSeconds/3600
    }
    private var currentMinutes: Int {
        return (countSeconds % 3600) / 60
    }
    private var currentSeconds: Int {
        return (countSeconds % 60)
    }
    //MARK: OVERTIME TIME PROPERTIES - PRIVATE
    private var countOvertimeSeconds: Int  = 0
    private var overtimeHours: Int {
        return countOvertimeSeconds/3600
    }
    private var overtimeMinutes: Int {
        return (countOvertimeSeconds % 3600) / 60
    }
    private var overtimeSeconds: Int {
        return (countOvertimeSeconds % 60)
    }
    //MARK: BACKGROUND TIMER HANDLING PROPERTIES - PRIVATE
    private var appDidEnterBackgroundDate: Date?
    
    init(dataManager: DataManager = DataManager.shared, timerProvider: Timer.Type = Timer.self) {
        self.dataManager = dataManager
        self.timerProvider = timerProvider
        super.init()
        // initialize properties:
        countSeconds = timerTotalSeconds
        updateTimerStringValue()
        //Add observers
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    //MARK: HANDLING BACKGROUND TIMER UPDATE FUNC
    @objc private func appDidEnterBackground() {
        if isRunning {
            appDidEnterBackgroundDate = Date()
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Double(5/*countSeconds*/), repeats: false)
            checkForPermissionAndDispatch(withTrigger: trigger)
        }
    }
    
    @objc private func appWillEnterForeground() {
        guard let appDidEnterBackgroundDate else { return }
        let timeInBackground = Calendar.current.dateComponents([.second], from: appDidEnterBackgroundDate, to: Date())
        if let secondsInBackground = timeInBackground.second {
            updateTimer(subtract: secondsInBackground)
            updateTimerStringValue()
        } else {
            print("Failed to retrive seconds spend in background! Timer value is not valid!")
        }
        //remove pending notifications
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [K.Notification.identifier])
    }
    
}
    

    //MARK: TIMER START & STOP FUNCTIONS
extension TimerModel {

    func startTimer()  {
        
        startDate = Date()
        
        countSeconds = timerTotalSeconds
        countOvertimeSeconds = 0
        
        progress = 0
        overtimeProgress = 0
        // this still does not work in the background
        timer = timerProvider.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self] _ in
            guard let self else { return }
            self.updateTimer()
        })
        
        isStarted = true
        isRunning = true
    }
    
    func stopTimer() {
        if let timer = timer {
            timer.invalidate()
        }
        isStarted = false
        isRunning = false
        finishDate = Date()
        saveEntry()
    }
    
    func resumeTimer() {
        isRunning = true
    }
    
    func pauseTimer() {
        isRunning = false
    }
}
   
    //MARK: TIMER UPDATE FUNCTIONS
extension TimerModel {
    
    /**
     Updates the timer countdown value
     - Parameter subtrahend: The value to be substracted from the countdown (default is 1)
     */
    func updateTimer(subtract subtrahend: Int = 1) {
        if isStarted && isRunning {
            
            //This is the situation when the timer is still in current state after the update, including 0
            if countSeconds >= subtrahend {
                countSeconds -= subtrahend
                withAnimation(.easeInOut) {
                    progress = 1 - CGFloat(countSeconds) / CGFloat(timerTotalSeconds)
                }
                updateTimerStringValue()
                return
            }
            //this is the situation when timer value moves it into overtime
            if countSeconds < subtrahend {
                if progressAfterFinish {
                    countSeconds = 0
                    countOvertimeSeconds += subtrahend - countSeconds
                    //update the progress rings
                    withAnimation(.easeInOut) {
                        progress = 1 - CGFloat(countSeconds) / CGFloat(timerTotalSeconds)
                        overtimeProgress = CGFloat(countOvertimeSeconds) / CGFloat(overtimeTotalSeconds)
                    }
                    updateTimerStringValue()
                } else {
                    countSeconds = 0
                    withAnimation(.easeInOut) {
                        progress = 1 - CGFloat(countSeconds) / CGFloat(timerTotalSeconds)
                    }
                    updateTimerStringValue()
                    stopTimer()
                }
            }
        }
    }
    
    
    func updateSecondProgress() {
        withAnimation(.linear) {
            secondProgress = 1 - (CGFloat(currentSeconds) / CGFloat(60))
        }
    }
    
    func updateMinuteProgres() {
        withAnimation(.easeInOut) {
            minuteProgress = 1 - (CGFloat(currentMinutes) / CGFloat(60))
        }
    }
    /// Updates the timer string value with current time components if the countSeconds > 0 and with current overtime components if countSeconds = 0.
    func updateTimerStringValue() {
        if countSeconds > 0 {
            
            let hoursComponent: String = currentHours < 10 ? "0\(currentHours)" : "\(currentHours)"
            let minutesComponent: String = currentMinutes < 10 ? "0\(currentMinutes)" : "\(currentMinutes)"
            let secondsComponent: String = currentSeconds < 10 ? "0\(currentSeconds)" : "\(currentSeconds)"
            
            if currentHours > 0 {
                timerStringValue = "\(hoursComponent) : \(minutesComponent)"
            } else {
                timerStringValue = "\(minutesComponent) : \(secondsComponent)"
            }
        } else if countOvertimeSeconds == 0 && countSeconds == 0 {
            timerStringValue = "00:00"
        } else {
            
            let hoursComponent: String = overtimeHours < 10 ? "0\(overtimeHours)" : "\(overtimeHours)"
            let minutesComponent: String = overtimeMinutes < 10 ? "0\(overtimeMinutes)" : "\(overtimeMinutes)"
            let secondsComponent: String = overtimeSeconds < 10 ? "0\(overtimeSeconds)" : "\(overtimeSeconds)"
            
            if overtimeHours > 0 {
                timerStringValue = "\(hoursComponent) : \(minutesComponent)"
            } else {
                timerStringValue = "\(minutesComponent) : \(secondsComponent)"
            }
        }
    }
    
}

    //MARK: DATA OPERATIONS
extension TimerModel {
    func checkForEntry() -> Bool {
        guard let entry = dataManager.fetch(forDate: Date()) else { return false }
        return true
    }
    func saveEntry() {
        guard let startDate = startDate, let finishDate = finishDate else { return }
        
        let workTimeInSeconds = timerTotalSeconds - countSeconds
        let overTimeInSeconds = countOvertimeSeconds
        
        let entryToSave = Entry(startDate: startDate, finishDate: finishDate, workTimeInSec: workTimeInSeconds, overTimeInSec: overTimeInSeconds)
        
        dataManager.updateAndSave(entry: entryToSave)
    }
}

//MARK: NOTIFICATIONS
extension TimerModel {
    
    func checkForPermissionAndDispatch(withTrigger trigger: UNNotificationTrigger? = nil) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized:
                self.dispatch(withTrigger: trigger)
            default:
                return
            }
        }
    }
    ///dispatch a local notification with standard title and body
    ///- Parameter trigger: a UNNotificationTrigger, set to nil for dispatching now
    func dispatch(withTrigger trigger: UNNotificationTrigger? = nil) {
        
        let content = UNMutableNotificationContent()
        content.title = K.Notification.title
        content.body = K.Notification.body
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: K.Notification.identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
        
    }
}
