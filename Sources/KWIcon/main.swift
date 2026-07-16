import AppKit
import Foundation

struct WeekDisplay {
    let week: Int
    let weekYear: Int
    let sprint: Int
    let sprintYear: Int
    let date: Date

    private static let sprintTimeZone = TimeZone(identifier: "Europe/Madrid") ?? .gmt
    private static let sprintSwitchWeekday = 4
    private static let sprintSwitchHour = 12

    static func current(date: Date = Date()) -> WeekDisplay {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = sprintTimeZone

        let sprintEndDate = sprintEndDate(for: date, calendar: calendar)

        return WeekDisplay(
            week: calendar.component(.weekOfYear, from: date),
            weekYear: calendar.component(.yearForWeekOfYear, from: date),
            sprint: calendar.component(.weekOfYear, from: sprintEndDate),
            sprintYear: calendar.component(.yearForWeekOfYear, from: sprintEndDate),
            date: date
        )
    }

    private static func sprintEndDate(for date: Date, calendar: Calendar) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: date)
        let daysToSwitchDay = sprintSwitchWeekday - weekday
        let switchDay = calendar.date(byAdding: .day, value: daysToSwitchDay, to: startOfDay) ?? startOfDay
        let switchMoment = calendar.date(
            bySettingHour: sprintSwitchHour,
            minute: 0,
            second: 0,
            of: switchDay
        ) ?? switchDay

        if date < switchMoment {
            return switchMoment
        }

        return calendar.date(byAdding: .day, value: 7, to: switchMoment) ?? switchMoment
    }

    var menuBarTitle: String {
        "SP\(sprint)-KW\(week)"
    }

    var sprintSummary: String {
        "Sprint \(sprint) · Switches Wed 12:00 Europe/Madrid"
    }

    var weekSummary: String {
        "Calendar week \(week)"
    }

    var copyLabel: String {
        menuBarTitle
    }

    var yearSummary: String {
        if sprintYear == weekYear {
            return "ISO week year \(weekYear)"
        }

        return "ISO week year \(weekYear) · Sprint year \(sprintYear)"
    }

    var todaySummary: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        formatter.timeZone = Self.sprintTimeZone
        return formatter.string(from: date)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private enum PreferenceKey {
        static let showsSprintAndWeek = "showsSprintAndWeek"
        static let showsSprintNumber = "showsSprintNumber"
    }

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var refreshTimer: Timer?
    private var currentDisplay = WeekDisplay.current()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        if #available(macOS 11.0, *) {
            statusItem.behavior = [.removalAllowed]
        }

        refresh()
        installObservers()

        refreshTimer = Timer.scheduledTimer(
            timeInterval: 30 * 60,
            target: self,
            selector: #selector(refresh),
            userInfo: nil,
            repeats: true
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    private func installObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refresh),
            name: .NSCalendarDayChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refresh),
            name: .NSSystemClockDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refresh),
            name: .NSSystemTimeZoneDidChange,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(refresh),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    @objc private func refresh() {
        currentDisplay = WeekDisplay.current()

        guard let button = statusItem.button else {
            return
        }

        button.title = displayTitle
        button.toolTip = "\(currentDisplay.sprintSummary) · \(currentDisplay.weekSummary) · \(currentDisplay.yearSummary)"
        statusItem.menu = makeMenu()
    }

    private var displayTitle: String {
        if UserDefaults.standard.bool(forKey: PreferenceKey.showsSprintAndWeek) {
            return currentDisplay.menuBarTitle
        }

        let number = UserDefaults.standard.bool(forKey: PreferenceKey.showsSprintNumber)
            ? currentDisplay.sprint
            : currentDisplay.week
        return "KW \(number)"
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()

        menu.addItem(disabledItem(currentDisplay.sprintSummary))
        menu.addItem(disabledItem(currentDisplay.weekSummary))
        menu.addItem(disabledItem(currentDisplay.yearSummary))
        menu.addItem(disabledItem(currentDisplay.todaySummary))
        menu.addItem(.separator())

        let sprintAndWeekItem = NSMenuItem(
            title: "Show Sprint + ISO Week",
            action: #selector(toggleSprintAndWeek),
            keyEquivalent: ""
        )
        sprintAndWeekItem.target = self
        sprintAndWeekItem.state = UserDefaults.standard.bool(forKey: PreferenceKey.showsSprintAndWeek) ? .on : .off
        menu.addItem(sprintAndWeekItem)

        let sprintNumberItem = NSMenuItem(
            title: "Use Sprint Number",
            action: #selector(toggleSprintNumber),
            keyEquivalent: ""
        )
        sprintNumberItem.target = self
        sprintNumberItem.isEnabled = !UserDefaults.standard.bool(forKey: PreferenceKey.showsSprintAndWeek)
        sprintNumberItem.state = UserDefaults.standard.bool(forKey: PreferenceKey.showsSprintNumber) ? .on : .off
        menu.addItem(sprintNumberItem)
        menu.addItem(.separator())

        let copyNumberItem = NSMenuItem(
            title: "Copy Week Number",
            action: #selector(copyWeekNumber),
            keyEquivalent: ""
        )
        copyNumberItem.target = self
        menu.addItem(copyNumberItem)

        let copyLabelItem = NSMenuItem(
            title: "Copy Display Label",
            action: #selector(copyWeekLabel),
            keyEquivalent: ""
        )
        copyLabelItem.target = self
        menu.addItem(copyLabelItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit KW Icon",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    @objc private func copyWeekNumber() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(String(currentDisplay.week), forType: .string)
    }

    @objc private func copyWeekLabel() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(displayTitle, forType: .string)
    }

    @objc private func toggleSprintAndWeek() {
        let defaults = UserDefaults.standard
        defaults.set(!defaults.bool(forKey: PreferenceKey.showsSprintAndWeek), forKey: PreferenceKey.showsSprintAndWeek)
        refresh()
    }

    @objc private func toggleSprintNumber() {
        let defaults = UserDefaults.standard
        defaults.set(!defaults.bool(forKey: PreferenceKey.showsSprintNumber), forKey: PreferenceKey.showsSprintNumber)
        refresh()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

if CommandLine.arguments.contains("--print-week") {
    print(WeekDisplay.current().menuBarTitle)
    exit(EXIT_SUCCESS)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
