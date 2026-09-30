import AgentCronCore
import Foundation
import Testing

@Suite("StorageLocation")
struct StorageLocationTests {
    @Test
    func `the root is a folder named for the bundle identifier inside Application Support`() {
        let applicationSupport = URL(
            filePath: "/Users/example/Library/Application Support",
            directoryHint: .isDirectory,
        )
        let root = StorageLocation.root(inApplicationSupport: applicationSupport)
        #expect(root
            .path(percentEncoded: false) ==
            "/Users/example/Library/Application Support/io.github.tomada1114.AgentCron/")
        #expect(root.hasDirectoryPath)
    }
}
