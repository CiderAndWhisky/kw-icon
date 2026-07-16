import AppKit
import Foundation

struct WeekDisplay {
    let week: Int
    let weekYear: Int
    let date: Date

    static func current(date: Date = Date()) -> WeekDisplay {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .autoupdatingCurrent
        let sprintDate = calendar.date(byAdding: .day, value: 5, to: date) ?? date

        return WeekDisplay(
            week: calendar.component(.weekOfYear, from: sprintDate),
            weekYear: calendar.component(.yearForWeekOfYear, from: sprintDate),
            date: date
        )
    }

    var menuBarTitle: String {
        "KW \(week)"
    }

    var weekSummary: String {
        "Calendar week \(week)"
    }

    var copyLabel: String {
        "KW \(week)"
    }

    var yearSummary: String {
        "ISO week year \(weekYear)"
    }

    var todaySummary: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
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

        button.title = currentDisplay.menuBarTitle
        button.toolTip = "\(currentDisplay.weekSummary) · \(currentDisplay.yearSummary)"
        statusItem.menu = makeMenu()
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()

        menu.addItem(disabledItem(currentDisplay.weekSummary))
        menu.addItem(disabledItem(currentDisplay.yearSummary))
        menu.addItem(disabledItem(currentDisplay.todaySummary))
        menu.addItem(.separator())

        let copyNumberItem = NSMenuItem(
            title: "Copy Week Number",
            action: #selector(copyWeekNumber),
            keyEquivalent: ""
        )
        copyNumberItem.target = self
        menu.addItem(copyNumberItem)

        let copyLabelItem = NSMenuItem(
            title: "Copy KW Label",
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
        NSPasteboard.general.setString(currentDisplay.copyLabel, forType: .string)
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
