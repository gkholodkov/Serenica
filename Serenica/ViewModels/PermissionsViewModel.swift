import Foundation
import Combine
import AVFoundation
import Speech
import UserNotifications
import UIKit

enum PermissionStatus {
    case granted, denied, notDetermined, restricted
}

final class PermissionsViewModel: ObservableObject {
    @Published var notificationStatus: PermissionStatus = .notDetermined
    @Published var micStatus: PermissionStatus = .notDetermined
    @Published var speechStatus: PermissionStatus = .notDetermined
    
    init() {
        refreshStatuses()
    }
    
    func refreshStatuses() {
        checkNotificationStatus()
        checkMicStatus()
        checkSpeechStatus()
    }
    
    // MARK: - Notifications
    func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral: self.notificationStatus = .granted
                case .denied: self.notificationStatus = .denied
                case .notDetermined: self.notificationStatus = .notDetermined
                @unknown default: self.notificationStatus = .restricted
                }
            }
        }
    }
    
    func requestNotificationPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                self.checkNotificationStatus()
                completion(granted)
            }
        }
    }
    
    // MARK: - Microphone
    func checkMicStatus() {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: self.micStatus = .granted
        case .denied: self.micStatus = .denied
        case .undetermined: self.micStatus = .notDetermined
        @unknown default: self.micStatus = .restricted
        }
    }
    
    func requestMicPermission(completion: @escaping (Bool) -> Void) {
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                self.checkMicStatus()
                completion(granted)
            }
        }
    }
    
    // MARK: - Speech
    func checkSpeechStatus() {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: self.speechStatus = .granted
        case .denied: self.speechStatus = .denied
        case .notDetermined: self.speechStatus = .notDetermined
        case .restricted: self.speechStatus = .restricted
        @unknown default: self.speechStatus = .restricted
        }
    }
    
    func requestSpeechPermission(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                self.checkSpeechStatus()
                completion(status == .authorized)
            }
        }
    }
    
    // Open app settings
    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
}
