import Foundation

enum UpdateConfiguration {
    static func isValid(feed: String?, publicKey: String?) -> Bool {
        guard let feed, let url = URL(string: feed),
              url.scheme?.lowercased() == "https", let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil,
              let publicKey, let key = Data(base64Encoded: publicKey), key.count == 32 else {
            return false
        }
        return true
    }
}
