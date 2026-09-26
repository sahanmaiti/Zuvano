import EventKit
import Foundation

struct EventKitCalendarSnapshot: Equatable, Sendable {
    nonisolated let calendarIdentifier: String
    nonisolated let title: String
    nonisolated let allowsContentModifications: Bool
    nonisolated let sourceIdentifier: String
    nonisolated let sourceTypeRawValue: Int

    nonisolated init(
        calendarIdentifier: String,
        title: String,
        allowsContentModifications: Bool,
        sourceIdentifier: String,
        sourceTypeRawValue: Int
    ) {
        self.calendarIdentifier = calendarIdentifier
        self.title = title
        self.allowsContentModifications = allowsContentModifications
        self.sourceIdentifier = sourceIdentifier
        self.sourceTypeRawValue = sourceTypeRawValue
    }
}

struct EventKitSourceSnapshot: Equatable, Sendable {
    nonisolated let sourceIdentifier: String
    nonisolated let sourceTypeRawValue: Int

    nonisolated init(sourceIdentifier: String, sourceTypeRawValue: Int) {
        self.sourceIdentifier = sourceIdentifier
        self.sourceTypeRawValue = sourceTypeRawValue
    }
}

enum EventKitWritableContainerDecision: Equatable, Sendable {
    case useCalendar(identifier: String)
    case attemptCreate(sourceIdentifiers: [String])
    case noWritableContainer
}

/// Source preference when creating a new EventKit calendar (pure ordering for tests and resolution).
enum EventKitCalendarResolution {
    nonisolated static let fallbackCalendarTitle = "Zuvano"

    nonisolated static func orderedSourceTypes(for entityType: EKEntityType) -> [EKSourceType] {
        switch entityType {
        case .event:
            return [.local, .calDAV, .exchange]
        case .reminder:
            return [.calDAV, .exchange, .local]
        default:
            return [.calDAV, .local, .exchange]
        }
    }

    nonisolated static func sourcesInPreferredOrder(
        from allSources: [EKSource],
        entityType: EKEntityType
    ) -> [EKSource] {
        let preferred = orderedSourceTypes(for: entityType)
        var ordered: [EKSource] = []
        var seen = Set<ObjectIdentifier>()

        for sourceType in preferred {
            for source in allSources where source.sourceType == sourceType {
                let id = ObjectIdentifier(source)
                guard !seen.contains(id) else { continue }
                seen.insert(id)
                ordered.append(source)
            }
        }

        for source in allSources {
            let id = ObjectIdentifier(source)
            guard !seen.contains(id) else { continue }
            seen.insert(id)
            ordered.append(source)
        }

        return ordered
    }

    nonisolated static func usableSourceSnapshots(
        from allSources: [EventKitSourceSnapshot],
        entityType: EKEntityType
    ) -> [EventKitSourceSnapshot] {
        let excluded: Set<Int> = [
            EKSourceType.birthdays.rawValue,
            EKSourceType.subscribed.rawValue
        ]
        let filtered = allSources.filter { !excluded.contains($0.sourceTypeRawValue) }
        let preferred = orderedSourceTypes(for: entityType).map(\.rawValue)
        var ordered: [EventKitSourceSnapshot] = []
        var seen = Set<String>()

        for sourceType in preferred {
            for source in filtered where source.sourceTypeRawValue == sourceType {
                guard !seen.contains(source.sourceIdentifier) else { continue }
                seen.insert(source.sourceIdentifier)
                ordered.append(source)
            }
        }

        for source in filtered {
            guard !seen.contains(source.sourceIdentifier) else { continue }
            seen.insert(source.sourceIdentifier)
            ordered.append(source)
        }

        return ordered
    }

    nonisolated static func writableContainerDecision(
        entityType: EKEntityType,
        defaultCalendarIdentifier: String?,
        calendars: [EventKitCalendarSnapshot],
        sources: [EventKitSourceSnapshot],
        fallbackTitle: String = fallbackCalendarTitle
    ) -> EventKitWritableContainerDecision {
        if let defaultCalendarIdentifier,
           let defaultCalendar = calendars.first(where: { $0.calendarIdentifier == defaultCalendarIdentifier }),
           defaultCalendar.allowsContentModifications {
            return .useCalendar(identifier: defaultCalendar.calendarIdentifier)
        }

        if let zuvano = calendars.first(where: {
            $0.title == fallbackTitle && $0.allowsContentModifications
        }) {
            return .useCalendar(identifier: zuvano.calendarIdentifier)
        }

        if let writable = calendars.first(where: \.allowsContentModifications) {
            return .useCalendar(identifier: writable.calendarIdentifier)
        }

        let usableSources = usableSourceSnapshots(from: sources, entityType: entityType)
        var createOn: [String] = []

        for source in usableSources {
            if let existing = calendars.first(where: {
                $0.sourceIdentifier == source.sourceIdentifier && $0.title == fallbackTitle
            }) {
                if existing.allowsContentModifications {
                    return .useCalendar(identifier: existing.calendarIdentifier)
                }
                continue
            }
            createOn.append(source.sourceIdentifier)
        }

        if createOn.isEmpty {
            return .noWritableContainer
        }
        return .attemptCreate(sourceIdentifiers: createOn)
    }
}
