import Testing
import Foundation
@testable import SpendZero

struct EveningCheckInTests {
    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }

    private func at(_ hour: Int, _ minute: Int = 0, day: Int = 3) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    @Test func deadlineIsNextMidnight() {
        #expect(EveningCheckIn.deadline(for: at(19, 30), calendar: cal) == at(0, day: 4))
        #expect(EveningCheckIn.deadline(for: at(0), calendar: cal) == at(0, day: 4))
    }

    @Test func deadlineHandlesDSTDay() {
        // US DST ends Nov 1 2026: that day is 25 hours long; the deadline is still local midnight.
        let night = cal.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 20))!
        let midnight = cal.date(from: DateComponents(year: 2026, month: 11, day: 2))!
        #expect(EveningCheckIn.deadline(for: night, calendar: cal) == midnight)
    }

    @Test func hoursLeftRoundsUpAndClampsAtZero() {
        let deadline = at(0, day: 4)
        #expect(EveningCheckIn.hoursLeft(now: at(21), deadline: deadline) == 3)
        #expect(EveningCheckIn.hoursLeft(now: at(21, 50), deadline: deadline) == 3)
        #expect(EveningCheckIn.hoursLeft(now: at(23, 59), deadline: deadline) == 1)
        #expect(EveningCheckIn.hoursLeft(now: deadline, deadline: deadline) == 0)
        #expect(EveningCheckIn.hoursLeft(now: at(1, day: 4), deadline: deadline) == 0)
    }

    @Test func expiresAtMidnight() {
        let day = cal.startOfDay(for: at(19))
        #expect(!EveningCheckIn.isExpired(activityDay: day, now: at(23, 59), calendar: cal))
        #expect(EveningCheckIn.isExpired(activityDay: day, now: at(0, day: 4), calendar: cal))
    }

    @Test func sealedOrSpentEndsTheActivity() {
        #expect(EveningCheckIn.decide(now: at(20), sealedOrBlocked: true, reminderHour: 20,
                                      hasActivityForToday: true, canSchedule: true, calendar: cal) == .end)
    }

    @Test func openingAfterSixStartsNow() {
        #expect(EveningCheckIn.decide(now: at(18, 5), sealedOrBlocked: false, reminderHour: 21,
                                      hasActivityForToday: false, canSchedule: false, calendar: cal) == .startNow)
    }

    @Test func earlierReminderOpensWindowEarlier() {
        #expect(EveningCheckIn.decide(now: at(17, 10), sealedOrBlocked: false, reminderHour: 17,
                                      hasActivityForToday: false, canSchedule: false, calendar: cal) == .startNow)
    }

    @Test func beforeWindowSchedulesAtReminderTime() {
        #expect(EveningCheckIn.decide(now: at(9), sealedOrBlocked: false, reminderHour: 20,
                                      hasActivityForToday: false, canSchedule: true, calendar: cal) == .schedule(at: at(20)))
        #expect(EveningCheckIn.decide(now: at(9), sealedOrBlocked: false, reminderHour: 20,
                                      hasActivityForToday: false, canSchedule: false, calendar: cal) == .wait)
    }

    @Test func morningReminderIsClampedToEvening() {
        #expect(EveningCheckIn.scheduledStart(on: at(9), reminderHour: 8, calendar: cal) == at(17))
    }

    @Test func existingActivityIsUpdatedNotDuplicated() {
        #expect(EveningCheckIn.decide(now: at(20), sealedOrBlocked: false, reminderHour: 20,
                                      hasActivityForToday: true, canSchedule: true, calendar: cal) == .update)
    }
}
