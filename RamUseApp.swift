//
//  RamUseApp.swift
//  RamUse
//
//  Created by Kristian Emil on 29/09/2025.
//

import SwiftUI
import AppKit
import ServiceManagement

@main
struct RamUseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    let ramManager = RAMMonitorManager()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from dock
        NSApp.setActivationPolicy(.accessory)
        
        // Create status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        guard let button = statusItem?.button else {
            print("Failed to create status bar button")
            return
        }
        
        // Set initial display
        updateMenuBar()
        
        // Set up click action
        button.target = self
        button.action = #selector(statusBarButtonClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        
        // Observe state changes to update menu bar
        setupMenuBarObserver()
    }
    
    @objc func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        
        if event.type == .rightMouseUp {
            // Right click - show menu
            showMenu(sender)
        } else {
            // Left click - open Activity Monitor
            openActivityMonitor()
        }
    }
    
    func showMenu(_ sender: NSStatusBarButton) {
        let menu = NSMenu()
        
        // Header with current usage
        let headerItem = NSMenuItem()
        headerItem.view = createHeaderView()
        menu.addItem(headerItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Memory Details
        let detailsItem = NSMenuItem(title: "Show Memory Details", action: #selector(showMemoryDetails), keyEquivalent: "")
        detailsItem.target = self
        menu.addItem(detailsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Display Format submenu
        let formatMenu = NSMenu()
        
        let percentageItem = NSMenuItem(title: "Percentage", action: #selector(setFormatPercentage), keyEquivalent: "")
        percentageItem.target = self
        percentageItem.state = (ramManager.displayFormat == .percentage) ? .on : .off
        formatMenu.addItem(percentageItem)
        
        let gbItem = NSMenuItem(title: "Gigabytes (GB)", action: #selector(setFormatGB), keyEquivalent: "")
        gbItem.target = self
        gbItem.state = (ramManager.displayFormat == .gigabytes) ? .on : .off
        formatMenu.addItem(gbItem)
        
        let mbItem = NSMenuItem(title: "Megabytes (MB)", action: #selector(setFormatMB), keyEquivalent: "")
        mbItem.target = self
        mbItem.state = (ramManager.displayFormat == .megabytes) ? .on : .off
        formatMenu.addItem(mbItem)
        
        let formatItem = NSMenuItem(title: "Display Format", action: nil, keyEquivalent: "")
        formatItem.submenu = formatMenu
        menu.addItem(formatItem)
        
        // Memory Type submenu
        let typeMenu = NSMenu()
        
        let usedItem = NSMenuItem(title: "Show Used Memory", action: #selector(setTypeUsed), keyEquivalent: "")
        usedItem.target = self
        usedItem.state = (ramManager.memoryDisplayType == .used) ? .on : .off
        typeMenu.addItem(usedItem)
        
        let freeItem = NSMenuItem(title: "Show Free Memory", action: #selector(setTypeFree), keyEquivalent: "")
        freeItem.target = self
        freeItem.state = (ramManager.memoryDisplayType == .free) ? .on : .off
        typeMenu.addItem(freeItem)
        
        let typeItem = NSMenuItem(title: "Memory Type", action: nil, keyEquivalent: "")
        typeItem.submenu = typeMenu
        menu.addItem(typeItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quick Actions
        let activityMonitorItem = NSMenuItem(title: "Open Activity Monitor", action: #selector(openActivityMonitor), keyEquivalent: "a")
        activityMonitorItem.target = self
        menu.addItem(activityMonitorItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Launch at login
        let launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginItem.target = self
        launchAtLoginItem.state = isLaunchAtLoginEnabled() ? .on : .off
        menu.addItem(launchAtLoginItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(title: "Quit RAM Monitor", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        // Show menu
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        
        // Clear menu after dismissal to restore click functionality
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.statusItem?.menu = nil
        }
    }
    
    private func createHeaderView() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 250, height: 90))
        
        // Main content stack (left-aligned)
        let contentStack = NSStackView()
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 6
        
        // Title with info button
        let titleContainer = NSView()
        
        let titleLabel = NSTextField(labelWithString: "RAM Monitor")
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleContainer.addSubview(titleLabel)
        
        // Info button in top right
        let infoButton = NSButton(image: NSImage(systemSymbolName: "info.circle", accessibilityDescription: "About")!, target: self, action: #selector(showAboutWindow))
        infoButton.isBordered = false
        infoButton.bezelStyle = .inline
        infoButton.translatesAutoresizingMaskIntoConstraints = false
        titleContainer.addSubview(infoButton)
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: titleContainer.leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: titleContainer.centerYAnchor),
            
            infoButton.trailingAnchor.constraint(equalTo: titleContainer.trailingAnchor),
            infoButton.centerYAnchor.constraint(equalTo: titleContainer.centerYAnchor),
            infoButton.widthAnchor.constraint(equalToConstant: 20),
            infoButton.heightAnchor.constraint(equalToConstant: 20),
            
            titleContainer.heightAnchor.constraint(equalToConstant: 20),
            titleContainer.widthAnchor.constraint(equalToConstant: 218)
        ])
        
        contentStack.addArrangedSubview(titleContainer)
        
        // Usage info
        let usageLabel = NSTextField(labelWithString: formattedUsageText())
        usageLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        usageLabel.textColor = .labelColor
        contentStack.addArrangedSubview(usageLabel)
        
        // Memory pressure (horizontal layout)
        let pressureContainer = NSView()
        
        let pressureLabel = NSTextField(labelWithString: "Memory Pressure:")
        pressureLabel.font = .systemFont(ofSize: 11)
        pressureLabel.textColor = .secondaryLabelColor
        
        let pressure = ramManager.memoryPressure
        
        let indicator = NSView()
        indicator.wantsLayer = true
        indicator.layer?.cornerRadius = 4
        indicator.layer?.backgroundColor = NSColor(pressure.color).cgColor
        
        let statusLabel = NSTextField(labelWithString: pressure.description)
        statusLabel.font = .systemFont(ofSize: 11, weight: .medium)
        statusLabel.textColor = NSColor(pressure.color)
        
        pressureContainer.addSubview(pressureLabel)
        pressureContainer.addSubview(indicator)
        pressureContainer.addSubview(statusLabel)
        
        pressureLabel.translatesAutoresizingMaskIntoConstraints = false
        indicator.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            pressureLabel.leadingAnchor.constraint(equalTo: pressureContainer.leadingAnchor),
            pressureLabel.centerYAnchor.constraint(equalTo: pressureContainer.centerYAnchor),
            
            indicator.leadingAnchor.constraint(equalTo: pressureLabel.trailingAnchor, constant: 8),
            indicator.widthAnchor.constraint(equalToConstant: 8),
            indicator.heightAnchor.constraint(equalToConstant: 8),
            indicator.centerYAnchor.constraint(equalTo: pressureContainer.centerYAnchor),
            
            statusLabel.leadingAnchor.constraint(equalTo: indicator.trailingAnchor, constant: 4),
            statusLabel.centerYAnchor.constraint(equalTo: pressureContainer.centerYAnchor),
            
            pressureContainer.heightAnchor.constraint(equalToConstant: 18),
            pressureContainer.widthAnchor.constraint(equalToConstant: 218)
        ])
        
        contentStack.addArrangedSubview(pressureContainer)
        
        // Add content stack to view with padding matching menu items
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentStack)
        
        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            contentStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            contentStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            contentStack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8)
        ])
        
        return view
    }
    
    private func formattedUsageText() -> String {
        let usedGB = Double(ramManager.usedMemory) / 1_073_741_824
        let totalGB = Double(ramManager.totalMemory) / 1_073_741_824
        return String(format: "%.1f / %.1f GB (%.0f%%)", usedGB, totalGB, ramManager.usagePercentage)
    }
    
    @objc func showAboutWindow() {
        let alert = NSAlert()
        alert.messageText = "RAM Monitor"
        alert.icon = NSImage(systemSymbolName: "memorychip.fill", accessibilityDescription: "RAM Monitor")
        alert.informativeText = """
        A lightweight menu bar utility for monitoring macOS memory usage.
        
        I'd love to hear your feedback!
        """
        alert.alertStyle = .informational
        
        alert.addButton(withTitle: "View on GitHub")
        alert.addButton(withTitle: "Send Feedback")
        alert.addButton(withTitle: "Close")
        
        let response = alert.runModal()
        
        switch response {
        case .alertFirstButtonReturn:
            // View on GitHub
            if let url = URL(string: "https://github.com/svidt/ram-monitor") {
                NSWorkspace.shared.open(url)
            }
        case .alertSecondButtonReturn:
            // Send Feedback (opens GitHub issues)
            if let url = URL(string: "https://github.com/svidt/ram-monitor/issues/new") {
                NSWorkspace.shared.open(url)
            }
        default:
            break
        }
    }
    
    @objc func showMemoryDetails() {
        let alert = NSAlert()
        alert.messageText = "Memory Breakdown"
        alert.informativeText = """
        Wired: \(ramManager.formatBytes(ramManager.wiredMemory, as: .gigabytes))
        Active: \(ramManager.formatBytes(ramManager.activeMemory, as: .gigabytes))
        Inactive: \(ramManager.formatBytes(ramManager.inactiveMemory, as: .gigabytes))
        Compressed: \(ramManager.formatBytes(ramManager.compressedMemory, as: .gigabytes))
        Free: \(ramManager.formatBytes(ramManager.freeMemory, as: .gigabytes))
        
        Total: \(ramManager.formatBytes(ramManager.totalMemory, as: .gigabytes))
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc func setFormatPercentage() {
        ramManager.displayFormat = .percentage
        ramManager.savePreferences()
        updateMenuBar()
    }
    
    @objc func setFormatGB() {
        ramManager.displayFormat = .gigabytes
        ramManager.savePreferences()
        updateMenuBar()
    }
    
    @objc func setFormatMB() {
        ramManager.displayFormat = .megabytes
        ramManager.savePreferences()
        updateMenuBar()
    }
    
    @objc func setTypeUsed() {
        ramManager.memoryDisplayType = .used
        ramManager.savePreferences()
        updateMenuBar()
    }
    
    @objc func setTypeFree() {
        ramManager.memoryDisplayType = .free
        ramManager.savePreferences()
        updateMenuBar()
    }
    
    @objc func openActivityMonitor() {
        let activityMonitorURL = URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app")
        NSWorkspace.shared.openApplication(at: activityMonitorURL, configuration: NSWorkspace.OpenConfiguration()) { app, error in
            if let error = error {
                print("Failed to open Activity Monitor: \(error)")
            }
        }
    }
    
    @objc func toggleLaunchAtLogin() {
        if isLaunchAtLoginEnabled() {
            disableLaunchAtLogin()
        } else {
            enableLaunchAtLogin()
        }
    }
    
    func isLaunchAtLoginEnabled() -> Bool {
        return SMAppService.mainApp.status == .enabled
    }
    
    func enableLaunchAtLogin() {
        do {
            try SMAppService.mainApp.register()
        } catch {
            print("Failed to enable launch at login: \(error)")
        }
    }
    
    func disableLaunchAtLogin() {
        do {
            try SMAppService.mainApp.unregister()
        } catch {
            print("Failed to disable launch at login: \(error)")
        }
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    func updateMenuBar() {
        guard let button = statusItem?.button else { return }
        
        // Set icon
        button.image = NSImage(systemSymbolName: "memorychip.fill", accessibilityDescription: "RAM Monitor")
        
        // Set text
        button.title = " " + ramManager.formattedMenuBarText()
    }
    
    func setupMenuBarObserver() {
        // Update menu bar every 2 seconds
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateMenuBar()
        }
    }
}
