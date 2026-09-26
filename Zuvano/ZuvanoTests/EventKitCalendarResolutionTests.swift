import EventKit
import Testing
@testable import Zuvano

struct EventKitCalendarResolutionTests {
    @Test func eventSourcePreferenceOrder() {
        let order = EventKitCalendarResolution.orderedSourceTypes(for: .event)
        #expect(order == [.local, .calDAV, .exchange])
    }

    @Test func reminderSourcePreferenceOrder() {
        let order = EventKitCalendarResolution.orderedSourceTypes(for: .reminder)
        #expect(order == [.calDAV, .exchange, .local])
    }

    @Test func prefersWritableDefaultCalendar() {
        let decision = EventKitCalendarResolution.writableContainerDecision(
            entityType: .event,
            defaultCalendarIdentifier: "default",
            calendars: [
                EventKitCalendarSnapshot(
                    calendarIdentifier: "default",
                    title: "Default",
                    allowsContentModifications: true,
                    sourceIdentifier: "local",
                    sourceTypeRawValue: EKSourceType.local.rawValue
                ),
                EventKitCalendarSnapshot(
                    calendarIdentifier: "other",
                    title: "Other",
                    allowsContentModifications: true,
                    sourceIdentifier: "local",
                    sourceTypeRawValue: EKSourceType.local.rawValue
                )
            ],
            sources: [
                EventKitSourceSnapshot(
                    sourceIdentifier: "local",
                    sourceTypeRawValue: EKSourceType.local.rawValue
                )
            ]
        )
        #expect(decision == .useCalendar(identifier: "default"))
    }

    @Test func usesWritableNonDefaultWhenDefaultNotWritable() {
        let decision = EventKitCalendarResolution.writableContainerDecision(
            entityType: .event,
            defaultCalendarIdentifier: "default",
            calendars: [
                EventKitCalendarSnapshot(
                    calendarIdentifier: "default",
                    title: "Default",
                    allowsContentModifications: false,
                    sourceIdentifier: "local",
                    sourceTypeRawValue: EKSourceType.local.rawValue
                ),
                EventKitCalendarSnapshot(
                    calendarIdentifier: "writable",
                    title: "Work",
                    allowsContentModifications: true,
                    sourceIdentifier: "local",
                    sourceTypeRawValue: EKSourceType.local.rawValue
                )
            ],
            sources: []
        )
        #expect(decision == .useCalendar(identifier: "writable"))
    }

    @Test func reusesWritableZuvanoCalendar() {
        let decision = EventKitCalendarResolution.writableContainerDecision(
            entityType: .reminder,
            defaultCalendarIdentifier: nil,
            calendars: [
                EventKitCalendarSnapshot(
                    calendarIdentifier: "zuvano",
                    title: EventKitCalendarResolution.fallbackCalendarTitle,
                    allowsContentModifications: true,
                    sourceIdentifier: "local",
                    sourceTypeRawValue: EKSourceType.local.rawValue
                )
            ],
            sources: [
                EventKitSourceSnapshot(
                    sourceIdentifier: "local",
                    sourceTypeRawValue: EKSourceType.local.rawValue
                )
            ]
        )
        #expect(decision == .useCalendar(identifier: "zuvano"))
    }

    @Test func attemptsCreateOnUsableSourceWhenNoWritableCalendar() {
        let decision = EventKitCalendarResolution.writableContainerDecision(
            entityType: .event,
            defaultCalendarIdentifier: nil,
            calendars: [],
            sources: [
                EventKitSourceSnapshot(
                    sourceIdentifier: "local",
                    sourceTypeRawValue: EKSourceType.local.rawValue
                ),
                EventKitSourceSnapshot(
                    sourceIdentifier: "birthdays",
                    sourceTypeRawValue: EKSourceType.birthdays.rawValue
                )
            ]
        )
        #expect(decision == .attemptCreate(sourceIdentifiers: ["local"]))
    }

    @Test func noWritableContainerWhenNoSources() {
        let decision = EventKitCalendarResolution.writableContainerDecision(
            entityType: .event,
            defaultCalendarIdentifier: nil,
            calendars: [],
            sources: []
        )
        #expect(decision == .noWritableContainer)
    }

    @Test func skipsDuplicateZuvanoCreateOnSourceWhenReadOnlyExists() {
        let decision = EventKitCalendarResolution.writableContainerDecision(
            entityType: .event,
            defaultCalendarIdentifier: nil,
            calendars: [
                EventKitCalendarSnapshot(
                    calendarIdentifier: "z-ro",
                    title: EventKitCalendarResolution.fallbackCalendarTitle,
                    allowsContentModifications: false,
                    sourceIdentifier: "local",
                    sourceTypeRawValue: EKSourceType.local.rawValue
                )
            ],
            sources: [
                EventKitSourceSnapshot(
                    sourceIdentifier: "local",
                    sourceTypeRawValue: EKSourceType.local.rawValue
                ),
                EventKitSourceSnapshot(
                    sourceIdentifier: "exchange",
                    sourceTypeRawValue: EKSourceType.exchange.rawValue
                )
            ]
        )
        #expect(decision == .attemptCreate(sourceIdentifiers: ["exchange"]))
    }
}
