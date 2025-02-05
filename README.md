# Serenica

A modern mental wellness and task management app built with SwiftUI that combines calendar-based scheduling with flexible todo management, human-centric design, and a supportive AI-powered assistant.

## Core Features

- **User Authentication**
  - Secure login/signup system
  - Password reset functionality
  - Data persistence per user

- **Task Management**
  - Calendar-based task view
  - Undated todo list
  - Completed tasks history

- **Data Persistence**
  - CoreData backend
  - User-specific data isolation
  - Efficient data fetching and updates

- **AI-Powered Assistant**
  - Personalized mental health insights for people with ADHD, ASD, and other neurodivergent conditions
  - Daily reminders and support
  - Goal- and wellness-oriented task suggestions

## Views Structure

### Authentication Flow

#### AuthView
- Main authentication screen
- Handles both sign-in and sign-up
- Toggle between modes
- Password reset trigger
- Error handling and validation

#### ForgotPasswordView
- Password reset flow
- Username verification
- New password validation
- Success/error feedback

### Main Interface

#### MainTabView
- Tab-based navigation
- Authentication state management
- Navigation between main features

#### ChatView
- Chat interface with AI assistant
- Message history
- Input field
- Send button
- Voice input option
- Sign-out button

#### CalendarView
- Three-section layout:
  1. **Calendar Section**
     - Monthly/Weekly calendar view
     - Drag gesture to switch between views
     - Visual indicators for days with events
     - Date selection and navigation
     - Today quick access
     - Restricted to the days after today
  
  2. **Todo Section**
     - Undated tasks management
     - Quick task addition
     - Task completion toggle
     - Task details access
     - Swipe-to-delete functionality
  
  3. **Completed Section**
     - Chronological list of completed tasks
     - Grouped by completion date
     - Read-only task details
     - Task restoration option

#### Event Management

##### AddEventView
- Task creation interface
- Optional date assignment
- Start/end time selection
- Notes/description field
- Validation and error handling

##### EventDetailView
- Task details and editing
- Date modification
- Status toggle
- Notes editing
- Bottom sheet presentation

##### EventRow
- Reusable task row component
- Completion status indicator
- Date/time display
- Tap actions configuration

## Technical Details

### Data Models

#### Event
- UUID-based identification
- Optional date support
- User association
- Completion status
- Notes support

#### User
- Secure password handling
- Creation timestamp
- Event relationship

### State Management

#### EventStore
- CoreData operations
- Event filtering and sorting
- CRUD operations
- User-specific data handling

#### AuthService
- User authentication
- Session management
- Security measures

## UI/UX Considerations

### Layout
- Consistent padding and spacing
- Minimum tap target sizes
- Clear visual hierarchy

### Navigation
- Intuitive tab-based structure
- Context-appropriate back navigation
- Modal presentations for detail views

### Feedback
- Visual completion indicators
- Error messages
- Loading states
- Success confirmations

## Design System

### Serenity
- Consistent color palette
- Typography scale
- Layout constants
- Reusable styles

## Future Enhancements

- [ ] Drag-and-drop task reordering
- [ ] Calendar sync
- [ ] Recurring tasks
- [ ] Task categories/tags
- [ ] Search functionality
- [ ] Dark mode support
- [ ] Task sharing
- [ ] Push notifications

## Requirements

- iOS 15.0+
- Xcode 13.0+
- Swift 5.5+

## Installation

1. Clone the repository
2. Open `Serenica.xcodeproj`
3. Build and run

## License

[Your chosen license] 