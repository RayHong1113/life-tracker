# Changelog

All notable changes to the **LifeTracker** project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Planned & In Progress

- [ ] **To do list**: Add a new page where users can create tasks and track its status.

---

## [1.4.0] - 2026-10-15

### Added

- **Untracked / Excluded Days Management**: Introduced [`ManageExcludedDaysScreen`](lib/views/settings/manage_excluded_days_screen.dart) accessible under Settings -> *APP CONFIGURATION*, enabling users to exclude forgotten dates or date ranges from statistical calculations.
- **Persistent Storage for Excluded Dates**: Serialized and persisted excluded date keys (`YYYY-MM-DD`) in SQLite `user_settings` table via `DatabaseHelper` and `SettingsProvider`.
- **Dynamic Daily Average with Exclusions**: In [`CategoryDetailScreen`](lib/views/statistics/category_detail_screen.dart), daily average calculations now dynamically subtract excluded days: `effectiveDays = max(1, activeDays - excludedCountInPeriod)`, preventing forgotten days from diluting user metrics.
- **Exclusion Badge on Detail Summary Card**: Added an informational badge `(X untracked excluded)` below the `Daily Average` statistic in [`CategoryDetailSummaryCard`](lib/views/statistics/widgets/category_detail_summary_card.dart).
- **Comprehensive Unit Test Suite**: Added [`test/excluded_days_test.dart`](test/excluded_days_test.dart) covering date key formatting, exclusion subtraction, ongoing period capping, and historical week calculations.

### Changed (Code Architecture & Refactoring)

- **Statistics Modularization**: Restructured monolithic `statistics_view.dart` (shrunk from 1,141 to 311 lines) and `category_detail_screen.dart` (shrunk from 1,186 to ~550 lines) into modular subcomponents:
  - Models: [`category_stats.dart`](lib/views/statistics/models/category_stats.dart), [`category_detail_types.dart`](lib/views/statistics/models/category_detail_types.dart).
  - Utilities: [`statistics_calculator.dart`](lib/views/statistics/utils/statistics_calculator.dart), [`category_detail_helper.dart`](lib/views/statistics/utils/category_detail_helper.dart).
  - Widgets: 10 decoupled widget files under [`lib/views/statistics/widgets/`](lib/views/statistics/widgets/).
- **Date Arithmetic & DST Immunity**: Refactored `CategoryDetailHelper.getStartOfWeek` and `StatisticsCalculator.getPeriodAnchor` to use pure calendar arithmetic, eliminating Daylight Saving Time (DST) 23:00/01:00 date shifts.
- **Date Header & Navigator Polish**: Refined period labels and headers across week and month views.
- **English Code Comments**: Preserved and standardized all code comments in modified and newly added files to English.

### Fixed

- **Cross-Day Activity Alignment in Category Detail**: Sliced cross-day activities (such as overnight sleep) into daily segments in [`CategoryDetailScreen`](lib/views/statistics/category_detail_screen.dart), aligning Activity Logs and bar charts with overview calculations across day boundaries.
- **Daily Average Fallback & Divisor**: Fixed an issue where completed weeks/months erroneously fell back to an active day count of 1, restoring accurate 7-day week and full-month calculations with correct exclusion subtractions.
- **Navigation Overflow**: Fixed `RenderFlex` text overflow in the category detail period navigation row using `Flexible` and ellipsis truncation.

---

## [1.3.0] - 2026-09-24

### Changed (Code Architecture & Refactoring)

- **Calendar Modularization**: Refactored the monolithic `calendar_view.dart` (reduced from 1,076 lines to ~260 lines) into clean, decoupled sub-modules without changing business behavior:
  - Extracted layout math and collision algorithms into [`TimelineLayoutHelper`](lib/views/calendar/utils/timeline_layout_helper.dart).
  - Extracted header date navigation into [`CalendarDateHeader`](lib/views/calendar/widgets/calendar_date_header.dart).
  - Extracted 24-hour background grid into [`TimelineHourCell`](lib/views/calendar/widgets/timeline_hour_cell.dart).
  - Extracted activity rendering and action dialogs into [`ActivityCardCell`](lib/views/calendar/widgets/activity_card_cell.dart).
  - Extracted positioning data class into [`PositionedActivity`](lib/views/calendar/models/positioned_activity.dart).
- Purely internal code quality, maintainability, and clean architecture improvements (zero new user-facing features).

---

## [1.2.0] - 2026-09-01

### Added

- **Dual Cloud Sync**: Integrated unified cloud synchronization with **Supabase** and **Firebase Firestore** alongside local SQLite persistence.
- **Label System**: Introduced Spendee-style tags with emojis and custom colors for fine-grained activity classification.
- **Bidirectional Date Synchronization**: Enabled seamless date synchronization across views and persistent storage.
- **Automated Unit Test Suite**: Added automated tests for core models, providers, and database operations with 100% test pass rate.

### Changed

- Updated database schema migration to handle dynamic label columns and label relational mappings.

---

## [1.1.0] - 2026-08-08

### Added

- **Dual-Mode Analytics**: Added switchable **Pie Chart** (proportional distribution) and **Bar Chart** (trend comparison) in the Statistics view.
- **Category Visibility Toggle**: Allowed users to hide specific categories from statistical charts and time summaries.
- **Full Time-Range Display**: Showed complete start-to-end time badges on single-line calendar cards.
- **Safety Confirmations**: Added confirmation dialogs before deleting activities or categories to prevent accidental data loss.

### Fixed

- Resolved activity card visual overlapping and vertical position alignment issues on the calendar timeline.
- Fixed category color synchronization between SQLite updates and calendar card titles.

### Changed

- Refactored category creation form UI with enhanced color picker and icon selection.
- Refined activity creation logic to ensure smooth time validation.

---

## [1.0.0] - 2026-07-30

### Added

- **Initial MVP Release**: Launched core time-tracking and productivity logging framework.
- **24-Hour Timeline Grid**: Interactive day-timeline supporting time slot selection and activity creation.
- **Local SQLite Database**: Implemented [`DatabaseHelper`](lib/services/database_helper.dart) for offline-first, persistent activity logging.
- **Default Category Set**: Pre-configured categories (Coding, Work, Study, Workout, Gaming, Cooking, Shopping, Rest) with custom colors and icons.
