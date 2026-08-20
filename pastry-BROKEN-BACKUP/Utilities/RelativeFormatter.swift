import Foundation

public struct RelativeFormatter {
    public static func format(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.second, .minute, .hour, .day], from: date, to: now)
        
        if let day = components.day, day > 0 {
            if day == 1 { return "Yesterday" }
            return "\(day) days ago"
        }
        if let hour = components.hour, hour > 0 {
            return "\(hour) hr ago"
        }
        if let minute = components.minute, minute > 0 {
            return "\(minute) min ago"
        }
        if let second = components.second, second > 5 {
            return "\(second) sec ago"
        }
        return "Just now"
    }
}
