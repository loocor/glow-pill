import XCTest

@testable import GlowPill

final class ShaderBundleTests: XCTestCase {
    func testCompiledShaderLibraryIsBundled() throws {
        let metallib = Bundle.module.url(forResource: "default", withExtension: "metallib")
        XCTAssertNotNil(
            metallib,
            "default.metallib missing from the package bundle; .metal was not compiled")
    }
}
