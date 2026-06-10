# Calendar Pulse build and setup guide

Calendar Pulse is a native macOS 14+ SwiftUI menu bar app that reads events already synced into Apple Calendar through EventKit. It does not use Google Calendar APIs.

## Open and run in Xcode

1. Open `CalendarPulse.xcodeproj` in Xcode 16 or newer.
2. Select the `Calendar Pulse` scheme.
3. Choose **My Mac** as the run destination.
4. Press **Run** (`⌘R`).
5. Calendar Pulse appears only in the macOS menu bar because `LSUIElement` is enabled; it does not appear in the Dock.

## Calendar permissions macOS will request

On first launch, macOS asks whether Calendar Pulse can access your calendars. Calendar Pulse requests full EventKit event access so it can read your synced calendar events and compute busy/free status. The app does not create, edit, or delete events.

If permission is denied, the popover shows: “Calendar access is needed to show your schedule.” Use the **Open System Settings** button to review Calendar privacy permissions.

## Add Google Calendar to Apple Calendar

Calendar Pulse reads whatever calendars are available to the macOS Calendar app. To include Google Calendar:

1. Open **System Settings**.
2. Go to **Internet Accounts**.
3. Click **Add Account** and choose **Google**.
4. Sign in and enable **Calendars** for that account.
5. Open the macOS **Calendar** app and confirm your Google calendars appear there.
6. Refresh Calendar Pulse from the popover.

## Archive or copy into Applications for personal use

For a quick personal build:

1. In Xcode, choose **Product > Archive**.
2. When Organizer opens, distribute or export the app for local use.
3. Copy `Calendar Pulse.app` into `/Applications`.
4. Launch it from `/Applications`; after launch it will live in the menu bar.

For local debugging builds, Xcode also places the built app in DerivedData under `Build/Products/Debug/Calendar Pulse.app`; you can copy that app into `/Applications` for personal testing.
