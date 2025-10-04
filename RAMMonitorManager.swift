//
//  RAMMonitorManager.swift
//  RamUse
//
//  Observable class to manage RAM monitoring state
//

import Foundation
import SwiftUI

enum DisplayFormat: String, Codable {
    case percentage     // Show as percentage (65%)
    case gigabytes      // Show as GB (8.2 GB)
    case megabytes      // Show as MB (8192 MB)
}

enum MemoryDisplayType: String, Codable {
    case used           // Show used memory
    case free           // Show free/available memory
}

@Observable
class RAMMonitorManager {
    var displayFormat: DisplayFormat = .percentage
    var memoryDisplayType: MemoryDisplayType = .used
    
    // Memory statistics
    var wiredMemory: UInt64 = 0
    var activeMemory: UInt64 = 0
    var inactiveMemory: UInt64 = 0
    var compressedMemory: UInt64 = 0
    var freeMemory: UInt64 = 0
    var totalMemory: UInt64 = 0
    
    private var updateTimer: Timer?
    
    // Computed properties
    var usedMemory: UInt64 {
        wiredMemory + activeMemory + inactiveMemory + compressedMemory
    }
    
    var availableMemory: UInt64 {
        freeMemory + inactiveMemory
    }
    
    var usagePercentage: Double {
        guard totalMemory > 0 else { return 0 }
        return Double(usedMemory) / Double(totalMemory) * 100
    }
    
    var freePercentage: Double {
        guard totalMemory > 0 else { return 0 }
        return Double(freeMemory) / Double(totalMemory) * 100
    }
    
    var memoryPressure: (color: Color, description: String) {
        let usageRatio = Double(usedMemory) / Double(totalMemory)
        let availableRatio = Double(availableMemory) / Double(totalMemory)
        
        if usageRatio > 0.85 || availableRatio < 0.1 {
            return (.red, "High")
        } else if usageRatio > 0.70 || availableRatio < 0.2 {
            return (.orange, "Medium")
        } else {
            return (.green, "Low")
        }
    }
    
    init() {
        loadPreferences()
        startMonitoring()
    }
    
    func startMonitoring() {
        // Update immediately
        updateMemoryStats()
        
        // Update every 2 seconds
        updateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateMemoryStats()
        }
    }
    
    func stopMonitoring() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    private func updateMemoryStats() {
        totalMemory = ProcessInfo.processInfo.physicalMemory
        
        var vmStats = vm_statistics64()
        var vmStatsCount = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                host_statistics64(mach_host_self(),
                                HOST_VM_INFO64,
                                $0,
                                &vmStatsCount)
            }
        }
        
        if result == KERN_SUCCESS {
            let pageSize = UInt64(vm_kernel_page_size)
            
            wiredMemory = UInt64(vmStats.wire_count) * pageSize
            activeMemory = UInt64(vmStats.active_count) * pageSize
            inactiveMemory = UInt64(vmStats.inactive_count) * pageSize
            compressedMemory = UInt64(vmStats.compressor_page_count) * pageSize
            freeMemory = UInt64(vmStats.free_count) * pageSize
        }
    }
    
    // Formatting helpers
    func formattedMenuBarText() -> String {
        let value: Double
        let suffix: String
        
        switch displayFormat {
        case .percentage:
            if memoryDisplayType == .used {
                return String(format: "%.0f%%", usagePercentage)
            } else {
                return String(format: "%.0f%% free", freePercentage)
            }
            
        case .gigabytes:
            if memoryDisplayType == .used {
                value = Double(usedMemory) / 1_073_741_824
                suffix = "GB"
            } else {
                value = Double(freeMemory) / 1_073_741_824
                suffix = "GB free"
            }
            return String(format: "%.1f %@", value, suffix)
            
        case .megabytes:
            if memoryDisplayType == .used {
                value = Double(usedMemory) / 1_048_576
                suffix = "MB"
            } else {
                value = Double(freeMemory) / 1_048_576
                suffix = "MB free"
            }
            return String(format: "%.0f %@", value, suffix)
        }
    }
    
    func formatBytes(_ bytes: UInt64, as format: DisplayFormat) -> String {
        switch format {
        case .percentage:
            let percentage = Double(bytes) / Double(totalMemory) * 100
            return String(format: "%.1f%%", percentage)
        case .gigabytes:
            return String(format: "%.2f GB", Double(bytes) / 1_073_741_824)
        case .megabytes:
            return String(format: "%.0f MB", Double(bytes) / 1_048_576)
        }
    }
    
    private func loadPreferences() {
        if let formatString = UserDefaults.standard.string(forKey: "displayFormat"),
           let format = DisplayFormat(rawValue: formatString) {
            displayFormat = format
        }
        
        if let typeString = UserDefaults.standard.string(forKey: "memoryDisplayType"),
           let type = MemoryDisplayType(rawValue: typeString) {
            memoryDisplayType = type
        }
    }
    
    func savePreferences() {
        UserDefaults.standard.set(displayFormat.rawValue, forKey: "displayFormat")
        UserDefaults.standard.set(memoryDisplayType.rawValue, forKey: "memoryDisplayType")
    }
    
    deinit {
        stopMonitoring()
        savePreferences()
    }
}
