import SpriteKit
import XCTest

@testable import b0tDesign

final class CRTScanlineShaderTests: XCTestCase {
    func test_shader_isInstantiable() {
        let shader = CRTScanlineShader.make()
        XCTAssertFalse(shader.source?.isEmpty ?? true, "shader source must not be empty")
    }

    func test_shader_hasScanlineUniforms() {
        let shader = CRTScanlineShader.make()
        let uniformNames = shader.uniforms.map(\.name)
        XCTAssertTrue(uniformNames.contains("u_intensity"), "uniforms: \(uniformNames)")
        XCTAssertTrue(uniformNames.contains("u_lineCount"), "uniforms: \(uniformNames)")
    }
}
