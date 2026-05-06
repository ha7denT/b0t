import SpriteKit

/// CRT scanline overlay shader — applied to the Eye-screen Part only.
///
/// Per `aesthetic-references.md`: subtle CRT overlay (toggleable). Bloom on the active wiring.
/// Warm phosphor — amber, green, cream. Never blue.
///
/// This is the *only* CRT surface in the system. Skull, Jaw, organs, heart, wiring,
/// and the LCD inspection panel all use distinct visual languages.
public enum CRTScanlineShader {
    public static func make(intensity: Float = 0.18, lineCount: Float = 96.0) -> SKShader {
        let source = """
            void main() {
                vec4 color = texture2D(u_texture, v_tex_coord);
                float scanline = sin(v_tex_coord.y * u_lineCount * 3.14159) * 0.5 + 0.5;
                float darken = mix(1.0, 1.0 - u_intensity, scanline);
                gl_FragColor = vec4(color.rgb * darken, color.a);
            }
            """
        let shader = SKShader(source: source)
        shader.uniforms = [
            SKUniform(name: "u_intensity", float: intensity),
            SKUniform(name: "u_lineCount", float: lineCount),
        ]
        return shader
    }
}
