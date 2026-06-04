import Testing
@testable import CopyCatCore

@Test func protectedZonesAreDetected() {
    let home = "/Users/x"
    #expect(isProtectedLocation("/Users/x/Desktop", home: home) == true)
    #expect(isProtectedLocation("/Users/x/Desktop/Shots", home: home) == true)
    #expect(isProtectedLocation("/Users/x/Documents", home: home) == true)
    #expect(isProtectedLocation("/Users/x/Downloads/sub", home: home) == true)
}

@Test func ownFoldersAreNotProtected() {
    let home = "/Users/x"
    #expect(isProtectedLocation("/Users/x/Pictures/Screenshots", home: home) == false)
    #expect(isProtectedLocation("/Users/x/Screenshots", home: home) == false)
}

@Test func savingToDiskWhenTargetMissingOrFile() {
    #expect(savingToDisk(target: nil) == true)
    #expect(savingToDisk(target: "file") == true)
}

@Test func notSavingToDiskWhenClipboardOnly() {
    #expect(savingToDisk(target: "clipboard") == false)
    #expect(savingToDisk(target: "preview") == false)
}
