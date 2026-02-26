import Foundation

#if canImport(FoundationModels)
import FoundationModels

@available(macOS 26, *)
@Generable
struct DailyBriefing {
    @Guide(description: "A concise, friendly 1-2 sentence summary of today's meeting schedule highlighting key meetings, free time blocks, and overall busyness")
    var summary: String
}

@available(macOS 26, *)
@Generable
struct MeetingInsight {
    @Guide(description: "A brief 1-line summary distilling the meeting's purpose or key agenda from its description and notes")
    var summary: String
}

@available(macOS 26, *)
@Generable
struct SmartTitle {
    @Guide(description: "An intelligently abbreviated version of the meeting title that preserves meaning within the character limit")
    var abbreviated: String
}

@available(macOS 26, *)
@Generable
struct ConflictInsight {
    @Guide(description: "A short, human-friendly description of the scheduling conflict and a practical suggestion")
    var description: String
}
#endif

/// Service that wraps Apple's on-device Foundation Models framework for AI-powered features.
/// All features run entirely on-device — no network, no API keys, no privacy concerns.
/// Gracefully falls back to nil results on macOS < 26 or unsupported hardware.
final class FoundationModelService {
    static let shared = FoundationModelService()

    private init() {}

    /// Whether on-device Foundation Models are available on this system.
    var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(macOS 26, *) {
            return SystemLanguageModel.default.availability == .available
        }
        #endif
        return false
    }

    // MARK: - Daily Briefing

    /// Generate a natural-language summary of today's schedule.
    /// Example: "Busy morning — 3 back-to-back meetings starting at 9, then free until your 1:1 with Sarah at 3."
    func generateDailyBriefing(meetings: [Meeting]) async -> String? {
        #if canImport(FoundationModels)
        if #available(macOS 26, *) {
            guard SystemLanguageModel.default.availability == .available else { return nil }
            guard !meetings.isEmpty else { return nil }

            let schedule = meetings
                .filter { !$0.isAllDay }
                .sorted()
                .map { meeting in
                    let time = Self.shortTime(meeting.startDate)
                    let end = Self.shortTime(meeting.endDate)
                    let duration = meeting.durationMinutes
                    return "- \(time)–\(end) (\(duration)m): \(meeting.title)"
                }
                .joined(separator: "\n")

            let allDayCount = meetings.filter { $0.isAllDay }.count
            let allDayNote = allDayCount > 0 ? "\nThere are also \(allDayCount) all-day event(s)." : ""

            let prompt = """
            You are a helpful calendar assistant. Summarize this person's schedule for today \
            in a concise, friendly way. Mention how busy they are, highlight important meetings, \
            and note any free time gaps. Keep it to 1-2 sentences.

            Today's meetings:
            \(schedule)\(allDayNote)
            """

            do {
                let session = LanguageModelSession()
                let result = try await session.respond(to: prompt, generating: DailyBriefing.self)
                return result.summary
            } catch {
                return nil
            }
        }
        #endif
        return nil
    }

    // MARK: - Meeting Summary

    /// Distill a meeting's notes/description into a quick 1-line summary.
    func summarizeMeeting(_ meeting: Meeting) async -> String? {
        #if canImport(FoundationModels)
        if #available(macOS 26, *) {
            guard SystemLanguageModel.default.availability == .available else { return nil }
            guard let notes = meeting.notes, !notes.isEmpty else { return nil }

            let prompt = """
            Summarize what this meeting is about in one short sentence based on its details.

            Title: \(meeting.title)
            Notes/Description:
            \(String(notes.prefix(500)))
            """

            do {
                let session = LanguageModelSession()
                let result = try await session.respond(to: prompt, generating: MeetingInsight.self)
                return result.summary
            } catch {
                return nil
            }
        }
        #endif
        return nil
    }

    // MARK: - Smart Title Abbreviation

    /// Intelligently abbreviate a meeting title to fit within a character limit.
    /// Unlike simple truncation, this preserves meaning.
    /// Example: "Quarterly Revenue Review Meeting" → "Q4 Rev Review" instead of "Quarterly Reven…"
    func abbreviateTitle(_ title: String, maxLength: Int) async -> String? {
        #if canImport(FoundationModels)
        if #available(macOS 26, *) {
            guard SystemLanguageModel.default.availability == .available else { return nil }
            guard title.count > maxLength else { return title }

            let prompt = """
            Abbreviate this meeting title to fit within \(maxLength) characters while preserving \
            its meaning. Use common abbreviations (Q1, Rev, Sync, etc). Do not use ellipsis. \
            Return only the abbreviated title.

            Title: \(title)
            """

            do {
                let session = LanguageModelSession()
                let result = try await session.respond(to: prompt, generating: SmartTitle.self)
                let abbreviated = result.abbreviated
                // Ensure it actually fits; fall back if the model overshot
                if abbreviated.count <= maxLength {
                    return abbreviated
                }
                return nil
            } catch {
                return nil
            }
        }
        #endif
        return nil
    }

    // MARK: - Conflict Description

    /// Describe overlapping meetings in a human-friendly way with a suggestion.
    func describeConflict(meeting1: Meeting, meeting2: Meeting) async -> String? {
        #if canImport(FoundationModels)
        if #available(macOS 26, *) {
            guard SystemLanguageModel.default.availability == .available else { return nil }

            let overlapMinutes = Int(
                min(meeting1.endDate, meeting2.endDate)
                    .timeIntervalSince(max(meeting1.startDate, meeting2.startDate)) / 60
            )
            guard overlapMinutes > 0 else { return nil }

            let prompt = """
            Two meetings overlap by \(overlapMinutes) minutes. Describe the conflict briefly \
            and suggest a practical resolution in one sentence.

            Meeting 1: "\(meeting1.title)" (\(Self.shortTime(meeting1.startDate))–\(Self.shortTime(meeting1.endDate)))
            Meeting 2: "\(meeting2.title)" (\(Self.shortTime(meeting2.startDate))–\(Self.shortTime(meeting2.endDate)))
            """

            do {
                let session = LanguageModelSession()
                let result = try await session.respond(to: prompt, generating: ConflictInsight.self)
                return result.description
            } catch {
                return nil
            }
        }
        #endif
        return nil
    }

    // MARK: - Helpers

    private static func shortTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}
