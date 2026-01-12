# Admin Application Implementation Plan

## Goal Description
Implement a comprehensive Admin Application for the `somang_reading_jesus` project. This includes managing schedules, users, reading progress tracking, content (images/videos), and notices. The goal is to provide church administrators with tools to manage the Bible reading program effectively.

## User Review Required
> [!IMPORTANT]
> **User Creation Strategy**: Since the app uses Phone Authentication, Admins cannot directly create "Login Accounts" for users without their specialized verification.
> **Proposed Solution**: 
> 1.  **Values**: Admin adds "Member Info" (Name, Phone, DOB) to a `members` collection (Roster).
> 2.  **Flow**: When a user signs up with a matching Phone Number, their profile is auto-linked/filled with this info.
> 3.  **Direct Edit**: Admin can also "Edit" profile details of *existing* users (Name, DOB, etc.) directly in the simple `users` list.
> 
> **Progress Tracking Performance**: Real-time aggregation of reading progress for all users might be slow.
> **Proposed Solution**: We will rely on a `stats/summary` document under each user (e.g. `users/{uid}/stats/reading_summary`) which is updated whenever a user marks a reading as complete. This allows the Admin Dashboard to quickly fetch numbers without counting thousands of documents.

## Proposed DB Schema and Changes

### 1. Database Schema (Firestore)

#### **Users & Progress**
*   `users/{uid}` (Existing `UserProfile`)
    *   Fields: `name`, `phoneNumber`, `birthDate`, `role`, `churchId`, `createdAt`, `updatedAt`
    *   Sub-collection: `completions/{completionId}` (Existing `ReadingCompletion`)
    *   **[NEW]** Sub-collection: `stats/summary`
        *   Doc ID: `reading_summary`
        *   Fields: `totalReadDays` (int), `lastReadDate` (DateTime), `currentStreak` (int)

#### **[NEW] Church Roster (for User Creation/Pre-loading)**
*   `church_roster/{phoneNumber}`
    *   Fields: `name`, `birthDate`, `phoneNumber`, `createdAt`
    *   *Purpose*: Acts as a "whitelist" or "pre-fill" for new sign-ups.

#### **Schedule**
*   `config/schedule/years/{year}` (Existing)
    *   Fields: `startDate`, `holidays` (List of Ranges)

#### **[NEW] Content Management**
*   `contents/{contentId}`
    *   Fields:
        *   `type`: 'image' | 'youtube'
        *   `title`: String
        *   `url`: String (Image URL or YouTube ID/URL)
        *   `isVisible`: boolean
        *   `order`: int (for sorting)
        *   `createdAt`: DateTime

#### **[NEW] Notices**
*   `notices/{noticeId}`
    *   Fields:
        *   `title`: String
        *   `body`: String
        *   `isVisible`: boolean
        *   `createdAt`: DateTime
        *   `sentPush`: boolean (Status of push notification)
---

### 2. Admin UI Changes

### Admin Dashboard (Windows Desktop App)
*   **Platform**: Windows Desktop Application (`.exe`).
*   **Summary Cards**:
    *   **Total Users**: Registered count.
    *   **Read Today (Renamed)**: "Active Today" (avoid confusion with "Completed").
    *   **Avg. Progress**: Average % completed vs. Expected Schedule.
*   **Analysis Charts**:
    *   **Progress by Age Group**.
    *   **Progress by Gender**.
*   **Navigation**: Side Navigation Rail.

### Schedule Management (`AdminScheduleScreen`)
*   **Refinement**: Ensure Holidays and Start Date editing is robust.

### User Management (`UserListScreen`, `UserDetailScreen`)
*   **List**: Single unified list (Real users + Pre-registered).
*   **Create**: "Add Member" creates a User DB entry (for pre-registration).
*   **Detail & Edit**:
    *   Edit Basic Info (Name, Phone, DOB, **Gender**).
    *   **Reading History Editing**: **Calendar UI** to view and toggle "Read" status for specific dates.

## Verification Plan

### Automated Tests
*   **Unit Tests**: Verify `ReadingSchedule` logic for date calculations.
*   **Widget Tests**: None planned for this phase (time constraint), relying on Manual Verification.

### Manual Verification
1.  **Dashboard**: Verify new "Progress" and "Group Stats" appear.
2.  **User Flow**:
    *   Admin adds "Member" -> Check if it appears in list.
    *   Click User -> **Calendar View**.
    *   Click a date on Calendar -> Toggle "Read" status.
3.  **Schedule**:
    *   Verify Schedule Start Date affects "Expected Progress".
