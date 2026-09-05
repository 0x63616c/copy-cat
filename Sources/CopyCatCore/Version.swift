import Foundation

public enum CopyCatCore {
    /// The release script reads this value; Info.plist is stamped during bundling.
    public static let version = "0.2.0"
    public static var installedVersion: String {
        appBundle?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? version
    }
    public static var build: String? {
        appBundle?.object(forInfoDictionaryKey: "CopyCatBuildNumber") as? String
    }
    private static var appBundle: Bundle? {
        Bundle.main.bundleIdentifier == "com.0x63616c.copy-cat" ? Bundle.main : nil
    }
}
