//
//  AlertView.swift
//  Serenica
//
//  Created by Checkito12 on 07.02.25.
//

import SwiftUI

// MARK: - Alert Configuration & Supporting Types

struct AlertConfiguration {
    var assignReminder: Bool = false
    var initiallyHadReminder: Bool = false
    var alertOption: AlertOption = .fifteen
    var customTimeValue: Double = 15
    var customTimeUnit: TimeUnit = .minutes
    
    /// Computes the notification interval in minutes.
    var computedNotificationInterval: Double? {
        guard assignReminder else { return nil }
        if alertOption == .custom {
            return customTimeValue * customTimeUnit.multiplier
        } else {
            return alertOption.intervalInMinutes
        }
    }
}

enum AlertOption: String, CaseIterable, Identifiable {
    case fifteen = "15 minutes before"
    case thirty = "30 minutes before"
    case oneHour = "1 hour before"
    case twoHours = "2 hours before"
    case oneDay = "1 day before"
    case custom = "Custom"
    
    var id: Self { self }
    
    /// For default options, returns the notification interval (in minutes).
    var intervalInMinutes: Double? {
        switch self {
        case .fifteen: return 15
        case .thirty:  return 30
        case .oneHour: return 60
        case .twoHours:return 120
        case .oneDay:  return 1440
        case .custom:  return nil
        }
    }
}

enum TimeUnit: String, CaseIterable, Identifiable {
    case minutes = "Minutes"
    case hours   = "Hours"
    case days    = "Days"
    case weeks   = "Weeks"
    case months  = "Months"
    case years   = "Years"
    
    var id: Self { self }
    
    /// Multiplier converts the entered value into minutes.
    var multiplier: Double {
        switch self {
        case .minutes: return 1
        case .hours:   return 60
        case .days:    return 1440
        case .weeks:   return 10080
        case .months:  return 43200  // Approximation (30 days)
        case .years:   return 525600 // Approximation (365 days)
        }
    }
}

// MARK: - Helper to Format Interval

/// Returns a human‑readable string for a given number of minutes,
/// choosing the “most convenient” unit.
fileprivate func formattedInterval(from minutes: Double) -> String {
    if minutes < 60 {
        return "\(Int(minutes)) minute\(minutes == 1 ? "" : "s")"
    } else if minutes < 1440 { // less than 1 day
        let hours = minutes / 60
        return "\(hours.cleanValue) hour\(hours == 1 ? "" : "s")"
    } else if minutes < 10080 { // less than 1 week
        let days = minutes / 1440
        return "\(days.cleanValue) day\(days == 1 ? "" : "s")"
    } else if minutes < 43200 { // less than 1 month (approx.)
        let weeks = minutes / 10080
        return "\(weeks.cleanValue) week\(weeks == 1 ? "" : "s")"
    } else if minutes < 525600 { // less than 1 year (approx.)
        let months = minutes / 43200
        return "\(months.cleanValue) month\(months == 1 ? "" : "s")"
    } else {
        let years = minutes / 525600
        return "\(years.cleanValue) year\(years == 1 ? "" : "s")"
    }
}

extension Double {
    /// Returns the double as a string without fractional digits if possible,
    /// or one decimal point otherwise.
    var cleanValue: String {
        if self.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", self)
        } else {
            return String(format: "%.1f", self)
        }
    }
}

// MARK: - AlertView Component

struct AlertView: View {
    @Binding var config: AlertConfiguration
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Assign a reminder", isOn: $config.assignReminder)
            
            if config.assignReminder {
                Picker("Alert", selection: $config.alertOption) {
                    ForEach(AlertOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(DefaultPickerStyle())
                
                if config.alertOption == .custom {
                    HStack {
                        TextField("Value", value: $config.customTimeValue, format: .number)
                            .keyboardType(.decimalPad)
                            .frame(width: 60)
                        Picker("", selection: $config.customTimeUnit) {
                            ForEach(TimeUnit.allCases) { unit in
                                Text(unit.rawValue).tag(unit)
                            }
                        }
                        .pickerStyle(DefaultPickerStyle())
                    }
                    
                    if let computed = config.computedNotificationInterval {
                        Text("Custom reminder: \(formattedInterval(from: computed)) before the event")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if let interval = config.alertOption.intervalInMinutes {
                    Text("Reminder set for: \(formattedInterval(from: interval)) before the event")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}


#if DEBUG
struct AlertView_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var alertConfig: AlertConfiguration = AlertConfiguration()
        
        var body: some View {
            AlertView(config: $alertConfig)
        }
    }
    
    static var previews: some View {
        PreviewWrapper()
    }
}

#endif
