import Foundation
import UserNotifications

// MARK: - Notification Service

class NotificationService: ObservableObject {
    static let shared = NotificationService()

    private init() {
        requestAuthorization()
    }

    // MARK: - Authorization

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✓ Notification authorization granted")
            } else if let error = error {
                print("✖ Notification authorization error:", error.localizedDescription)
            }
        }
    }

    // MARK: - macOS System Notifications

    func sendSystemNotification(title: String, body: String, urgent: Bool = false) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = urgent ? .defaultCritical : .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Immediate delivery
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("✖ Failed to send notification:", error.localizedDescription)
            }
        }
    }

    // MARK: - Telegram Notifications

    func sendTelegram(_ message: String) {
        // Use Clawdbot to send Telegram message
        let script = """
        #!/bin/bash
        cd ~/.clawdbot
        node send-telegram.js "\(message.replacingOccurrences(of: "\"", with: "\\\""))"
        """

        executeScript(script)
    }

    // MARK: - WhatsApp Notifications

    func sendWhatsApp(_ message: String) {
        // Use Clawdbot to send WhatsApp message
        let script = """
        #!/bin/bash
        cd ~/.clawdbot
        node send-whatsapp.js "\(message.replacingOccurrences(of: "\"", with: "\\\""))"
        """

        executeScript(script)
    }

    // MARK: - Script Execution

    private func executeScript(_ script: String) {
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", script]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()

            if task.terminationStatus != 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                print("✖ Script execution failed:", output)
            }
        } catch {
            print("✖ Failed to execute script:", error.localizedDescription)
        }
    }

    // MARK: - Claude CLI Execution

    func executeClaude(prompt: String, completion: @escaping (String?) -> Void) {
        let script = """
        #!/bin/bash
        claude --non-interactive "\(prompt.replacingOccurrences(of: "\"", with: "\\\""))"
        """

        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", script]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()

            DispatchQueue.global(qos: .background).async {
                task.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)

                DispatchQueue.main.async {
                    completion(output)
                }
            }
        } catch {
            print("✖ Failed to execute Claude CLI:", error.localizedDescription)
            completion(nil)
        }
    }
}
