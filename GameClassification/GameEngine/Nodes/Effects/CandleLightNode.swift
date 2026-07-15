//
//  CandleLightNode.swift
//  GameClassification
//

import SpriteKit

/// A reusable, touch-transparent darkness overlay with a soft light centered on
/// a point in scene space. The radial falloff and flicker are rendered in one
/// fullscreen shader pass.
final class CandleLightNode: SKNode {

    struct Configuration {
        /// Distance from the light center to the fully dark area, in scene points.
        var radius: CGFloat

        /// Opacity outside the light radius. `0` is clear and `1` is black.
        var darknessOpacity: CGFloat

        /// Amount of darkness removed at the light center. `1` is fully lit.
        var lightIntensity: CGFloat

        /// Width of the feathered outer edge. Larger values make a softer falloff.
        var softness: CGFloat

        /// Vertical radius relative to the horizontal radius. Values above `1`
        /// create a subtle upright oval.
        var verticalScale: CGFloat

        /// Strength of the warm tint close to the character.
        var warmth: CGFloat

        /// Fractional radius variation used by the candle flicker. Set to `0`
        /// to disable flicker.
        var flickerAmount: CGFloat

        /// Multiplier for the flicker's animation speed.
        var flickerSpeed: CGFloat

        init(
            radius: CGFloat = 220,
            darknessOpacity: CGFloat = 0.94,
            lightIntensity: CGFloat = 1.0,
            softness: CGFloat = 0.42,
            verticalScale: CGFloat = 1.08,
            warmth: CGFloat = 0.08,
            flickerAmount: CGFloat = 0.025,
            flickerSpeed: CGFloat = 1.0
        ) {
            self.radius = radius
            self.darknessOpacity = darknessOpacity
            self.lightIntensity = lightIntensity
            self.softness = softness
            self.verticalScale = verticalScale
            self.warmth = warmth
            self.flickerAmount = flickerAmount
            self.flickerSpeed = flickerSpeed
        }
    }

    /// Update this value at runtime to tune the effect. Changes are applied
    /// without recreating the node or recompiling its shader.
    var configuration: Configuration {
        didSet { applyConfiguration() }
    }

    private let overlay: SKSpriteNode
    private let sceneSizeUniform: SKUniform
    private let lightCenterUniform: SKUniform
    private let radiusUniform: SKUniform
    private let darknessOpacityUniform: SKUniform
    private let lightIntensityUniform: SKUniform
    private let softnessUniform: SKUniform
    private let verticalScaleUniform: SKUniform
    private let warmthUniform: SKUniform
    private let flickerScaleUniform: SKUniform

    private var sceneSize: CGSize

