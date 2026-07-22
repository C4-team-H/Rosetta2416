import SpriteKit
import Testing
@testable import GameClassification

@Suite("Victory launch cutscene")
@MainActor
struct VictoryLaunchSceneTests {
    @Test("Builds the supplied background, ship, and looping four-frame jet animation")
    func buildsLaunchComposition() throws {
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 1_024, height: 768))
        let scene = VictoryLaunchScene(size: view.bounds.size) {}
        scene.scaleMode = .resizeFill

        view.presentScene(scene)

        let background = try #require(scene.childNode(withName: VictoryLaunchScene.backgroundNodeName))
        let assembly = try #require(scene.childNode(withName: VictoryLaunchScene.shipAssemblyNodeName))
        let ship = try #require(assembly.childNode(withName: VictoryLaunchScene.shipNodeName) as? SKSpriteNode)
        let jetFire = try #require(assembly.childNode(withName: VictoryLaunchScene.jetFireNodeName) as? SKSpriteNode)

        #expect(background is SKSpriteNode)
        #expect(ship.size.width > 0)
        #expect(ship.size.height > 0)
        #expect(jetFire.position.y < 0)
        #expect(jetFire.action(forKey: VictoryLaunchScene.jetFireAnimationKey) != nil)
        #expect(assembly.action(forKey: VictoryLaunchScene.launchAnimationKey) != nil)
        #expect(assembly.position.y < 0)
    }
}
