//
//  PlaneCrasherApp.swift
//  Shared
//
//  Created on 8/5/25.
//

import SwiftUI

// MARK: - Save Data Structure
struct GameSaveData: Codable {
    let airfieldLine: [CGPoint]?
    let backgroundImageData: Data?
    var highScore: Int
}

// MARK: - Main App Structure
@main
struct PlaneCrasherApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
