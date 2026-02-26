import Foundation

final class CalendarCache {
    struct CacheEntry {
        let meetings: [Meeting]
        let fetchedAt: Date
    }

    private var cache: [String: CacheEntry] = [:]  // key = "providerType_dateString"
    private var ttl: TimeInterval  // seconds before entry expires
    private let queue = DispatchQueue(label: "com.memcache.calendarCache")

    init(ttl: TimeInterval = 60) {
        self.ttl = ttl
    }

    func cacheKey(provider: CalendarProviderType, date: Date) -> String {
        let dateStr = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: date))
        return "\(provider.rawValue)_\(dateStr)"
    }

    func get(provider: CalendarProviderType, date: Date) -> [Meeting]? {
        queue.sync {
            let key = cacheKey(provider: provider, date: date)
            guard let entry = cache[key] else { return nil }
            if Date().timeIntervalSince(entry.fetchedAt) > ttl {
                cache.removeValue(forKey: key)
                return nil
            }
            return entry.meetings
        }
    }

    func set(_ meetings: [Meeting], provider: CalendarProviderType, date: Date) {
        queue.sync {
            let key = cacheKey(provider: provider, date: date)
            cache[key] = CacheEntry(meetings: meetings, fetchedAt: Date())
        }
    }

    func invalidate(provider: CalendarProviderType) {
        queue.sync {
            cache = cache.filter { !$0.key.hasPrefix(provider.rawValue) }
        }
    }

    func invalidateAll() {
        queue.sync {
            cache.removeAll()
        }
    }

    func updateTTL(_ newTTL: TimeInterval) {
        queue.sync {
            self.ttl = newTTL
        }
    }
}
