//
//  AppDelegate.swift
//  DC Habits
//
//  Created by Nazar on 22.02.2023.
//

import UIKit
import BackgroundTasks

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let temporaryDirectory = NSTemporaryDirectory()
        let urlCache = URLCache(memoryCapacity: 25_000_000, diskCapacity: 50_000_000, diskPath: temporaryDirectory)
        URLCache.shared = urlCache
        
        registerBackgroundTasks()
       
        return true
    }
    
    // MARK: Registering Launch Handlers for Tasks
    private func registerBackgroundTasks() {
        
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "Nazar-Fomenchuk.DC-Habits.refresh", using: nil) { task in
            print("Task handler")
          
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
        
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "Nazar-Fomenchuk.DC-Habits.processing", using: nil) { task in
            print("Procesing Task handler")
            self.handleAppProcessing(task: task as! BGProcessingTask)
        }
    }
    
    // MARK: - Scheduling Tasks
    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "Nazar-Fomenchuk.DC-Habits.refresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 1 * 60) // fetch after 1 minute.
        //Note :: EarliestBeginDate should not be set to too far into the future.
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("task scheduled")
        } catch {
            print("Could not schedule app refresh: \(error)")
        }
    }
    
    func scheduleAppProcessingTask() {
        let request = BGProcessingTaskRequest(identifier: "Nazar-Fomenchuk.DC-Habits.processing")
        request.requiresNetworkConnectivity = true
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule database cleaning: \(error)")
        }
    }
    
    // MARK: - Handling Launch for Tasks
    
    func handleAppRefresh(task: BGAppRefreshTask) {
        // Schedule a new refresh task.
        print("Handling task")
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
            //we will also mark the task as completed. This way we are playing nice by the system’s rules, and we will be able to get most background time we request.
        }
        
        task.setTaskCompleted(success: true)
    
        scheduleAppRefresh()
    }
    
    func handleAppProcessing(task: BGProcessingTask) {
        //Got a Bug when applying Snapshot: Thread 1: Fatal error: Unexpectedly found nil while implicitly unwrapping an Optional value.
        DispatchQueue.main.async {
//            HomeCollectionViewController.shared.update()
        }
        
        task.setTaskCompleted(success: true)
    }
    
    
    // MARK: UISceneSession Lifecycle
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
}

