import SwiftUI

/// A compact date picker view that shows week-based navigation and day selection.
struct DatePickerView: View {
    @Binding var selectedDate: Date
    let specialDate: Date
    let onSelectDay: (Date) -> Void

    var body: some View {
        VStack(spacing: 0) {
            WeekNavigationHeader(selectedDate: $selectedDate)
            WeekCalendarGridView(selectedDate: $selectedDate, events: [], onSelectDay: onSelectDay, specialDate: specialDate)
                .frame(height: 60)
        }
    }
}

// MARK: - WeekNavigationHeader

/// A header that provides week-based navigation with left/right arrows and a Today button.
struct WeekNavigationHeader: View {
    @Binding var selectedDate: Date
    private var canNavigateToPreviousWeek: Bool {
        let currentWeekStart = Date().startOfWeek()
        let selectedWeekStart = selectedDate.startOfWeek()
        return selectedWeekStart > currentWeekStart
    }

    var body: some View {
        HStack {
            // Left Arrow: Moves to the previous week.
            Button {
                withAnimation {
                    if canNavigateToPreviousWeek {
                        selectedDate = selectedDate.previousWeek()
                    }
                }
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundColor(Serenity.Colors.primary)
                    .font(.title3)
            }
            .frame(width: Serenity.Layout.minimumTapTarget)
            .disabled(!canNavigateToPreviousWeek)
            
            
            Spacer()
            
            // Header Title: Shows either “Today” or the weekday and month.
            let isToday = Calendar.current.isDate(selectedDate, inSameDayAs: Date())
            let mainText = isToday ? "Today" : DateFormatter.weekdayFormatter.string(from: selectedDate)
            let subText = DateFormatter.monthFormatter.string(from: selectedDate)
            VStack(spacing: 2) {
                Text(mainText)
                    .font(Serenity.Typography.screenTitle())
                Text(subText)
                    .font(Serenity.Typography.caption())
            }
            .transition(.opacity)
            .id(selectedDate)
            .animation(.easeInOut, value: selectedDate)
            
            Spacer()
            
            // Right Arrow: Moves to the next week.
            Button {
                withAnimation {
                    selectedDate = selectedDate.nextWeek()
                }
            } label: {
                Image(systemName: "chevron.right")
                    .foregroundColor(Serenity.Colors.primary)
                    .font(.title3)
            }
            .frame(width: Serenity.Layout.minimumTapTarget)
        }
        .padding()
    }
}
    
    /// Computes the 7 days representing the week that includes selectedDate.


// MARK: - Preview

#if DEBUG
struct DatePickerView_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var selectedDate: Date = Date()
        
        var body: some View {
            DatePickerView(selectedDate: $selectedDate, specialDate: Date().startOfDay()) { newDate in
                // For preview purposes, simply update the selectedDate.
                selectedDate = newDate
            }
            .padding()
            .previewLayout(.sizeThatFits)
        }
    }
    
    static var previews: some View {
        PreviewWrapper()
    }
}
#endif
