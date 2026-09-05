import CryptoKit
import Foundation

// Public-key-only verification; never reads Keychain or signing secrets.
let args = CommandLine.arguments
func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}
guard args.count == 4 || args.count == 5,
      let signature = Data(base64Encoded: args[2]),
      let keyData = Data(base64Encoded: args[3]) else { fail("Usage: verify-signature.swift file signature public-key [signed-byte-count]") }
do {
    let key = try Curve25519.Signing.PublicKey(rawRepresentation: keyData)
    let contents = try Data(contentsOf: URL(fileURLWithPath: args[1]))
    let count = args.count == 5 ? Int(args[4]) ?? -1 : contents.count
    guard count > 0, count <= contents.count else { fail("Invalid signed byte count") }
    let data = Data(contents.prefix(count))
    guard key.isValidSignature(signature, for: data) else { fail("Signature verification failed: \(args[1])") }
    var tampered = data
    tampered[tampered.startIndex] ^= 1
    guard !key.isValidSignature(signature, for: tampered) else { fail("Tampered content was accepted") }
    print("Signature verified; tamper control rejected: \(URL(fileURLWithPath: args[1]).lastPathComponent)")
} catch { fail("Signature verification failed: \(error)") }