    init(sceneSize: CGSize, configuration: Configuration = Configuration()) {
        let validSize = Self.validSize(sceneSize)
        self.sceneSize = validSize
        self.configuration = configuration

        sceneSizeUniform = SKUniform(
            name: "u_scene_size",
            vectorFloat2: SIMD2(Float(validSize.width), Float(validSize.height))
        )
        lightCenterUniform = SKUniform(
            name: "u_light_center",
            vectorFloat2: SIMD2(0.5, 0.5)
        )
        radiusUniform = SKUniform(name: "u_radius", float: 1)
        darknessOpacityUniform = SKUniform(name: "u_darkness_opacity", float: 1)
        lightIntensityUniform = SKUniform(name: "u_light_intensity", float: 1)
        softnessUniform = SKUniform(name: "u_softness", float: 1)
        verticalScaleUniform = SKUniform(name: "u_vertical_scale", float: 1)
        warmthUniform = SKUniform(name: "u_warmth", float: 0)
        flickerScaleUniform = SKUniform(name: "u_flicker_scale", float: 1)

        let shader = SKShader(
            source: Self.fragmentShader,
            uniforms: [
                sceneSizeUniform,
                lightCenterUniform,
                radiusUniform,
                darknessOpacityUniform,
                lightIntensityUniform,
                softnessUniform,
                verticalScaleUniform,
                warmthUniform,
                flickerScaleUniform
            ]
        )

        overlay = SKSpriteNode(color: .white, size: validSize)
        overlay.anchorPoint = .zero
        overlay.position = .zero
        overlay.name = "candleLightOverlay"
        overlay.shader = shader

        super.init()

        isUserInteractionEnabled = false
        addChild(overlay)
        applyConfiguration()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Moves the bright area to a point expressed in the overlay's scene space.
    /// Call after moving the character so the light uses the latest position.
    func update(lightPosition: CGPoint) {
        let normalizedX = Float(lightPosition.x / sceneSize.width)
        let normalizedY = Float(lightPosition.y / sceneSize.height)
        lightCenterUniform.vectorFloat2Value = SIMD2(normalizedX, normalizedY)
    }

    /// Updates the light position and evaluates the subtle radius flicker once
    /// for this frame, avoiding trigonometry in every fragment on the GPU.
    func update(lightPosition: CGPoint, currentTime: TimeInterval) {
        update(lightPosition: lightPosition)

        let speed = max(configuration.flickerSpeed, 0)
        let time = CGFloat(currentTime) * speed
        let wave =
              0.55 * sin(time * 5.3)
            + 0.30 * sin(time * 8.7 + 1.7)
            + 0.15 * sin(time * 13.1 + 0.4)
        let amount = configuration.flickerAmount.clamped(to: 0...0.15)
        flickerScaleUniform.floatValue = Float(1 + amount * wave)
    }

    /// Keeps the overlay fullscreen after rotation or any scene-size change.
    func resize(to newSize: CGSize) {
        sceneSize = Self.validSize(newSize)
        overlay.size = sceneSize
        sceneSizeUniform.vectorFloat2Value = SIMD2(
            Float(sceneSize.width),
            Float(sceneSize.height)
        )
    }

    private func applyConfiguration() {
        radiusUniform.floatValue = Float(max(configuration.radius, 1))
        darknessOpacityUniform.floatValue = Float(configuration.darknessOpacity.clamped(to: 0...1))
        lightIntensityUniform.floatValue = Float(configuration.lightIntensity.clamped(to: 0...1))
        softnessUniform.floatValue = Float(configuration.softness.clamped(to: 0.05...0.75))
        verticalScaleUniform.floatValue = Float(max(configuration.verticalScale, 0.1))
        warmthUniform.floatValue = Float(configuration.warmth.clamped(to: 0...1))
        if configuration.flickerAmount <= 0 || configuration.flickerSpeed <= 0 {
            flickerScaleUniform.floatValue = 1
        }
    }

    private static func validSize(_ size: CGSize) -> CGSize {
        CGSize(width: max(size.width, 1), height: max(size.height, 1))
    }

    private static let fragmentShader = """
    void main() {
        vec2 delta = (v_tex_coord - u_light_center) * u_scene_size;
        delta.y /= max(u_vertical_scale, 0.1);

        float flickeredRadius = max(
            1.0,
            u_radius * u_flicker_scale
        );

        float distanceFromLight = length(delta) / flickeredRadius;
        float coreFade = smoothstep(0.06, 0.28, distanceFromLight);
        float middleFade = smoothstep(0.20, 0.72, distanceFromLight);
        float edgeStart = clamp(1.0 - u_softness, 0.20, 0.95);
        float edgeFade = smoothstep(edgeStart, 1.0, distanceFromLight);

        float lightProfile =
            (1.0 - 0.12 * coreFade)
            * (1.0 - 0.55 * middleFade)
            * (1.0 - edgeFade);
        lightProfile = clamp(lightProfile, 0.0, 1.0);

        float illumination = clamp(
            u_light_intensity * lightProfile,
            0.0,
            1.0
        );
        float darkAlpha = clamp(
            u_darkness_opacity * (1.0 - illumination),
            0.0,
            1.0
        );

        float warmAlpha = clamp(
            u_warmth * lightProfile * lightProfile,
            0.0,
            1.0
        );
        vec3 warmColor = vec3(1.0, 0.58, 0.20);

        // Premultiplied result of warm light followed by the black overlay.
        float outputAlpha = darkAlpha + warmAlpha * (1.0 - darkAlpha);
        vec3 outputColor = warmColor * warmAlpha * (1.0 - darkAlpha);
        gl_FragColor = vec4(outputColor, outputAlpha);
    }
    """
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
