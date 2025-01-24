//
//  GameScene.swift
//  AsteroidZ
//
//  Created by SuperBox64m on 12/31/24.
//

import SpriteKit
import GameplayKit
import GameController

class GameScene: SKScene, SKPhysicsContactDelegate {
    
    private var player: SKShapeNode!
    private var rotationRate: CGFloat = 0
    private var thrustDirection: CGFloat = 0
    private var velocity = CGVector(dx: 0, dy: 0)
    private var asteroids = [SKShapeNode]()
    
    // Add these new properties
    private var bullets = [SKShapeNode]()
    private var lastFireTime: TimeInterval = 0
    private var fireRate: TimeInterval = 0.2 // Minimum time between shots
    
    // Add new properties at the top
    private var scoreLabel: SKLabelNode!
    private var livesLabel: SKLabelNode!
    private var highScoreLabel: SKLabelNode!
    
    // Add these properties at the top of the class
    private var scoreNodes: [SKShapeNode] = []
    private var highScoreNodes: [SKShapeNode] = []
    private var livesNodes: [SKShapeNode] = []
    private let extraShipBonus = 5000
    
    private var score: Int = 0 {
        didSet {
            updateScore()
            
            // Check for extra ship bonus
            if score >= lastExtraShipScore + extraShipBonus {
                awardExtraShip()
                lastExtraShipScore = score - (score % extraShipBonus)
            }
            
            // Update high score if needed
            if score > highScore {
                highScore = score
                UserDefaults.standard.set(highScore, forKey: "highScore")
            }
        }
    }
    private var lives: Int = 3 {
        didSet {
            updateLives()
        }
    }
    private var highScore: Int = UserDefaults.standard.integer(forKey: "highScore") {
        didSet {
            updateHighScore()
        }
    }
    
    // Add new properties
    private var isRespawning = false
    private var respawnSafeRadius: CGFloat = 100
    
    // Add new property for thrust visual
    private var thrustNode: SKShapeNode?
    
    // Add physics categories
    let shipCategory: UInt32 = 0x1 << 0      // 0001
    let asterCategory: UInt32 = 0x1 << 1      // 0010
    let roidCategory: UInt32 = 0x1 << 2       // 0100
    let bulletCategory: UInt32 = 0x1 << 3     // 1000
    let allAsteroidsCategory: UInt32 = 0x1 << 1 | 0x1 << 2  // 0110 (combines Aster and Roid)
    let saucerCategory: UInt32 = 0x1 << 4
    let saucerBulletCategory: UInt32 = 0x1 << 5
    
    // Add toggle for asteroid type
    private var isNextAster = true  // Toggle between Aster and Roid
    
    // Add property at top of class
    private var isGameOver = false
    
    // Audio properties
    private var fireSound: SKAction!
    private var bangLargeSound: SKAction!
    private var bangMediumSound: SKAction!
    private var bangSmallSound: SKAction!
    private var extraShipSound: SKAction!
    private var lastExtraShipScore = 0  // Track when we last gave an extra ship
    
    // Add property to track wrapped sprites
    private var wrappedSprites: [SKNode: SKNode] = [:]
    
    // Add at top of class
    private let maxAsterVelocity: CGFloat = 300.0  // Maximum speed for Aster type asteroids
    
    enum SaucerSize {
        case large
        case small
    }
    
    private var activeSaucer: SKShapeNode?
    private var saucerSound: SKAudioNode?
    private var saucerBigSound: SKAction!
    private var saucerSmallSound: SKAction!
    private var saucerTimer: Timer?
    
    // Add at top of class
    private var saucerShootTimer: Timer?
    private let largeShootInterval: TimeInterval = 1.5  // Large saucer shoots slower
    private let smallShootInterval: TimeInterval = 0.8   // Small saucer shoots faster
    
    // Add at top of class
    private var saucerDistanceTraveled: CGFloat = 0
    private let saucerChangeDirectionDistance: CGFloat = 300
    
    // Add at top of class
    private let initialAsteroidSpeed: CGFloat = 50.0   // Reduced from 68.75
    private let maxAsteroidSpeed: CGFloat = 100.0      // Reduced from 206.25
    private var currentAsteroidSpeed: CGFloat = 50.0   // Start at new initial speed
    
    // At top of class
    private var shipThrustSpeed: CGFloat = 15.0  // Reduced by 90% from 150 to 15
    
    // At top of class
    private var thrustSoundAction: SKAction!
    
    // Audio properties
    private var beat1: SKAction!
    private var beat2: SKAction!
    // Beat system properties
    private var beatTimer: Timer?
    private var currentBeat = 1
    private var beatInterval: TimeInterval = 1.0
    private let minBeatInterval: TimeInterval = 0.3
    private let maxBeatInterval: TimeInterval = 1.0
    
    // KEEP only this at class level
    private var reverseFlameNode: SKShapeNode?
    
    // At class level, add these properties
    private var fadeInAction: SKAction!
    private var throbAction: SKAction!
    
    // Add at top of class
    private var asteroidCountLabel: SKLabelNode!
    private var beatIntervalLabel: SKLabelNode!
    private var intervalChangedLabel: SKLabelNode!
    
    // Add at top of class with other properties
    private var showDebugInfo: Bool = false  // Set to false by default
    
    // Add at top of class
    private var baseSaucerInterval: TimeInterval = 20.0  // Base spawn interval
    private var minSaucerInterval: TimeInterval = 5.0    // Minimum spawn interval
    private var maxSaucerInterval: TimeInterval = 15.0   // Maximum spawn interval
    
    // Add at class level
    private var gameOverLabels: [SKLabelNode] = []
    
    // Add at class level
    private var level: Int = 1
    
    // Add at class level
    private var isFullscreen = true  // Start in fullscreen mode
    
    // At class level
    private var titleScreen: SKShapeNode?
    
    // At class level
    private var saucerSpawnEnabled = true  // Track if spawning is enabled
    
    // Add at top of file
    private var gamePadConnected = false
    
    // Add at top of class
    private var keyboardLeft = false
    private var keyboardRight = false
    
    // Add back the thrust sound properties
    private var thrustSound: SKAction!
    private let thrustSoundKey = "thrustSound"  // Unique key for the sound action
    private var thrustSoundNode: SKAudioNode?  // To track and stop the sound
    
    // Add at top of class
    private var gameOverScreen: SKNode?  // Track the game over screen node
    
    // Add at top of class
    private var isSpaceKeyDown = false  // Track spacebar state
    
    // Add this function to GameScene class
    func setupGameController() {
        // Enable game controller support
        GCController.startWirelessControllerDiscovery()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleControllerDidConnect),
            name: .GCControllerDidConnect,
            object: nil
        )
        
        // Check for already connected controller
        if let controller = GCController.controllers().first {
            configureGameController(controller)
        }
    }
    
    @objc func handleControllerDidConnect(_ notification: Notification) {
        if let gameController = notification.object as? GCController {
            configureGameController(gameController)
            gamePadConnected = true
        }
    }
    
    func configureGameController(_ controller: GCController) {
        guard let gamepad = controller.extendedGamepad else { return }
        
        // Configure D-pad
        gamepad.dpad.valueChangedHandler = { [weak self] _, xValue, yValue in
            self?.handleDirectionalInput(x: xValue, y: yValue)
        }
        
        // Configure left stick - same controls as D-pad
        gamepad.leftThumbstick.valueChangedHandler = { [weak self] _, xValue, yValue in 
            self?.handleDirectionalInput(x: xValue, y: yValue)
        }
        
        // A button for firing
        gamepad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                self?.fireBullet()
            }
        }
        
        gamepad.buttonB.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                self?.fireBullet()
            }
        }
        
        gamepad.buttonX.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                self?.thrustDirection = CGFloat(1)
                self?.showThrustFlame()
            } else {
                self?.thrustDirection = 0
                self?.hideThrustFlame()
            }
        }
        
        gamepad.buttonY.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                self?.thrustDirection = CGFloat(-1)
                self?.showReverseFlame()
            } else {
                self?.thrustDirection = 0
                self?.hideReverseFlame()
            }
        }
    }
    
    private func handleDirectionalInput(x: Float, y: Float) {
        // Rotation only for left/right (same as keyboard)
        
        
        if x == -1 {
            rotationRate = 1.0
        } else if x == 1 {
            rotationRate = -1.0
        } else {
            rotationRate = 0
        }
        

//        if y == 1 {
//            thrustDirection = CGFloat(y)
//            showThrustFlame()
//        } else if y == -1 {
//            thrustDirection = CGFloat(y)
//            showReverseFlame()
//        } else {
//            thrustDirection = 0
//            hideThrustFlame()
//            hideReverseFlame()
//        }
        

    }
    
    // Add at top of class
    private func createPlayerShip() -> SKShapeNode {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 20))    // Top point
        path.addLine(to: CGPoint(x: -15, y: -20)) // Bottom left
        path.addLine(to: CGPoint(x: 15, y: -20))  // Bottom right
        path.closeSubpath()
        
        let ship = SKShapeNode(path: path)
        ship.strokeColor = .white
        ship.lineWidth = 2.0
        ship.fillColor = .black
        
        // Setup physics body
        ship.physicsBody = SKPhysicsBody(polygonFrom: path)
        ship.physicsBody?.categoryBitMask = shipCategory
        ship.physicsBody?.contactTestBitMask = asterCategory | roidCategory | saucerCategory | saucerBulletCategory
        ship.physicsBody?.collisionBitMask = 0
        ship.physicsBody?.affectedByGravity = false
        ship.physicsBody?.isDynamic = true
        ship.physicsBody?.usesPreciseCollisionDetection = true
        ship.name = "PlayerShip"
        return ship
    }
    
    func createSaucer(size: SaucerSize) -> SKShapeNode {
        let path = CGMutablePath()
        let scale: CGFloat = size == .large ? 1.0 : 0.5
        
        // Create a path that follows ALL the lines of the saucer
        path.move(to: CGPoint(x: -40 * scale, y: 0))
        path.addLine(to: CGPoint(x: -20 * scale, y: 20 * scale))
        path.addLine(to: CGPoint(x: 20 * scale, y: 20 * scale))
        path.addLine(to: CGPoint(x: 40 * scale, y: 0))
        path.addLine(to: CGPoint(x: 20 * scale, y: -20 * scale))
        path.addLine(to: CGPoint(x: -20 * scale, y: -20 * scale))
        path.closeSubpath()  // Close the main body
        
        // Create visual path with all details
        let visualPath = path.mutableCopy()!
        
        // Add the middle line
        visualPath.move(to: CGPoint(x: -40 * scale, y: 0))
        visualPath.addLine(to: CGPoint(x: 40 * scale, y: 0))
        
        // Add the top canopy
        visualPath.move(to: CGPoint(x: -15 * scale, y: 20 * scale))
        visualPath.addLine(to: CGPoint(x: -10 * scale, y: 35 * scale))
        visualPath.addLine(to: CGPoint(x: 10 * scale, y: 35 * scale))
        visualPath.addLine(to: CGPoint(x: 15 * scale, y: 20 * scale))
        
        // Add the bottom canopy
        visualPath.move(to: CGPoint(x: -15 * scale, y: -20 * scale))
        visualPath.addLine(to: CGPoint(x: -10 * scale, y: -25 * scale))
        visualPath.addLine(to: CGPoint(x: 10 * scale, y: -25 * scale))
        visualPath.addLine(to: CGPoint(x: 15 * scale, y: -20 * scale))
        
        let saucer = SKShapeNode(path: visualPath)  // Use detailed path for visuals
        saucer.strokeColor = .white
        saucer.lineWidth = 2.0
        
        // Use simpler path for physics body
        saucer.physicsBody = SKPhysicsBody(polygonFrom: path)
        saucer.physicsBody?.categoryBitMask = saucerCategory
        saucer.physicsBody?.collisionBitMask = asterCategory  // Add collision with Aster type
        saucer.physicsBody?.contactTestBitMask = bulletCategory | asterCategory  // Test contact with bullets and Asters
        saucer.physicsBody?.affectedByGravity = false
        saucer.physicsBody?.linearDamping = 0
        saucer.physicsBody?.angularDamping = 0
        saucer.name = "Saucer"
        return saucer
    }
    
    override func sceneDidLoad() {
        super.sceneDidLoad()
        setupGameController()  // Add this line
        
        // Set black background
        backgroundColor = .black
        
        // Enable physics world and contact delegate
        physicsWorld.contactDelegate = self
        
        // // Initialize fade and throb actions with longer durations
        // fadeInAction = SKAction.fadeIn(withDuration: 1.0)  // Longer fade-in (3 seconds)
        // throbAction = SKAction.sequence([
        //     SKAction.group([
        //         SKAction.repeat(
        //             SKAction.sequence([
        //                 SKAction.fadeAlpha(to: 0.5, duration: 0.5),
        //                 SKAction.scale(to: 0.9, duration: 0.5),      // Start at half size
        //                 SKAction.scale(to: 1.0, duration: 0.5),  // Scale up over 3 seconds
        //                 SKAction.fadeAlpha(to: 1.0, duration: 0.5)
        //             ]),
        //             count: 1
        //         )
        //     ])
        // ])
        
        // Create player ship with exact edge physics body
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 20))    // Top point
        path.addLine(to: CGPoint(x: -15, y: -20)) // Bottom left
        path.addLine(to: CGPoint(x: 15, y: -20))  // Bottom right
        path.closeSubpath()
        
        player = SKShapeNode(path: path)
        player.strokeColor = .white
        player.lineWidth = 2.0
        player.fillColor = .black
        
        // Update physics body settings for player
        player.physicsBody = SKPhysicsBody(polygonFrom: path)
        player.physicsBody?.categoryBitMask = shipCategory
        player.physicsBody?.contactTestBitMask = asterCategory | roidCategory | saucerCategory | saucerBulletCategory  // Test ALL asteroid types
        player.physicsBody?.collisionBitMask = 0  // Don't physically collide, just detect contact
        player.physicsBody?.affectedByGravity = false
        player.physicsBody?.isDynamic = true
        player.physicsBody?.usesPreciseCollisionDetection = true
        player.name = "Loaded PlayerShip"
        player.alpha = 0  // Start completely invisible
        player.isHidden = true  // Hide it completely
        addChild(player)
        
        // Add initial asteroids
        for _ in 0..<10 {
            spawnAsteroid(size: .large)
        }
        
        // Initialize the displays with vector graphics
        updateScore()
        updateHighScore()
        updateLives()
        
        // Create thrust visual
        let thrustPath = CGMutablePath()
        thrustPath.move(to: CGPoint(x: -8, y: -20))  // Left base of triangle
        thrustPath.addLine(to: CGPoint(x: 0, y: -30)) // Thrust point
        thrustPath.addLine(to: CGPoint(x: 8, y: -20))  // Right base of triangle
        
        thrustNode = SKShapeNode(path: thrustPath)
        thrustNode?.strokeColor = .white
        thrustNode?.lineWidth = 2.0
        thrustNode?.fillColor = .clear
        thrustNode?.isHidden = true
        player.addChild(thrustNode!)
        
        // Create reverse thrust visual
        let reverseThrustPath = CGMutablePath()
        reverseThrustPath.move(to: CGPoint(x: -8, y: 20))  // Left base at top
        reverseThrustPath.addLine(to: CGPoint(x: 0, y: 30)) // Thrust point at top
        reverseThrustPath.addLine(to: CGPoint(x: 8, y: 20))  // Right base at top
        
        reverseFlameNode = SKShapeNode(path: reverseThrustPath)
        reverseFlameNode?.strokeColor = .white
        reverseFlameNode?.lineWidth = 2.0
        reverseFlameNode?.fillColor = .clear
        reverseFlameNode?.isHidden = true
        player.addChild(reverseFlameNode!)
        
  
        
        // Setup audio actions with proper volume
        beat1 = SKAction.playSoundFileNamed("beat1.wav", waitForCompletion: false)
        beat2 = SKAction.playSoundFileNamed("beat2.wav", waitForCompletion: false)
        fireSound = SKAction.playSoundFileNamed("fire.wav", waitForCompletion: false)
        bangLargeSound = SKAction.playSoundFileNamed("bangLarge.wav", waitForCompletion: false)
        bangMediumSound = SKAction.playSoundFileNamed("bangMedium.wav", waitForCompletion: false)
        bangSmallSound = SKAction.playSoundFileNamed("bangSmall.wav", waitForCompletion: false)
        extraShipSound = SKAction.playSoundFileNamed("extraShip.wav", waitForCompletion: false)
        saucerBigSound = SKAction.playSoundFileNamed("saucerBig.wav", waitForCompletion: false)
        saucerSmallSound = SKAction.playSoundFileNamed("saucerSmall.wav", waitForCompletion: false)
        thrustSound = SKAction.playSoundFileNamed("thrust.wav", waitForCompletion: false)
        
        // Spawn first saucer immediately
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {  // 5 second initial delay
            self.spawnSaucer(forcedSize: .large)  // Force first saucer to be large
        }
        
        // Start regular saucer timer
        startSaucerTimer()
        
        // Setup thrust sound
        thrustSoundAction = SKAction.playSoundFileNamed("thrust.wav", waitForCompletion: false)
      
        // Start background beats immediately after setup
        startBackgroundBeats()
        
        // Setup debug labels but hide them initially
        asteroidCountLabel = SKLabelNode(fontNamed: "Avenir-Medium")
        asteroidCountLabel.fontSize = 20
        asteroidCountLabel.position = CGPoint(x: frame.midX, y: frame.maxY - 60)
        asteroidCountLabel.fontColor = .green
        asteroidCountLabel.alpha = 0.5  // 50% opacity
        asteroidCountLabel.isHidden = !showDebugInfo
        addChild(asteroidCountLabel)
        
        beatIntervalLabel = SKLabelNode(fontNamed: "Avenir-Medium")
        beatIntervalLabel.fontSize = 20
        beatIntervalLabel.position = CGPoint(x: frame.midX, y: frame.maxY - 90)
        beatIntervalLabel.fontColor = .blue
        beatIntervalLabel.alpha = 0.5  // 50% opacity
        beatIntervalLabel.isHidden = !showDebugInfo
        addChild(beatIntervalLabel)
        
        intervalChangedLabel = SKLabelNode(fontNamed: "Avenir-Medium")
        intervalChangedLabel.fontSize = 20
        intervalChangedLabel.position = CGPoint(x: frame.midX, y: frame.maxY - 120)
        //intervalChangedLabel.fontColor = .red
        intervalChangedLabel.alpha = 0.5  // 50% opacity
        intervalChangedLabel.isHidden = !showDebugInfo
        addChild(intervalChangedLabel)
        
        // Add level label
        setupLevelLabel()
        
        if score == 0 {
            showTitleScreen()
//            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
//                self.tryRespawn()
//            }
        } else {
            self.tryRespawn()
        }
    
    }
    
    private func updateLevel() {
        // Remove existing level nodes
        children.filter { $0.name == "levelNode" }.forEach { $0.removeFromParent() }
        
        // Draw level number at bottom left
        let levelNode = drawVectorNumber(level, at: CGPoint(x: size.width * 0.05, y: size.height * 0.05))
        levelNode.name = "levelNode"
        addChild(levelNode)
    }
    
    // Update the setupLevelLabel function to use vector numbers instead
    func setupLevelLabel() {
        updateLevel()
    }
    
    func startSaucerTimer() {
        // Clear any existing timer
        saucerTimer?.invalidate()
        
        // Create new timer
        saucerTimer = Timer.scheduledTimer(withTimeInterval: baseSaucerInterval, repeats: true) { [weak self] _ in
            self?.spawnSaucer()
        }
        
        // Add to RunLoop
        if let timer = saucerTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }
    
    // Add these new methods for asteroids and bullets
    enum AsteroidSize {
        case large, medium, small
        
        var radius: CGFloat {
            switch self {
            case .large: return 40
            case .medium: return 20
            case .small: return 10
            }
        }
        
        var points: Int {
            switch self {
            case .large: return 8
            case .medium: return 6
            case .small: return 4
            }
        }
    }
    
    func createAsteroidPath(radius: CGFloat, points: Int) -> CGPath {
        let path = CGMutablePath()
        let angleStep = (CGFloat.pi * 2) / CGFloat(points)
        
        var firstPoint = CGPoint()
        
        // Create more points for smoother shape
        let totalPoints = points * 3
        
        for i in 0..<totalPoints {
            let baseAngle = angleStep * CGFloat(i) / 3.0
            
            // Create occasional inward/outward variations
            let radiusVariation: CGFloat
            if i % 3 == 0 {
                // Main points stay closer to circle
                radiusVariation = CGFloat.random(in: 0.9...1.1)
            } else {
                // Intermediate points can vary more dramatically
                radiusVariation = CGFloat.random(in: 0.7...1.2)
            }
            
            let currentRadius = radius * radiusVariation
            let x = cos(baseAngle) * currentRadius
            let y = sin(baseAngle) * currentRadius
            
            if i == 0 {
                firstPoint = CGPoint(x: x, y: y)
                path.move(to: firstPoint)
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        path.addLine(to: firstPoint)
        return path
    }
    
    func spawnAsteroid(size: AsteroidSize) {
        // Try to find a safe spawn position
        var safePosition: CGPoint?
        let safeRadius: CGFloat = 100  // Minimum distance between asteroids
        let centerSafeRadius: CGFloat = 200  // Keep large asteroids away from center
        let maxAttempts = 10  // Maximum attempts to find safe position
        
        // Ensure asteroids spawn away from the player ship
        let playerSafeRadius: CGFloat = 150  // Minimum distance from player
        
        for _ in 0..<maxAttempts {
            // Generate random position
            let x = CGFloat.random(in: 0...frame.width)
            let y = CGFloat.random(in: 0...frame.height)
            let testPosition = CGPoint(x: x, y: y)
            
            // Check if position is safe
            var positionIsSafe = true
            
            // Ensure asteroids are away from the player
            if let player = player {
                let distanceFromPlayer = hypot(testPosition.x - player.position.x, testPosition.y - player.position.y)
                if distanceFromPlayer < playerSafeRadius {
                    positionIsSafe = false
                    continue
                }
            }
            
            // For large asteroids, ensure they're away from center
            if size == .large {
                let distanceFromCenter = hypot(testPosition.x - frame.midX, testPosition.y - frame.midY)
                if distanceFromCenter < centerSafeRadius {
                    positionIsSafe = false
                    continue
                }
                
                // Check distance from other large asteroids
                for asteroid in asteroids where asteroid.userData?["size"] as? AsteroidSize == .large {
                    let distance = hypot(asteroid.position.x - testPosition.x, asteroid.position.y - testPosition.y)
                    if distance < safeRadius {
                        positionIsSafe = false
                        break
                    }
                }
            }
            
            if positionIsSafe {
                safePosition = testPosition
                break
            }
        }
        
        // If no safe position found, force spawn at edge of screen
        let spawnPosition: CGPoint
        if safePosition == nil && size == .large {
            let angle = CGFloat.random(in: 0...(2 * .pi))
            spawnPosition = CGPoint(
                x: frame.midX + cos(angle) * centerSafeRadius,
                y: frame.midY + sin(angle) * centerSafeRadius
            )
        } else {
            spawnPosition = safePosition ?? CGPoint(x: frame.midX, y: frame.midY)
        }
        
        // Create asteroid at safe position
        let asteroid = createAsteroid(size: size)
        asteroid.position = spawnPosition
        
        addChild(asteroid)
        asteroids.append(asteroid)
    }
    
    func createAsteroid(size: AsteroidSize) -> SKShapeNode {
        let asteroidPath = createAsteroidPath(radius: size.radius, points: size.points)
        let asteroid = SKShapeNode(path: asteroidPath)
        asteroid.strokeColor = .white
        asteroid.lineWidth = 2.0
        
        // Initialize userData dictionary
        asteroid.userData = NSMutableDictionary()
        asteroid.userData?["size"] = size
        
        if isNextAster {
            asteroid.fillColor = .black     // TEMP: Color Asters red (was .black)
            asteroid.physicsBody = SKPhysicsBody(polygonFrom: asteroidPath)
            asteroid.physicsBody?.categoryBitMask = asterCategory
            asteroid.physicsBody?.contactTestBitMask = shipCategory
            asteroid.physicsBody?.collisionBitMask = asterCategory
            asteroid.physicsBody?.restitution = 0.8  // Reduced from 1.0
            asteroid.physicsBody?.friction = 0.2     // Added friction
            asteroid.physicsBody?.linearDamping = 0.1  // Added damping
            asteroid.physicsBody?.angularDamping = 0.1 // Added angular damping
            
            // Add initial rotation, but slower
            let rotationSpeed = CGFloat.random(in: -1.0...1.0)  // Reduced rotation speed
            asteroid.physicsBody?.angularVelocity = rotationSpeed
            asteroid.name = "Asteroid"
        } else {
            asteroid.fillColor = .clear   // TEMP: Color Roids green (was .clear)
            asteroid.physicsBody = SKPhysicsBody(polygonFrom: asteroidPath)
            asteroid.physicsBody?.categoryBitMask = roidCategory
            asteroid.physicsBody?.contactTestBitMask = shipCategory
            asteroid.physicsBody?.collisionBitMask = 0
            asteroid.name = "Roid"
        }
        
        // Common physics properties
        asteroid.physicsBody?.usesPreciseCollisionDetection = true  // Add this for better collision detection
        asteroid.physicsBody?.restitution = 1.0
        asteroid.physicsBody?.friction = 0.0
        asteroid.physicsBody?.linearDamping = 0.0
        asteroid.physicsBody?.angularDamping = 0.0
        asteroid.physicsBody?.affectedByGravity = false
        asteroid.physicsBody?.isDynamic = true
        asteroid.physicsBody?.mass = 1.0  // Added mass for better collisions
        
        // Calculate velocity with current speed
        let angle = CGFloat.random(in: 0...(2 * .pi))
        let speed = CGFloat.random(in: currentAsteroidSpeed/2...currentAsteroidSpeed)
        let dx = cos(angle) * speed
        let dy = sin(angle) * speed
        
        asteroid.physicsBody?.velocity = CGVector(dx: dx, dy: dy)
        
        // Random position on the edge of the screen
        let side = Int.random(in: 0...3)
        switch side {
        case 0: // Top
            asteroid.position = CGPoint(x: CGFloat.random(in: 0...frame.width), y: frame.height)
        case 1: // Right
            asteroid.position = CGPoint(x: frame.width, y: CGFloat.random(in: 0...frame.height))
        case 2: // Bottom
            asteroid.position = CGPoint(x: CGFloat.random(in: 0...frame.width), y: 0)
        default: // Left
            asteroid.position = CGPoint(x: 0, y: CGFloat.random(in: 0...frame.height))
        }
        
        // Toggle for next spawn
        isNextAster.toggle()
        
        return asteroid
    }
    
    // Add helper function to check for overlap
    func isTooCloseToOtherAsteroids(position: CGPoint, radius: CGFloat, existingPositions: [CGPoint]) -> Bool {
        for existingPosition in existingPositions {
            let distance = hypot(position.x - existingPosition.x, position.y - existingPosition.y)
            if distance < radius * 2 {  // Use diameter for minimum separation
                return true
            }
        }
        return false
    }
    
    func fireBullet() {
        guard let currentPlayer = player else { return }  // Exit if no player
        
        // Create bullet
        let bullet = SKShapeNode(circleOfRadius: 2.0)
        bullet.strokeColor = .white
        bullet.fillColor = .white
        
        // Calculate position at tip of triangle (point facing forward)
        let tipOffset = CGPoint(x: -sin(currentPlayer.zRotation) * 20,  // Negative sin for correct x direction
                               y: cos(currentPlayer.zRotation) * 20)     // Positive cos for correct y direction
        bullet.position = CGPoint(x: currentPlayer.position.x + tipOffset.x,
                                y: currentPlayer.position.y + tipOffset.y)
        
        // Play fire sound
        run(fireSound)
        
        // Add physics body
        bullet.physicsBody = SKPhysicsBody(circleOfRadius: 2.0)
        bullet.physicsBody?.categoryBitMask = bulletCategory
        bullet.physicsBody?.collisionBitMask = 0
        bullet.physicsBody?.contactTestBitMask = allAsteroidsCategory | saucerCategory | saucerBulletCategory
        bullet.physicsBody?.affectedByGravity = false
        bullet.name = "PlayerBullet"
        // Set velocity in same direction as ship is pointing
        let bulletSpeed: CGFloat = 400.0
        bullet.physicsBody?.velocity = CGVector(dx: -sin(currentPlayer.zRotation) * bulletSpeed,  // Match direction
                                              dy: cos(currentPlayer.zRotation) * bulletSpeed)
        
        addChild(bullet)
        bullets.append(bullet)
        
        // Remove bullet after 2 seconds
        let waitAction = SKAction.wait(forDuration: 2.0)
        let removeAction = SKAction.run {
            bullet.removeFromParent()
            if let index = self.bullets.firstIndex(of: bullet) {
                self.bullets.remove(at: index)
            }
        }
        bullet.run(SKAction.sequence([waitAction, removeAction]))
    }
    
    override func keyDown(with event: NSEvent) {
        // Check for game over state first
        if isGameOver {
            if event.keyCode == 49 || // Spacebar
               event.keyCode == 23 || // 5 key
               event.keyCode == 8 {   // C key
                titleScreen?.removeFromParent()  // Remove title screen
                restartGame()
            }
            return  // Ignore other inputs during game over
        }
        
        switch event.keyCode {
        case 123, 0:  // Left arrow or 'a'
            keyboardLeft = true
            handleRotation()
        case 124, 2:  // Right arrow or 'd'
            keyboardRight = true
            handleRotation()
        case 126:     // Up arrow
            thrustDirection = 1.0
        case 125:     // Down arrow
            thrustDirection = -1.0
        case 49:      // Spacebar
            if !isSpaceKeyDown {  // Only fire if spacebar wasn't already down
                isSpaceKeyDown = true
                fireBullet()
            }
        default:
            break
        }
    }
    
    override func keyUp(with event: NSEvent) {
        switch event.keyCode {
        case 123, 0:  // Left arrow or 'a'
            keyboardLeft = false
            handleRotation()
        case 124, 2:  // Right arrow or 'd'
            keyboardRight = false
            handleRotation()
        case 126, 125:  // Up or Down arrow
            thrustDirection = 0
        case 49:      // Spacebar
            isSpaceKeyDown = false  // Reset spacebar state
        default:
            break
        }
    }
    
    private func handleRotation() {
        if keyboardLeft {
            rotationRate = 1.0
        } else if keyboardRight {
            rotationRate = -1.0
        } else {
            rotationRate = 0
        }
    }
    
    override func update(_ currentTime: TimeInterval) {
        // Move rotation update to the start and ensure it always happens
        if let currentPlayer = player, rotationRate != 0 {
            currentPlayer.zRotation += rotationRate * CGFloat(0.05)
        }
        
        // Apply thrust and play sound
        if let currentPlayer = player, thrustDirection != 0 {
            let angle = currentPlayer.zRotation
            let dx = -sin(angle) * shipThrustSpeed * thrustDirection
            let dy = cos(angle) * shipThrustSpeed * thrustDirection
            currentPlayer.physicsBody?.applyForce(CGVector(dx: dx, dy: dy))
            
            // Show thrust visual
            thrustNode?.isHidden = false
            
            // Play thrust sound in spurts
            if action(forKey: "thrustSound") == nil {
                let playSound = SKAction.group([
                    SKAction.changeVolume(to: 0.5, duration: 0),
                    SKAction.playSoundFileNamed("thrust.wav", waitForCompletion: false)
                ])
                run(playSound)
            }
        } else {
            // Hide thrust visual and stop sound when not thrusting
            thrustNode?.isHidden = true
            removeAction(forKey: "thrustSound")
        }
        
        // Update position
        if let currentPlayer = player {
            currentPlayer.position.x += velocity.dx
            currentPlayer.position.y += velocity.dy
        
        // Screen wrapping
            if currentPlayer.position.x > frame.maxX {
                currentPlayer.position.x = frame.minX
            } else if currentPlayer.position.x < frame.minX {
                currentPlayer.position.x = frame.maxX
            }
            
            if currentPlayer.position.y > frame.maxY {
                currentPlayer.position.y = frame.minY
            } else if currentPlayer.position.y < frame.minY {
                currentPlayer.position.y = frame.maxY
            }
        }
        
        // Apply friction
        velocity.dx *= 0.99
        velocity.dy *= 0.99
        
        // Update bullets
        for bullet in bullets {
            if let velocity = bullet.userData?["velocity"] as? CGVector {
                bullet.position.x += velocity.dx
                bullet.position.y += velocity.dy
                
                // Remove bullets that are off screen
                if !frame.contains(bullet.position) {
                    bullet.removeFromParent()
                    if let index = bullets.firstIndex(of: bullet) {
                        bullets.remove(at: index)
                    }
                }
            }
        }
        
        // ONLY bullets can destroy asteroids
        for bullet in bullets {
            for asteroid in asteroids {
                if bullet.frame.intersects(asteroid.frame) {
                    // Remove the bullet
                    bullet.removeFromParent()
                    if let index = bullets.firstIndex(of: bullet) {
                        bullets.remove(at: index)
                    }
                    
                    // Split the asteroid
                    splitAsteroid(asteroid)
                    
                    break // Break inner loop since bullet is now gone
                }
            }
        }
        
        // Update wrapping for all asteroids
        for asteroid in asteroids {
            wrapAsteroid(asteroid)
        }
        
        // Cap velocity for Aster type asteroids
        for asteroid in asteroids {
            if asteroid.fillColor == .black {  // It's an Aster type
                if let physicsBody = asteroid.physicsBody {
                    let velocity = physicsBody.velocity
                    let speed = sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy)
                    
                    if speed > maxAsterVelocity {
                        // Scale down the velocity to max speed while preserving direction
                        let scale = maxAsterVelocity / speed
                        physicsBody.velocity = CGVector(dx: velocity.dx * scale, 
                                                      dy: velocity.dy * scale)
                    }
                }
            }
        }
        
        // Update saucer movement
        if let saucer = activeSaucer, let velocity = saucer.physicsBody?.velocity {
            // Calculate distance traveled since last frame
            let deltaDistance = sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy) * CGFloat(1.0/60.0)
            saucerDistanceTraveled += deltaDistance
            
            // Change direction every 300 pixels
            if saucerDistanceTraveled >= saucerChangeDirectionDistance {
                changeSaucerDirection(saucer)
                saucerDistanceTraveled = 0
            }
        }
        
        // Wrap saucer position
        if let saucer = activeSaucer {
            wrapSaucer(saucer)
        }
        
        // Update beat tempo every frame to catch all asteroid count changes
        updateBeatTempo()
        
        // Wrap player position
        wrapPlayer()
        
        // Handle thrust flames
        if thrustDirection > 0 {
            showThrustFlame()
        } else if thrustDirection < 0 {
            showReverseFlame()
        } else {
            hideThrustFlame()
            hideReverseFlame()
        }
        
        // Apply thrust in direction ship is pointing
        if let currentPlayer = player, thrustDirection != 0 {
            let dx = -sin(currentPlayer.zRotation) * shipThrustSpeed * thrustDirection
            let dy = cos(currentPlayer.zRotation) * shipThrustSpeed * thrustDirection
            currentPlayer.physicsBody?.applyForce(CGVector(dx: dx, dy: dy))
        }
        
        // Wrap player position
        wrapPlayer()
        
        // Check for level completion
        checkLevelCompletion()
    }
    
    // Add these new methods for asteroid splitting
    func splitAsteroid(_ asteroid: SKShapeNode) {
        if let size = asteroid.userData?["size"] as? AsteroidSize {
            switch size {
            case .large:
                run(bangLargeSound)
                score += 5
                createAsteroidImplosion(at: asteroid.position)  // Only implosion for large
                showMessage("5", duration: 1.0)
            case .medium:
                run(bangMediumSound)
                score += 10
                // Both effects for medium
                createAsteroidImplosion(at: asteroid.position)
                createAsteroidExplosion(at: asteroid.position, isMedium: true)
                showMessage("10", duration: 1.0)
            case .small:
                run(bangSmallSound)
                score += 25
                createAsteroidExplosion(at: asteroid.position, isMedium: false)
                showMessage("25", duration: 1.0)
            }
            
            // Update score display
            updateScore()
            
            // Remove the original asteroid
            if let index = asteroids.firstIndex(of: asteroid) {
                asteroids.remove(at: index)
            }
            asteroid.removeFromParent()
            
            // Split into smaller asteroids
            switch size {
            case .large:
                spawnSplitAsteroids(at: asteroid.position, size: .medium, count: 2)
            case .medium:
                spawnSplitAsteroids(at: asteroid.position, size: .small, count: 2)
            case .small:
                return
            }
            
            updateBeatTempo()
        }
    }
    
    func spawnSplitAsteroids(at position: CGPoint, size: AsteroidSize, count: Int) {
        let splitAngles: [CGFloat] = [0, .pi] // Opposite directions
        
        for i in 0..<count {
            let newAsteroid = SKShapeNode(path: createAsteroidPath(radius: size.radius, points: size.points))
            newAsteroid.strokeColor = .white
            newAsteroid.lineWidth = 2.0
            
            // Offset starting positions to prevent overlap
            let offsetDistance = size.radius * 2 // Ensure they start separated
            let offsetAngle = splitAngles[i]
            let startX = position.x + cos(offsetAngle) * offsetDistance
            let startY = position.y + sin(offsetAngle) * offsetDistance
            newAsteroid.position = CGPoint(x: startX, y: startY)
            
            // Initialize userData dictionary
            newAsteroid.userData = NSMutableDictionary()
            newAsteroid.userData?["size"] = size
            
            // Use toggle for exact 50/50 split
            newAsteroid.fillColor = isNextAster ? .black : .clear  // TEMP: Color split asteroids
            
            // Create physics body
            newAsteroid.physicsBody = SKPhysicsBody(edgeLoopFrom: newAsteroid.path!)
            
            if isNextAster {
                // Black filled asteroids that collide with each other
                newAsteroid.physicsBody?.categoryBitMask = asterCategory
                newAsteroid.physicsBody?.contactTestBitMask = shipCategory
                newAsteroid.physicsBody?.collisionBitMask = asterCategory
                newAsteroid.physicsBody?.restitution = 0.8  // Reduced from 1.0
                newAsteroid.physicsBody?.friction = 0.2     // Added friction
                newAsteroid.physicsBody?.linearDamping = 0.1  // Added damping
                newAsteroid.physicsBody?.angularDamping = 0.1 // Added angular damping
                newAsteroid.physicsBody?.mass = 1.0
                newAsteroid.physicsBody?.allowsRotation = true
                
                // Slower initial speed for colliding asteroids
                let speed = CGFloat.random(in: 100...200)  // Reduced from 200...400
                let splitAngle = splitAngles[i] + CGFloat.random(in: -0.5...0.5)
                let velocity = CGVector(dx: cos(splitAngle) * speed, dy: sin(splitAngle) * speed)
                newAsteroid.physicsBody?.velocity = velocity
                
                // Add some initial rotation, but slower
                let rotationSpeed = CGFloat.random(in: -1.0...1.0)  // Reduced rotation speed
                newAsteroid.physicsBody?.angularVelocity = rotationSpeed
                newAsteroid.name = "Newborn Aster"
            } else {
                // Clear filled asteroids that pass through each other
                newAsteroid.physicsBody?.categoryBitMask = roidCategory
                newAsteroid.physicsBody?.contactTestBitMask = shipCategory
                newAsteroid.physicsBody?.collisionBitMask = 0
                
                // Ensure Roids keep moving with constant velocity
                let speed = CGFloat.random(in: 100...200)
                let splitAngle = splitAngles[i] + CGFloat.random(in: -0.5...0.5)
                let velocity = CGVector(dx: cos(splitAngle) * speed, dy: sin(splitAngle) * speed)
                newAsteroid.physicsBody?.velocity = velocity
                newAsteroid.name = "Newborn Roid"

            }
            
            newAsteroid.physicsBody?.affectedByGravity = false
            newAsteroid.physicsBody?.isDynamic = true
            newAsteroid.physicsBody?.usesPreciseCollisionDetection = true
            
            // Toggle for next asteroid
            isNextAster.toggle()
            
            asteroids.append(newAsteroid)
            addChild(newAsteroid)
        }
    }
    
    // Add player death handling
    func playerDied() {
        run(bangMediumSound)
        
        // Stop any existing sounds
        saucerSound?.removeFromParent()
        
        // Create ship destruction animation at current position
        createShipDestructionAnimation()
        
        // Remove the player completely
        if let player {
            player.removeAllActions()  // Remove all actions from the player
            player.removeFromParent()
        }
        // Remove player from parent
        player = nil
        
        if lives <= 1 {
            lives = 0
            isGameOver = true
            showMessage("GAME OVER", duration: 3.0)
        } else {
            lives -= 1
            isRespawning = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.tryRespawn()
            }
        }
    }
    
    func createShipDestructionAnimation() {
        // Create the three lines that make up the ship's shape
        let topLine = SKShapeNode()
        let leftLine = SKShapeNode()
        let rightLine = SKShapeNode()
        
        // Draw the lines
        let topPath = CGMutablePath()
        topPath.move(to: CGPoint(x: 0, y: 20))
        topPath.addLine(to: CGPoint(x: 0, y: 0))
        topLine.path = topPath
        
        let leftPath = CGMutablePath()
        leftPath.move(to: CGPoint(x: 0, y: 0))
        leftPath.addLine(to: CGPoint(x: -15, y: -20))
        leftLine.path = leftPath
        
        let rightPath = CGMutablePath()
        rightPath.move(to: CGPoint(x: 0, y: 0))
        rightPath.addLine(to: CGPoint(x: 15, y: -20))
        rightLine.path = rightPath
        
        // Set line properties
        [topLine, leftLine, rightLine].forEach {
            $0.strokeColor = .white
            $0.lineWidth = 2.0
            
            if let player {
                $0.position = player.position
                $0.zRotation = player.zRotation
            }
           
            addChild($0)
        }
        
        // Animate the pieces
        let duration = 1.0
        let fadeOut = SKAction.fadeOut(withDuration: duration)
        let moveTop = SKAction.moveBy(x: 0, y: 20, duration: duration)
        let moveLeft = SKAction.moveBy(x: -20, y: -20, duration: duration)
        let moveRight = SKAction.moveBy(x: 20, y: -20, duration: duration)
        let spin = SKAction.rotate(byAngle: .pi * 2, duration: duration)
        
        topLine.run(SKAction.group([fadeOut, moveTop, spin]))
        leftLine.run(SKAction.group([fadeOut, moveLeft, spin]))
        rightLine.run(SKAction.group([fadeOut, moveRight, spin]))
        
        // Remove the lines after animation
        let wait = SKAction.wait(forDuration: duration)
        let remove = SKAction.run {
            [topLine, leftLine, rightLine].forEach { $0.removeFromParent() }
        }
        run(SKAction.sequence([wait, remove]))
    }

    
    // Add new respawn methods
    func findSafeSpawnLocation() -> CGPoint? {
        let safeRadius: CGFloat = 100  // Area that needs to be clear
        let attempts = 20  // Maximum attempts to find safe spot
        
        for _ in 0..<attempts {
            // Try random position
            let testPoint = CGPoint(
                x: CGFloat.random(in: safeRadius...(frame.width - safeRadius)),
                y: CGFloat.random(in: safeRadius...(frame.height - safeRadius))
            )
            
            // Check if area is clear of asteroids and saucers
            var areaIsSafe = true
            
            // Check distance to all asteroids
            for asteroid in asteroids {
                let distance = hypot(
                    asteroid.position.x - testPoint.x,
                    asteroid.position.y - testPoint.y
                )
                if distance < safeRadius {
                    areaIsSafe = false
                    break
                }
            }
            
            // Check distance to saucer if one exists
            if let saucer = activeSaucer {
                let distance = hypot(saucer.position.x - testPoint.x,
                                   saucer.position.y - testPoint.y)
                if distance < safeRadius {
                    areaIsSafe = false
                }
            }
            
            if areaIsSafe {
                return testPoint
            }
        }
        
        return nil
    }
    
    func tryRespawn() {
        // Create new player ship if needed
        if player == nil {
            player = createPlayerShip()
        }
        
        let centerPoint = CGPoint(x: frame.midX, y: frame.midY)
        
        // Check if center area is clear
        var areaIsSafe = true
        let safeRadius: CGFloat = 100
        
        // Check distance to all asteroids
        for asteroid in asteroids {
            let distance = hypot(asteroid.position.x - centerPoint.x, 
                               asteroid.position.y - centerPoint.y)
            if distance < safeRadius {
                areaIsSafe = false
                break
            }
        }
        
        // Check distance to saucer if one exists
        if let saucer = activeSaucer {
            let distance = hypot(saucer.position.x - centerPoint.x,
                               saucer.position.y - centerPoint.y)
            if distance < safeRadius {
                areaIsSafe = false
            }
        }
        
        if areaIsSafe {
            // Add player to scene if not already there
            if player?.parent == nil {
                addChild(player!)
            }
            
            // Reset position and physics
            player?.position = centerPoint
            player?.isHidden = false
            player?.alpha = 0.2  // Start faded for throb effect
            player?.physicsBody?.velocity = .zero
            player?.physicsBody?.angularVelocity = 0
            
            // Recreate flame effects
            recreateFlameEffects()
            
            isRespawning = false
            
            // Play thrust sound at 75% volume using SKAction
            let playSound = SKAction.group([
                SKAction.changeVolume(to: 0.5, duration: 0),
                SKAction.playSoundFileNamed("thrust.wav", waitForCompletion: false)
            ])
            run(playSound)
            
            // Add throb effect
            if let currentPlayer = player {
                let throb = SKAction.sequence([
                    SKAction.fadeAlpha(to: 1.0, duration: 0.2),
                    SKAction.fadeAlpha(to: 0.2, duration: 0.2)
                ])
                
                // Create sequence: 3 throbs followed by final fade to full opacity
                let throbSequence = SKAction.sequence([
                    SKAction.repeat(throb, count: 3),
                    SKAction.fadeAlpha(to: 1.0, duration: 0.2)  // Final fade to full opacity
                ])
                
                currentPlayer.run(throbSequence)
            }
            
            // Play thrust sound at 50% volume and reversed
            let thrustSound = SKAudioNode(fileNamed: "thrust.wav")
            thrustSound.autoplayLooped = false
            
            // Set up reversed playback at 50% volume
            let setupSound = SKAction.group([
                SKAction.changeVolume(to: 0.5, duration: 0),
                SKAction.changePlaybackRate(to: -1.0, duration: 0)  // Full reverse
            ])
            
//            let playSoundX = SKAction.sequence([
//                setupSound,
//                SKAction.play()
//            ])
//            
//            thrustSound.run(playSound)
//            addChild(thrustSound)
            
            // Remove sound after throb finishes
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                thrustSound.removeFromParent()
            }
            
            // Add throb effect
//            if let currentPlayer = player {
//                let throb = SKAction.sequence([
//                    SKAction.fadeAlpha(to: 1.0, duration: 0.2),
//                    SKAction.fadeAlpha(to: 0.2, duration: 0.2)
//                ])
//                
//                // Create sequence: 3 throbs followed by final fade to full opacity
//                let throbSequence = SKAction.sequence([
//                    SKAction.repeat(throb, count: 3),
//                    SKAction.fadeAlpha(to: 1.0, duration: 0.2)
//                ])
//                
//                currentPlayer.run(throbSequence)
//            }
        } else {
            // Try again after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.tryRespawn()
            }
        }
    }
    
    func isCenterAreaSafe() -> Bool {
        let centerPoint = CGPoint(x: frame.midX, y: frame.midY)
        
        for asteroid in asteroids {
            let distance = hypot(asteroid.position.x - centerPoint.x,
                               asteroid.position.y - centerPoint.y)
            if distance < respawnSafeRadius {
                return false
            }
        }
        return true
    }
    
    func respawnPlayer() {
        player.position = CGPoint(x: frame.midX, y: frame.midY)
        player.zRotation = 0
        velocity = CGVector(dx: 0, dy: 0)
        player.isHidden = false
        isRespawning = false
        
        // Add invulnerability period
        player.alpha = 0.5
        let blinkAction = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.5, duration: 0.2),
            SKAction.fadeAlpha(to: 1.0, duration: 0.2)
        ])
        let blinkCount = 5
        player.run(SKAction.sequence([
            SKAction.repeat(blinkAction, count: blinkCount),
            SKAction.run { [weak self] in
                self?.player.alpha = 1.0
            }
        ]))
    }
    
    // Add contact delegate method
    func didBegin(_ contact: SKPhysicsContact) {
        let collision = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask
        
        // Log collision details
        print("Collision detected between: \(contact.bodyA.node?.name ?? "Unknown") and \(contact.bodyB.node?.name ?? "Unknown")")
        
        // Add handling for Aster hitting saucer
        if collision == (asterCategory | saucerCategory) {
            // Get the saucer node
            let saucer = (contact.bodyA.categoryBitMask == saucerCategory) ? 
                         contact.bodyA.node as? SKShapeNode : 
                         contact.bodyB.node as? SKShapeNode
            
            // Destroy the saucer
            if let saucer = saucer {
                saucerDestroyed(saucer)
            }
        }
        
        // Handle player bullets hitting targets
        if collision == (bulletCategory | asterCategory) || 
           collision == (bulletCategory | roidCategory) ||
           collision == (bulletCategory | saucerCategory) {
            
            // Determine which node is the bullet and which is the target
            let bullet = contact.bodyA.categoryBitMask == bulletCategory ? contact.bodyA.node : contact.bodyB.node
            let target = contact.bodyA.categoryBitMask == bulletCategory ? contact.bodyB.node : contact.bodyA.node
            
            // Handle destruction
            if let targetNode = target as? SKShapeNode {
                // Check if it's a saucer - just destroy it, scoring happens in saucerDestroyed
                if targetNode.physicsBody?.categoryBitMask == saucerCategory {
                    saucerDestroyed(targetNode)
                }
                // Check if it's an asteroid
                else if let _ = targetNode.userData?["size"] as? AsteroidSize {
                        splitAsteroid(targetNode)
                    }
                }
                
            // Remove the bullet
            bullet?.removeFromParent()
        }
        
        // Handle ship collisions
        if (contact.bodyA.categoryBitMask == shipCategory || 
            contact.bodyB.categoryBitMask == shipCategory) {
            if !isRespawning {
                // Change the fill color of the object that hit the ship to red
                if let nodeA = contact.bodyA.node as? SKShapeNode {
                    //nodeA.fillColor = .red
                }
                if let nodeB = contact.bodyB.node as? SKShapeNode {
                    //nodeB.fillColor = .red
                }
                playerDied()
            }
        }
        
        // Add check for player bullets hitting saucer bullets
        if collision == (bulletCategory | saucerBulletCategory) {
            let bulletPos = contact.bodyA.node?.position ?? contact.bodyB.node?.position ?? .zero
            
            // Remove both bullets
            contact.bodyA.node?.removeFromParent()
            contact.bodyB.node?.removeFromParent()
            
            // Create explosion effect
            createBulletExplosion(at: bulletPos)
            
            // Award points
            score += 100
            
            // Show score message
            showMessage("+100", duration: 1.0)
        }
    }
    
    func restartGame() {
        // Remove game over screen
        gameOverScreen?.removeFromParent()
        gameOverScreen = nil
        
        // Remove game over messages
        for label in gameOverLabels {
            label.removeFromParent()
        }
        gameOverLabels.removeAll()
        
        // Reset game state
        isGameOver = false
        score = 0
        lives = 3
        
        // Try to spawn player
        tryRespawn()
        
        lastExtraShipScore = 0  // Reset extra ship counter
        currentAsteroidSpeed = initialAsteroidSpeed
        
        // Use these instead
        beatInterval = maxBeatInterval
        startBackgroundBeats()
        
        level = 1  // Reset level
        
        saucerSpawnEnabled = true
        scheduleSaucerSpawn()  // Start initial saucer spawn cycle
    }
    
    func startBackgroundBeats() {
        // Stop any existing timer
        beatTimer?.invalidate()
        beatTimer = nil
        
        // Play first beat immediately
        run(beat1)
        currentBeat = 2
        
        // Create new timer that repeats
        let newTimer = Timer.scheduledTimer(withTimeInterval: beatInterval, repeats: true) { [weak self] _ in
            self?.playNextBeat()
        }
        beatTimer = newTimer
        RunLoop.current.add(newTimer, forMode: .common)
    }
    
    func updateBeatTempo() {
        // Base count from asteroids
        var totalCount = asteroids.count
        
        // Add weighted count for active saucer
        if let saucer = activeSaucer {
            // Check saucer size and add appropriate weight
            if saucer.xScale == 1.0 {  // Large saucer
                totalCount += 20  // Counts as 10 additional asteroids
            } else {  // Small saucer
                totalCount += 40  // Counts as 20 additional asteroids
            }
        }
        
        // Update asteroid count label (green) - safely
        asteroidCountLabel?.text = "ASTEROIDS AND SAUCERS \(totalCount)"
        
        let oldInterval = beatInterval
        
        switch totalCount {
        case 0...5:
            beatInterval = 0.2
        case 4...9:
            beatInterval = 0.4
        case 10...14:
            beatInterval = 0.6
        case 15...19:
            beatInterval = 1.0
        case 20...24:
            beatInterval = 0.6
        case 25...29:
            beatInterval = 0.4
        case 30...:
            beatInterval = 0.2
        default:
            beatInterval = 1.0
        }
        
        // Update beat interval label (blue) - safely
        beatIntervalLabel?.text = "BEAT INTERVAL \(String(format: "%.2f", beatInterval))"
        
        // Show interval changed message (red) - safely
        if oldInterval != beatInterval {
            intervalChangedLabel?.text = "INTERVAL CHANGED"
            // Clear the message after 1 second
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.intervalChangedLabel?.text = ""
            }
            
            // Update timer if interval changed - FIXED TIMER CREATION
            beatTimer?.invalidate()
            let newTimer = Timer.scheduledTimer(withTimeInterval: beatInterval, repeats: true) { [weak self] _ in
                self?.playNextBeat()
            }
            beatTimer = newTimer
            RunLoop.current.add(newTimer, forMode: .common)
        }
        
        // Add this at the end
        updateSaucerSpawnRate()
    }
    
    func playNextBeat() {
        if currentBeat == 1 {
            run(beat1)
            currentBeat = 2
        } else {
            run(beat2)
            currentBeat = 1
        }
    }
    
    // Update screen wrapping in update method
    func wrapAsteroid(_ asteroid: SKShapeNode) {
        // Simple screen wrapping - when object goes off one edge, place it on the opposite edge
        if asteroid.position.x < -asteroid.frame.width {
            asteroid.position.x = frame.maxX + asteroid.frame.width/2
        } else if asteroid.position.x > frame.maxX + asteroid.frame.width {
            asteroid.position.x = -asteroid.frame.width/2
        }
        
        if asteroid.position.y < -asteroid.frame.height {
            asteroid.position.y = frame.maxY + asteroid.frame.height/2
        } else if asteroid.position.y > frame.maxY + asteroid.frame.height {
            asteroid.position.y = -asteroid.frame.height/2
        }
    }
    
    func createOrUpdateWrapper(for asteroid: SKShapeNode, at position: CGPoint) {
        if let existingWrapper = wrappedSprites[asteroid] {
            // Update existing wrapper position
            existingWrapper.position = position
            existingWrapper.zRotation = asteroid.zRotation
        } else {
            // Create new wrapper
            let wrapper = asteroid.copy() as! SKShapeNode
            wrapper.position = position
            addChild(wrapper)
            wrappedSprites[asteroid] = wrapper
        }
    }
    
    // Clean up wrappers when removing asteroids
    func removeAsteroid(_ asteroid: SKShapeNode) {
        if let wrapper = wrappedSprites[asteroid] {
            wrapper.removeFromParent()
            wrappedSprites.removeValue(forKey: asteroid)
        }
        asteroid.removeFromParent()
    }
    
    func awardExtraShip() {
        lives += 1
        run(extraShipSound)
        showMessage("EXTRA SHIP", duration: 2.0)
    }
    
    func decideSaucerSize() -> SaucerSize {
        return Bool.random() ? .large : .small  // Simpler 50/50
    }
    
    func spawnSaucer(forcedSize: SaucerSize? = nil) {
        guard activeSaucer == nil, saucerSpawnEnabled else { return }
        
        let size = forcedSize ?? decideSaucerSize()
        let saucer = createSaucer(size: size)
        
        // Random edge spawn
        let side = Int.random(in: 0...1)
        saucer.position = CGPoint(x: side == 0 ? -50 : frame.maxX + 50,
                                y: CGFloat.random(in: 100...frame.maxY-100))
        
        // Reset distance tracker for new saucer
        saucerDistanceTraveled = 0
        
        // Initial movement
        let speed: CGFloat = size == .large ? 100 : 150
        let direction: CGFloat = side == 0 ? 1 : -1
        let angle = CGFloat.random(in: -CGFloat.pi/4...CGFloat.pi/4)
        let dx = cos(angle) * speed * direction
        let dy = sin(angle) * speed
        saucer.physicsBody?.velocity = CGVector(dx: dx, dy: dy)
        
        // Setup repeating sound based on size with 50% volume
        if size == .large {
            let audioNode = SKAudioNode(fileNamed: "saucerBig.wav")
            audioNode.autoplayLooped = true
            saucer.addChild(audioNode)
            audioNode.run(SKAction.changeVolume(to: 0.5, duration: 0))
        } else {
            let audioNode = SKAudioNode(fileNamed: "saucerSmall.wav")
            audioNode.autoplayLooped = true
            saucer.addChild(audioNode)
            audioNode.run(SKAction.changeVolume(to: 0.5, duration: 0))
        }
        
        activeSaucer = saucer
        addChild(saucer)
        
        // Remove after 15 seconds with proper cleanup
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            if self?.activeSaucer != nil {
                self?.removeSaucer()
            }
        }
        
        // Start shooting immediately for both sizes
        startSaucerShooting(size: size)
    }
    
    func startSaucerShooting(size: SaucerSize) {
        // Clear any existing timer
        saucerShootTimer?.invalidate()
        saucerShootTimer = nil
        
        // Set shooting interval based on size
        let interval = size == .large ? 1.5 : 0.8  // Large shoots slower but more accurately
        
        saucerShootTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.saucerShoot(isLarge: size == .large)
        }
    }
    
    func saucerShoot(isLarge: Bool) {
        guard let saucer = activeSaucer else { return }
        
        // Create bullet
        let bullet = SKShapeNode(circleOfRadius: 2.0)
        bullet.strokeColor = .white
        bullet.fillColor = .white
        bullet.position = saucer.position
        
        // Direction calculation
        let angle: CGFloat
        if isLarge {
            // Large saucer: 50% chance to aim at player, 50% chance random
            if Bool.random() && player != nil {
                let playerPos = player.position
                let dx = playerPos.x - saucer.position.x
                let dy = playerPos.y - saucer.position.y
                angle = atan2(dy, dx) + CGFloat.random(in: -0.5...0.5) // Add some randomness
            } else {
                angle = CGFloat.random(in: 0...(2 * .pi))
            }
        } else {
            // Small saucer: Completely random
            angle = CGFloat.random(in: 0...(2 * .pi))
        }
        
        let bulletSpeed: CGFloat = 300.0
        
        // Add physics
        bullet.physicsBody = SKPhysicsBody(circleOfRadius: 2.0)
        bullet.physicsBody?.categoryBitMask = saucerBulletCategory
        bullet.physicsBody?.collisionBitMask = 0  // Don't collide with anything
        bullet.physicsBody?.contactTestBitMask = shipCategory | allAsteroidsCategory  // Add asteroid detection
        bullet.physicsBody?.affectedByGravity = false
        bullet.name = "SaucerBullet"
        // Set velocity
        bullet.physicsBody?.velocity = CGVector(dx: cos(angle) * bulletSpeed,
                                          dy: sin(angle) * bulletSpeed)
        
        addChild(bullet)
        
        // Remove bullet when it goes off screen
        let removeWhenOffscreen = SKAction.repeatForever(SKAction.sequence([
            SKAction.wait(forDuration: 0.1),
            SKAction.run { [weak self] in
                guard let self = self else { return }
                if !self.frame.contains(bullet.position) {
                    bullet.removeFromParent()
                }
            }
        ]))
        bullet.run(removeWhenOffscreen)
    }
    
    func removeSaucer() {
        // Stop shooting
        saucerShootTimer?.invalidate()
        saucerShootTimer = nil
        
        if let saucer = activeSaucer {
            saucerDestroyed(saucer)  // Use new destruction effect
        }
    }
    
    func saucerDestroyed(_ saucer: SKShapeNode) {
        // Stop sound first
        saucerSound?.removeFromParent()
        saucerSound = nil
        
        // Award points when saucer is actually destroyed
        let isLarge = saucer.xScale == 1.0
        score += isLarge ? 50 : 75
        updateScore()
        
        // Show score without "+"
        let scoreText = "\(isLarge ? 50 : 75)"
        showMessage(scoreText, duration: 1.0)
        
        // Determine size and play appropriate explosion sound
        run(isLarge ? bangLargeSound : bangSmallSound)
        
        // Create explosion debris
        let numPieces = isLarge ? 8 : 6
        let saucerLines = createSaucerDebris(at: saucer.position, numPieces: numPieces)
        
        // Add and animate each piece
        for line in saucerLines {
            addChild(line)
            
            // Random direction and speed
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 50...150)
            let dx = cos(angle) * speed
            let dy = sin(angle) * speed
            
            // Movement and fade sequence
            let move = SKAction.move(by: CGVector(dx: dx, dy: dy), duration: 1.0)
            let fade = SKAction.fadeOut(withDuration: 1.0)
            let group = SKAction.group([move, fade])
            let remove = SKAction.removeFromParent()
            
            line.run(SKAction.sequence([group, remove]))
        }
        
        // Remove the saucer
        saucer.removeFromParent()
        activeSaucer = nil
        
        // Schedule next saucer spawn immediately after destruction
        if saucerSpawnEnabled {
            scheduleSaucerSpawn()
        }
    }
    
    func createSaucerDebris(at position: CGPoint, numPieces: Int) -> [SKShapeNode] {
        var debris: [SKShapeNode] = []
        
        // Create line segments that look like pieces of the saucer
        let pieceLength = CGFloat.random(in: 5...15)
        
        for _ in 0..<numPieces {
            let line = SKShapeNode()
            let path = CGMutablePath()
            
            // Random line segment
            let startX = CGFloat.random(in: -5...5)
            let startY = CGFloat.random(in: -5...5)
            path.move(to: CGPoint(x: startX, y: startY))
            path.addLine(to: CGPoint(x: startX + pieceLength, y: startY + CGFloat.random(in: -5...5)))
            
            line.path = path
            line.strokeColor = .white
            line.lineWidth = 1.0
            line.position = position
            
            debris.append(line)
        }
        
        return debris
    }
    
    func changeSaucerDirection(_ saucer: SKShapeNode) {
        let isLarge = saucer.xScale == 1.0
        let speed: CGFloat = isLarge ? 100 : 150
        
        // Random angle between -45 and 45 degrees (keep somewhat horizontal)
        let angle = CGFloat.random(in: -CGFloat.pi/4...CGFloat.pi/4)
        
        // If saucer is on the right side of screen, bias movement left
        // If saucer is on the left side of screen, bias movement right
        let horizontalBias: CGFloat
        if saucer.position.x > frame.width/2 {
            horizontalBias = -1
        } else {
            horizontalBias = 1
        }
        
        // Calculate new velocity
        let dx = cos(angle) * speed * horizontalBias
        let dy = sin(angle) * speed
        
        saucer.physicsBody?.velocity = CGVector(dx: dx, dy: dy)
    }
    
    func wrapSaucer(_ saucer: SKShapeNode) {
        let size = saucer.frame.size
        let position = saucer.position
        
        // Wrap horizontally
        if position.x < -size.width/2 {
            saucer.position.x = frame.maxX + size.width/2
        } else if position.x > frame.maxX + size.width/2 {
            saucer.position.x = -size.width/2
        }
        
        // Wrap vertically
        if position.y < -size.height/2 {
            saucer.position.y = frame.maxY + size.height/2
        } else if position.y > frame.maxY + size.height {
            saucer.position.y = -size.height/2
        }
    }
    
    func showThrustFlame() {
        // Reset alpha and show flame
        thrustNode?.alpha = 1.0
        thrustNode?.isHidden = false
        
        // Animate the thrust flame
        let flicker = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.3, duration: 0.1),
            SKAction.fadeAlpha(to: 1.0, duration: 0.1)
        ])
        
        thrustNode?.run(SKAction.repeatForever(flicker))
    }
    
    func hideThrustFlame() {
        thrustNode?.removeAllActions()
        thrustNode?.isHidden = true
    }
    
    func showReverseFlame() {
        // Reset alpha and show flames
        thrustNode?.alpha = 1.0
        reverseFlameNode?.alpha = 1.0
        thrustNode?.isHidden = false
        reverseFlameNode?.isHidden = false
        
        // Animate both flames
        let flicker = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.3, duration: 0.1),
            SKAction.fadeAlpha(to: 1.0, duration: 0.1)
        ])
        
        thrustNode?.run(SKAction.repeatForever(flicker))
        reverseFlameNode?.run(SKAction.repeatForever(flicker))
    }
    
    func hideReverseFlame() {
        reverseFlameNode?.removeAllActions()
        reverseFlameNode?.isHidden = true
    }
    
    // Add this helper function
    func showMessage(_ text: String, duration: TimeInterval = 2.0) {
        if text.contains("GAME OVER") {
            showGameOverScreen()
        } else if text.contains("EXTRA") {
            // Create vector text for EXTRA LIVES
            let messageNode = drawVectorLetter(text, at: CGPoint(x: frame.maxX - 100, y: 50))
            messageNode.alpha = 1.0  
            addChild(messageNode)
            
            // Animate and remove
            let wait = SKAction.wait(forDuration: duration)
            let fade = SKAction.fadeOut(withDuration: 0.3)
            let remove = SKAction.removeFromParent()
            messageNode.run(SKAction.sequence([wait, fade, remove]))
        }
    }
    
    // Add function to toggle debug info
    func toggleDebugInfo() {
        showDebugInfo.toggle()
        asteroidCountLabel?.isHidden = !showDebugInfo
        beatIntervalLabel?.isHidden = !showDebugInfo
        intervalChangedLabel?.isHidden = !showDebugInfo
    }
    
    // Add bullet explosion effect
    func createBulletExplosion(at position: CGPoint) {
        // Create multiple particles
        for _ in 0...5 {
            let particle = SKShapeNode(circleOfRadius: 1.0)
            particle.position = position
            particle.strokeColor = .white
            particle.fillColor = .white
            addChild(particle)
            
            // Random direction explosion
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 50...100)
            let dx = cos(angle) * speed
            let dy = sin(angle) * speed
            
            // Animate explosion
            let move = SKAction.move(by: CGVector(dx: dx, dy: dy), duration: 0.5)
            let fade = SKAction.fadeOut(withDuration: 0.5)
            let group = SKAction.group([move, fade])
            let remove = SKAction.removeFromParent()
            
            particle.run(SKAction.sequence([group, remove]))
        }
    }
    
    func updateSaucerSpawnRate() {
        // Count small asteroids
        let smallAsteroidCount = asteroids.filter { asteroid in
            if let size = asteroid.userData?["size"] as? AsteroidSize {
                return size == .small
            }
            return false
        }.count
        
        // Calculate new interval with 50% faster spawns
        var newInterval = baseSaucerInterval
        
        // Reduce interval based on small asteroid count (50% faster than before)
        switch smallAsteroidCount {
        case 0...4:
            newInterval = baseSaucerInterval * 0.5       // 10 seconds (was 20)
        case 5...9:
            newInterval = baseSaucerInterval * 0.4       // 8 seconds (was 16)
        case 10...14:
            newInterval = baseSaucerInterval * 0.3       // 6 seconds (was 12)
        case 15...19:
            newInterval = baseSaucerInterval * 0.2       // 4 seconds (was 8)
        default:
            newInterval = minSaucerInterval * 0.5        // 2.5 seconds (was 5)
        }
        
        // Update timer if it exists
        if let currentTimer = saucerTimer {
            currentTimer.invalidate()
            saucerTimer = Timer.scheduledTimer(withTimeInterval: newInterval, repeats: true) { [weak self] _ in
                self?.spawnSaucer()
            }
        }
    }
    
    // Add new explosion effect for asteroids
    func createAsteroidExplosion(at position: CGPoint, isMedium: Bool = false) {
        // Adjust particle count and parameters based on size
        let particleCount = isMedium ? 6 : 8  // Keep same particle counts
        let particleRadius: CGFloat = isMedium ? 1.0 : 0.5625  // 50% larger than before (0.375 * 1.5)
        let speedRange: ClosedRange<CGFloat> = isMedium ? 50.0...150.0 : 37.5...75.0  // 50% faster (25...50 * 1.5)
        
        for _ in 0...particleCount {
            let particle = SKShapeNode(circleOfRadius: particleRadius)
            particle.position = position
            particle.strokeColor = .white
            particle.fillColor = .white
            addChild(particle)
            
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: speedRange)
            let dx = cos(angle) * speed
            let dy = sin(angle) * speed
            
            let duration = isMedium ? 0.5 : 0.7  // Keep same duration
            let move = SKAction.move(by: CGVector(dx: dx, dy: dy), duration: duration)
            let fade = SKAction.fadeOut(withDuration: duration)
            let group = SKAction.group([move, fade])
            let remove = SKAction.removeFromParent()
            
            particle.run(SKAction.sequence([group, remove]))
        }
    }
    
    // Add new implosion effect
    func createAsteroidImplosion(at position: CGPoint) {
        let particleCount = 12  // More particles for implosion
        
        for _ in 0...particleCount {
            let particle = SKShapeNode(circleOfRadius: 1.0)
            particle.position = CGPoint(
                x: position.x + CGFloat.random(in: -40...40),
                y: position.y + CGFloat.random(in: -40...40)
            )
            particle.strokeColor = .white
            particle.fillColor = .white
            addChild(particle)
            
            let move = SKAction.move(to: position, duration: 0.3)  // Quick implosion
            let fade = SKAction.fadeOut(withDuration: 0.3)
            let group = SKAction.group([move, fade])
            let remove = SKAction.removeFromParent()
            
            particle.run(SKAction.sequence([group, remove]))
        }
    }
    
    // Update score display
    private func updateScore() {
        // Remove existing score nodes
        children.filter { $0.name == "scoreNode" }.forEach { $0.removeFromParent() }
        
        // Draw score
        let scoreNode = drawVectorNumber(score, at: CGPoint(x: size.width * 0.1, y: size.height * 0.95))
        scoreNode.name = "scoreNode"
        addChild(scoreNode)
    }
    
    private func updateHighScore() {
        // Remove existing high score nodes
        children.filter { $0.name == "highScoreNode" }.forEach { $0.removeFromParent() }
        
        // Draw high score
        let highScoreNode = drawVectorNumber(highScore, at: CGPoint(x: size.width * 0.5, y: size.height * 0.95))
        highScoreNode.name = "highScoreNode"
        addChild(highScoreNode)
    }
    
    private func createLivesShip(at pos: CGPoint) -> SKNode {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 12.5))    // Top point
        path.addLine(to: CGPoint(x: -7.5, y: -12.5)) // Bottom left
        path.addLine(to: CGPoint(x: 7.5, y: -12.5))  // Bottom right
        path.closeSubpath()
        
        let shipShape = SKShapeNode(path: path)
        shipShape.strokeColor = .white
        shipShape.lineWidth = 2.0
        shipShape.position = pos
        return shipShape
    }

    private func updateLives() {
        // Remove existing lives nodes
        livesNodes.forEach { $0.removeFromParent() }
        livesNodes.removeAll()
        
        // Create lives container at top right
        let livesContainer = SKNode()
        livesContainer.position = CGPoint(x: frame.width - 50, y: frame.height - 50)
        
        // Create ship icons for each life
        let shipSpacing: CGFloat = 20 // Reduced by 50%
        for i in 0..<lives {
            let shipNode = createLivesShip(at: CGPoint(x: -CGFloat(i) * shipSpacing, y: 0))
            livesNodes.append(shipNode as! SKShapeNode)
            livesContainer.addChild(shipNode)
        }
        
        addChild(livesContainer)
    }
    
    func wrapPlayer() {
        guard let currentPlayer = player else { return }
        
        // Wrap horizontally
        if currentPlayer.position.x < 0 {
            currentPlayer.position.x = frame.maxX
        } else if currentPlayer.position.x > frame.maxX {
            currentPlayer.position.x = 0
        }
        
        // Wrap vertically
        if currentPlayer.position.y < 0 {
            currentPlayer.position.y = frame.maxY
        } else if currentPlayer.position.y > frame.maxY {
            currentPlayer.position.y = 0
        }
    }
    
    func recreateFlameEffects() {
        // Remove old flames if they exist
        if let thrust = thrustNode {
            thrust.removeFromParent()
        }
        reverseFlameNode?.removeFromParent()
        
        // Recreate forward thrust flame
        let thrustPath = CGMutablePath()
        thrustPath.move(to: CGPoint(x: -8, y: -20))
        thrustPath.addLine(to: CGPoint(x: 0, y: -30))
        thrustPath.addLine(to: CGPoint(x: 8, y: -20))
        
        thrustNode = SKShapeNode(path: thrustPath)
        thrustNode?.strokeColor = .white
        thrustNode?.lineWidth = 2.0
        thrustNode?.fillColor = .clear
        thrustNode?.isHidden = true
        player.addChild(thrustNode!)
        
        // Recreate reverse thrust flame
        let reverseThrustPath = CGMutablePath()
        reverseThrustPath.move(to: CGPoint(x: -8, y: 20))
        reverseThrustPath.addLine(to: CGPoint(x: 0, y: 30))
        reverseThrustPath.addLine(to: CGPoint(x: 8, y: 20))
        
        reverseFlameNode = SKShapeNode(path: reverseThrustPath)
        reverseFlameNode?.strokeColor = .white
        reverseFlameNode?.lineWidth = 2.0
        reverseFlameNode?.fillColor = .clear
        reverseFlameNode?.isHidden = true
        player.addChild(reverseFlameNode!)
    }
    
    // Add new function to check for level completion
    func checkLevelCompletion() {
        if asteroids.isEmpty {
            startNextLevel()
        }
    }
    
    // Add new function to start next level
    func startNextLevel() {
        level += 1
        
        // Hide player temporarily
        player.isHidden = true
        
        // Show level message
        showMessage("LEVEL \(level)", duration: 2.0)
        
        // Update level display
        updateLevel()
        
        // Spawn new asteroids (level + 9 asteroids)
        for _ in 0..<(level + 9) {
            spawnAsteroid(size: .large)
        }
        
        // Try to respawn player safely
        tryRespawn()
    }
    
    func showTitleScreen() {
        // Create container for all title lines
        titleScreen = SKShapeNode()
        
        // Create container specifically for ASTEROIDZ title
        let asteroidzContainer = SKShapeNode()
        
        // ASTEROIDZ title letters - adjusted positions to center
        let titleLetters: [(path: CGMutablePath, position: CGPoint)] = [
            createLetterA(at: CGPoint(x: -350, y: 100)),  // Moved left
            createLetterS(at: CGPoint(x: -250, y: 100)),
            createLetterT(at: CGPoint(x: -150, y: 100)),
            createLetterE(at: CGPoint(x: -50, y: 100)),
            createLetterR(at: CGPoint(x: 50, y: 100)),
            createLetterO(at: CGPoint(x: 150, y: 100)),
            createLetterI(at: CGPoint(x: 225, y: 100)),
            createLetterD(at: CGPoint(x: 300, y: 100)),
            createLetterZ(at: CGPoint(x: 400, y: 100))
        ]
        
        // Add ASTEROIDZ letters to its container
        for (path, position) in titleLetters {
            let letter = SKShapeNode(path: path)
            letter.strokeColor = .white
            letter.lineWidth = 2.0
            letter.position = position
            asteroidzContainer.addChild(letter)
        }
        // Add ASTEROIDZ container to title screen
        titleScreen?.addChild(asteroidzContainer)
        
        // Add INSERT COIN letters - adjusted positions to center
        let insertLetters: [(path: CGMutablePath, position: CGPoint)] = [
            createLetterI(at: CGPoint(x: -225, y: -50)),
            createLetterN(at: CGPoint(x: -175, y: -50)),
            createLetterS(at: CGPoint(x: -125, y: -50)),
            createLetterE(at: CGPoint(x: -75, y: -50)),
            createLetterR(at: CGPoint(x: -25, y: -50)),
            createLetterT(at: CGPoint(x: 25, y: -50)),
            createLetterC(at: CGPoint(x: 100, y: -50)),
            createLetterO(at: CGPoint(x: 150, y: -50)),
            createLetterI(at: CGPoint(x: 200, y: -50)),
            createLetterN(at: CGPoint(x: 250, y: -50))
        ]
        
        for (path, position) in insertLetters {
            let letter = SKShapeNode(path: path)
            letter.strokeColor = .white
            letter.lineWidth = 2.0
            letter.position = position
            letter.setScale(0.5)  // 50% size
            titleScreen?.addChild(letter)
        }
        
        // Position title screen at exact center of frame
        titleScreen?.position = CGPoint(x: frame.midX, y: frame.midY)
        addChild(titleScreen!)
        
        // Glow animation for ASTEROIDZ only
        let glow = SKAction.sequence([
            SKAction.customAction(withDuration: 4.0) { node, time in
                let progress = time / 2.0
                let alpha = 0.775 + sin(progress * .pi * 2) * 0.075  // Oscillates between 0.7 and 0.85
                node.alpha = alpha
            }
        ])
        
        // Apply glow to ASTEROIDZ container only
        asteroidzContainer.run(SKAction.repeatForever(glow))
        
        // Blink effect for INSERT COIN letters only
        let blink = SKAction.sequence([
            SKAction.wait(forDuration: 0.5),
            SKAction.run { [weak self] in
                self?.titleScreen?.children.forEach { node in
                    if node.position.y < 0 {  // Only affect INSERT COIN letters
                        node.isHidden.toggle()
                    }
                }
            }
        ])
        
        titleScreen?.run(SKAction.repeatForever(blink))
        
        // Wait for spacebar
        isGameOver = true
    }
    
    // Helper functions to create letter paths
    private func createLetterA(at pos: CGPoint) -> (CGMutablePath, CGPoint) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 50))
        path.addLine(to: CGPoint(x: -25, y: -50))
        path.move(to: CGPoint(x: 0, y: 50))
        path.addLine(to: CGPoint(x: 25, y: -50))
        path.move(to: CGPoint(x: -15, y: 0))
        path.addLine(to: CGPoint(x: 15, y: 0))
        return (path, pos)
    }
    
    private func createLetterS(at pos: CGPoint) -> (CGMutablePath, CGPoint) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 25, y: 50))
        path.addLine(to: CGPoint(x: -25, y: 50))
        path.addLine(to: CGPoint(x: -25, y: 0))
        path.addLine(to: CGPoint(x: 25, y: 0))
        path.addLine(to: CGPoint(x: 25, y: -50))
        path.addLine(to: CGPoint(x: -25, y: -50))
        return (path, pos)
    }
    
    private func createLetterT(at pos: CGPoint) -> (CGMutablePath, CGPoint) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -25, y: 50))
        path.addLine(to: CGPoint(x: 25, y: 50))
        path.move(to: CGPoint(x: 0, y: 50))
        path.addLine(to: CGPoint(x: 0, y: -50))
        return (path, pos)
    }
    
    private func createLetterE(at pos: CGPoint) -> (CGMutablePath, CGPoint) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 25, y: 50))
        path.addLine(to: CGPoint(x: -25, y: 50))
        path.move(to: CGPoint(x: -25, y: 50))
        path.addLine(to: CGPoint(x: -25, y: -50))
        path.addLine(to: CGPoint(x: 25, y: -50))
        path.move(to: CGPoint(x: -25, y: 0))
        path.addLine(to: CGPoint(x: 15, y: 0))
        return (path, pos)
    }
    
    private func createLetterR(at pos: CGPoint) -> (CGMutablePath, CGPoint) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -25, y: -50))
        path.addLine(to: CGPoint(x: -25, y: 50))
        path.addLine(to: CGPoint(x: 25, y: 50))
        path.addLine(to: CGPoint(x: 25, y: 0))
        path.addLine(to: CGPoint(x: -25, y: 0))
        path.move(to: CGPoint(x: -10, y: 0))
        path.addLine(to: CGPoint(x: 25, y: -50))
        return (path, pos)
    }
    
    private func createLetterO(at pos: CGPoint) -> (CGMutablePath, CGPoint) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -25, y: 50))
        path.addLine(to: CGPoint(x: 25, y: 50))
        path.addLine(to: CGPoint(x: 25, y: -50))
        path.addLine(to: CGPoint(x: -25, y: -50))
        path.addLine(to: CGPoint(x: -25, y: 50))
        return (path, pos)
    }
    
    private func createLetterI(at pos: CGPoint) -> (CGMutablePath, CGPoint) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 50))
        path.addLine(to: CGPoint(x: 0, y: -50))
        return (path, pos)
    }
    
    private func createLetterD(at pos: CGPoint) -> (CGMutablePath, CGPoint) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -25, y: -50))
        path.addLine(to: CGPoint(x: -25, y: 50))
        path.addLine(to: CGPoint(x: 15, y: 50))
        path.addLine(to: CGPoint(x: 25, y: 25))
        path.addLine(to: CGPoint(x: 25, y: -25))
        path.addLine(to: CGPoint(x: 15, y: -50))
        path.addLine(to: CGPoint(x: -25, y: -50))
        return (path, pos)
    }
    
    private func createLetterZ(at pos: CGPoint) -> (CGMutablePath, CGPoint) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -25, y: 50))
        path.addLine(to: CGPoint(x: 25, y: 50))
        path.addLine(to: CGPoint(x: -25, y: -50))
        path.addLine(to: CGPoint(x: 25, y: -50))
        return (path, pos)
    }
    
    private func createLetterH(at pos: CGPoint) -> (CGMutablePath, CGPoint) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -25, y: 50))
        path.addLine(to: CGPoint(x: -25, y: -50))
        path.move(to: CGPoint(x: 25, y: 50))
        path.addLine(to: CGPoint(x: 25, y: -50))
        path.move(to: CGPoint(x: -25, y: 0))
        path.addLine(to: CGPoint(x: 25, y: 0))
        return (path, pos)
    }
    
    private func createLetterG(at pos: CGPoint) -> (CGMutablePath, CGPoint) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 25, y: 50))
        path.addLine(to: CGPoint(x: -25, y: 50))
        path.addLine(to: CGPoint(x: -25, y: -50))
        path.addLine(to: CGPoint(x: 25, y: -50))
        path.addLine(to: CGPoint(x: 25, y: 0))
        path.addLine(to: CGPoint(x: 0, y: 0))
        return (path, pos)
    }
        
    private func createLetterC(at pos: CGPoint) -> (CGMutablePath, CGPoint) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 25, y: 50))
        path.addLine(to: CGPoint(x: -25, y: 50))
        path.addLine(to: CGPoint(x: -25, y: -50))
        path.addLine(to: CGPoint(x: 25, y: -50))
        return (path, pos)
    }
    
    private func createLetterM(at pos: CGPoint) -> (CGMutablePath, CGPoint) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -25, y: -50))
        path.addLine(to: CGPoint(x: -25, y: 50))
        path.addLine(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 25, y: 50))
        path.addLine(to: CGPoint(x: 25, y: -50))
        return (path, pos)
    }
    
    private func createLetterV(at pos: CGPoint) -> (CGMutablePath, CGPoint) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -25, y: 50))
        path.addLine(to: CGPoint(x: 0, y: -50))
        path.addLine(to: CGPoint(x: 25, y: 50))
        return (path, pos)
    }
    
    private func createLetterN(at pos: CGPoint) -> (CGMutablePath, CGPoint) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -25, y: -50))
        path.addLine(to: CGPoint(x: -25, y: 50))
        path.addLine(to: CGPoint(x: 25, y: -50))
        path.addLine(to: CGPoint(x: 25, y: 50))
        return (path, pos)
    }
    
    // In spawnSaucer function or where saucer timing is handled
    func scheduleSaucerSpawn() {
        // Cancel any existing spawn
        removeAction(forKey: "spawnSaucer")
        
        // Calculate spawn interval based on number of asteroids
        let asteroidCount = asteroids.count
        let maxAsteroids: CGFloat = 10.0  // Expected maximum number of asteroids
        
        // Ensure interval multiplier is valid
        let intervalMultiplier = max(0.3, CGFloat(asteroidCount) / maxAsteroids)
        let maxInterval = maxSaucerInterval * intervalMultiplier
        
        // Ensure range is valid (min must be less than max)
        let adjustedInterval = TimeInterval.random(
            in: min(minSaucerInterval, maxInterval)...maxInterval
        )
        
        let waitAction = SKAction.wait(forDuration: adjustedInterval)
        let spawnAction = SKAction.run { [weak self] in
            self?.spawnSaucer()
            self?.scheduleSaucerSpawn()  // Schedule next spawn
        }
        
        run(SKAction.sequence([waitAction, spawnAction]), withKey: "spawnSaucer")
    }

    private func createLetterB(at pos: CGPoint) -> (CGMutablePath, CGPoint) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -25, y: 50))
        path.addLine(to: CGPoint(x: 0, y: 50))
        path.addLine(to: CGPoint(x: 25, y: 25))
        path.addLine(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 25, y: -25))
        path.addLine(to: CGPoint(x: 0, y: -50))
        path.addLine(to: CGPoint(x: -25, y: -50))
        path.addLine(to: CGPoint(x: -25, y: 50))
        return (path, pos)
    }

    private func createLetterF(at pos: CGPoint) -> (CGMutablePath, CGPoint) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -25, y: 50))
        path.addLine(to: CGPoint(x: 25, y: 50))
        path.move(to: CGPoint(x: -25, y: 0))
        path.addLine(to: CGPoint(x: 15, y: 0))
        path.move(to: CGPoint(x: -25, y: 50))
        path.addLine(to: CGPoint(x: -25, y: -50))
        return (path, pos)
    }

    private func createLetterJ(at pos: CGPoint) -> (CGMutablePath, CGPoint) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 25, y: 50))
        path.addLine(to: CGPoint(x: 25, y: -25))
        path.addLine(to: CGPoint(x: 0, y: -50))
        path.addLine(to: CGPoint(x: -25, y: -25))
        return (path, pos)
    }

    private func createLetterK(at pos: CGPoint) -> (CGMutablePath, CGPoint) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -25, y: 50))
        path.addLine(to: CGPoint(x: -25, y: -50))
        path.move(to: CGPoint(x: 25, y: 50))
        path.addLine(to: CGPoint(x: -25, y: 0))
        path.addLine(to: CGPoint(x: 25, y: -50))
        return (path, pos)
    }

    private func createLetterL(at pos: CGPoint) -> (CGMutablePath, CGPoint) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -25, y: 50))
        path.addLine(to: CGPoint(x: -25, y: -50))
        path.addLine(to: CGPoint(x: 25, y: -50))
        return (path, pos)
    }

    private func createLetterP(at pos: CGPoint) -> (CGMutablePath, CGPoint) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -25, y: -50))
        path.addLine(to: CGPoint(x: -25, y: 50))
        path.addLine(to: CGPoint(x: 25, y: 50))
        path.addLine(to: CGPoint(x: 25, y: 0))
        path.addLine(to: CGPoint(x: -25, y: 0))
        return (path, pos)
    }

    private func createLetterQ(at pos: CGPoint) -> (CGMutablePath, CGPoint) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -25, y: 50))
        path.addLine(to: CGPoint(x: 25, y: 50))
        path.addLine(to: CGPoint(x: 25, y: -50))
        path.addLine(to: CGPoint(x: -25, y: -50))
        path.addLine(to: CGPoint(x: -25, y: 50))
        path.move(to: CGPoint(x: 0, y: -25))
        path.addLine(to: CGPoint(x: 25, y: -50))
        return (path, pos)
    }

    private func createLetterU(at pos: CGPoint) -> (CGMutablePath, CGPoint) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -25, y: 50))
        path.addLine(to: CGPoint(x: -25, y: -50))
        path.addLine(to: CGPoint(x: 25, y: -50))
        path.addLine(to: CGPoint(x: 25, y: 50))
        return (path, pos)
    }

    private func createLetterW(at pos: CGPoint) -> (CGMutablePath, CGPoint) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -25, y: 50))
        path.addLine(to: CGPoint(x: -15, y: -50))
        path.addLine(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 15, y: -50))
        path.addLine(to: CGPoint(x: 25, y: 50))
        return (path, pos)
    }

    private func createLetterX(at pos: CGPoint) -> (CGMutablePath, CGPoint) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -25, y: 50))
        path.addLine(to: CGPoint(x: 25, y: -50))
        path.move(to: CGPoint(x: 25, y: 50))
        path.addLine(to: CGPoint(x: -25, y: -50))
        return (path, pos)
    }

    private func createLetterY(at pos: CGPoint) -> (CGMutablePath, CGPoint) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -25, y: 50))
        path.addLine(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 25, y: 50))
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 0, y: -50))
        return (path, pos)
    }

   

    private func drawVectorNumber(_ number: Int, at position: CGPoint) -> SKNode {
        let numberNode = SKNode()
        let digitWidth: CGFloat = 10
        let digitSpacing: CGFloat = 5
        let digitHeight: CGFloat = 20
        
        let digitPoints: [[CGPoint]] = [
            // 0
            [CGPoint(x: 0, y: 0), CGPoint(x: digitWidth, y: 0),
             CGPoint(x: digitWidth, y: 0), CGPoint(x: digitWidth, y: digitHeight),
             CGPoint(x: digitWidth, y: digitHeight), CGPoint(x: 0, y: digitHeight),
             CGPoint(x: 0, y: digitHeight), CGPoint(x: 0, y: 0)],
            // 1
            [CGPoint(x: digitWidth, y: 0), CGPoint(x: digitWidth, y: digitHeight)],
            // 2
            [CGPoint(x: 0, y: digitHeight), CGPoint(x: digitWidth, y: digitHeight),
             CGPoint(x: digitWidth, y: digitHeight), CGPoint(x: digitWidth, y: digitHeight/2),
             CGPoint(x: digitWidth, y: digitHeight/2), CGPoint(x: 0, y: digitHeight/2),
             CGPoint(x: 0, y: digitHeight/2), CGPoint(x: 0, y: 0),
             CGPoint(x: 0, y: 0), CGPoint(x: digitWidth, y: 0)],
            // 3
            [CGPoint(x: 0, y: digitHeight), CGPoint(x: digitWidth, y: digitHeight),
             CGPoint(x: digitWidth, y: digitHeight), CGPoint(x: digitWidth, y: 0),
             CGPoint(x: digitWidth, y: 0), CGPoint(x: 0, y: 0),
             CGPoint(x: 0, y: digitHeight/2), CGPoint(x: digitWidth, y: digitHeight/2)],
            // 4
            [CGPoint(x: 0, y: digitHeight), CGPoint(x: 0, y: digitHeight/2),
             CGPoint(x: 0, y: digitHeight/2), CGPoint(x: digitWidth, y: digitHeight/2),
             CGPoint(x: digitWidth, y: digitHeight), CGPoint(x: digitWidth, y: 0)],
            // 5
            [CGPoint(x: digitWidth, y: digitHeight), CGPoint(x: 0, y: digitHeight),
             CGPoint(x: 0, y: digitHeight), CGPoint(x: 0, y: digitHeight/2),
             CGPoint(x: 0, y: digitHeight/2), CGPoint(x: digitWidth, y: digitHeight/2),
             CGPoint(x: digitWidth, y: digitHeight/2), CGPoint(x: digitWidth, y: 0),
             CGPoint(x: digitWidth, y: 0), CGPoint(x: 0, y: 0)],
            // 6
            [CGPoint(x: digitWidth, y: digitHeight), CGPoint(x: 0, y: digitHeight),
             CGPoint(x: 0, y: digitHeight), CGPoint(x: 0, y: 0),
             CGPoint(x: 0, y: 0), CGPoint(x: digitWidth, y: 0),
             CGPoint(x: digitWidth, y: 0), CGPoint(x: digitWidth, y: digitHeight/2),
             CGPoint(x: digitWidth, y: digitHeight/2), CGPoint(x: 0, y: digitHeight/2)],
            // 7
            [CGPoint(x: 0, y: digitHeight), CGPoint(x: digitWidth, y: digitHeight),
             CGPoint(x: digitWidth, y: digitHeight), CGPoint(x: digitWidth, y: 0)],
            // 8
            [CGPoint(x: 0, y: 0), CGPoint(x: digitWidth, y: 0),
             CGPoint(x: digitWidth, y: 0), CGPoint(x: digitWidth, y: digitHeight),
             CGPoint(x: digitWidth, y: digitHeight), CGPoint(x: 0, y: digitHeight),
             CGPoint(x: 0, y: digitHeight), CGPoint(x: 0, y: 0),
             CGPoint(x: 0, y: digitHeight/2), CGPoint(x: digitWidth, y: digitHeight/2)],
            // 9
            [CGPoint(x: digitWidth, y: 0), CGPoint(x: digitWidth, y: digitHeight),
             CGPoint(x: digitWidth, y: digitHeight), CGPoint(x: 0, y: digitHeight),
             CGPoint(x: 0, y: digitHeight), CGPoint(x: 0, y: digitHeight/2),
             CGPoint(x: 0, y: digitHeight/2), CGPoint(x: digitWidth, y: digitHeight/2)]
        ]
        
        // Convert number to string to process each digit
        let digits = String(number).compactMap { Int(String($0)) }
        var totalWidth: CGFloat = 0
        
        // Calculate total width
        totalWidth = CGFloat(digits.count) * (digitWidth + digitSpacing) - digitSpacing
        
        // Start drawing from the left, accounting for total width
        var currentX: CGFloat = -totalWidth / 2
        
        for digit in digits {
            let digitNode = SKNode()
            
            for i in stride(from: 0, to: digitPoints[digit].count, by: 2) {
                let line = SKShapeNode()
                let path = CGMutablePath()
                path.move(to: digitPoints[digit][i])
                path.addLine(to: digitPoints[digit][i + 1])
                line.path = path
                line.strokeColor = .white
                line.lineWidth = 2
                digitNode.addChild(line)
            }
            
            // Position each digit with proper spacing
            digitNode.position = CGPoint(x: currentX, y: 0)
            numberNode.addChild(digitNode)
            
            // Move to next digit position
            currentX += digitWidth + digitSpacing
        }
        
        numberNode.position = position
        return numberNode
    }

    // Add this new function for the spacer character (50% width of normal O)
    private func createLetterSPC(at pos: CGPoint) -> (CGMutablePath, CGPoint) {
        let path = CGMutablePath()
        // Create an empty path with O dimensions but 50% width
        path.move(to: CGPoint(x: -12.5, y: 50))  // Half width of normal O
        path.addLine(to: CGPoint(x: 12.5, y: 50))
        return (path, pos)
    }

    // Update showGameOverScreen function with new spacer
    func showGameOverScreen() {
        // Remove any existing game over screen first
        gameOverScreen?.removeFromParent()
        
        // Create container for all game over lines
        gameOverScreen = SKNode()
        
        // GAME OVER title letters centered (shifted left)
        let gameOverLetters: [(path: CGMutablePath, position: CGPoint)] = [
            createLetterG(at: CGPoint(x: -320, y: 100)),  // Start further left
            createLetterA(at: CGPoint(x: -240, y: 100)),  // 80 units apart
            createLetterM(at: CGPoint(x: -160, y: 100)),  // 80 units apart
            createLetterE(at: CGPoint(x: -80, y: 100)),   // 80 units apart
            createLetterSPC(at: CGPoint(x: 0, y: 100)),   // Center spacer
            createLetterO(at: CGPoint(x: 80, y: 100)),    // 80 units apart
            createLetterV(at: CGPoint(x: 160, y: 100)),   // 80 units apart
            createLetterE(at: CGPoint(x: 240, y: 100)),   // 80 units apart
            createLetterR(at: CGPoint(x: 320, y: 100))    // 80 units apart
        ]
        
        // Add GAME OVER letters to the screen
        for (index, (path, position)) in gameOverLetters.enumerated() {
            let letter = SKShapeNode(path: path)
            letter.strokeColor = index == 4 ? .clear : .white  // Make spacer invisible
            letter.lineWidth = 2.0
            letter.position = position
            gameOverScreen?.addChild(letter)
        }
        
        // PRESS SPACE letters centered under GAME OVER (shifted 5 pixels right)
        let pressSpaceLetters: [(path: CGMutablePath, position: CGPoint)] = [
            createLetterP(at: CGPoint(x: -260, y: -50)),  // +5 from -265
            createLetterR(at: CGPoint(x: -210, y: -50)),  // +5 from -215
            createLetterE(at: CGPoint(x: -160, y: -50)),  // +5 from -165
            createLetterS(at: CGPoint(x: -110, y: -50)),  // +5 from -115
            createLetterS(at: CGPoint(x: -60, y: -50)),   // +5 from -65
            createLetterSPC(at: CGPoint(x: -10, y: -50)), // +5 from -15
            createLetterS(at: CGPoint(x: 40, y: -50)),    // +5 from 35
            createLetterP(at: CGPoint(x: 90, y: -50)),    // +5 from 85
            createLetterA(at: CGPoint(x: 140, y: -50)),   // +5 from 135
            createLetterC(at: CGPoint(x: 190, y: -50)),   // +5 from 185
            createLetterE(at: CGPoint(x: 240, y: -50))    // +5 from 235
        ]
        
        // Add PRESS SPACE letters to the screen with 50% scale
        for (index, (path, position)) in pressSpaceLetters.enumerated() {
            let letter = SKShapeNode(path: path)
            letter.strokeColor = index == 5 ? .clear : .white  // Make spacer invisible
            letter.lineWidth = 2.0
            letter.position = position
            letter.setScale(0.5)  // Set to 50% size
            gameOverScreen?.addChild(letter)
        }
        
        // Position game over screen
        gameOverScreen?.position = CGPoint(x: frame.midX, y: frame.midY)
        if let gameOverScreen = gameOverScreen {
            addChild(gameOverScreen)
        }
        
        // Blink effect for PRESS SPACE
        let blink = SKAction.sequence([
            SKAction.wait(forDuration: 0.5),
            SKAction.run { [weak self] in
                self?.gameOverScreen?.children.forEach { node in
                    if node.position.y < 0 {  // Only affect PRESS SPACE letters
                        node.isHidden.toggle()
                    }
                }
            }
        ])
        
        gameOverScreen?.run(SKAction.repeatForever(blink))
    }

    private func drawVectorLetter(_ text: String, at position: CGPoint) -> SKNode {
        let letterNode = SKNode()
        let letterWidth: CGFloat = 10
        let letterSpacing: CGFloat = 5
        let letterHeight: CGFloat = 20
        
        let letterPoints: [String: [CGPoint]] = [
            "A": [CGPoint(x: 0, y: 0), CGPoint(x: letterWidth/2, y: letterHeight),
                  CGPoint(x: letterWidth/2, y: letterHeight), CGPoint(x: letterWidth, y: 0),
                  CGPoint(x: letterWidth/4, y: letterHeight/2), CGPoint(x: letterWidth*3/4, y: letterHeight/2)],
            "B": [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: letterHeight),
                  CGPoint(x: 0, y: letterHeight), CGPoint(x: letterWidth*3/4, y: letterHeight),
                  CGPoint(x: letterWidth*3/4, y: letterHeight), CGPoint(x: letterWidth, y: letterHeight*3/4),
                  CGPoint(x: letterWidth, y: letterHeight*3/4), CGPoint(x: letterWidth*3/4, y: letterHeight/2),
                  CGPoint(x: letterWidth*3/4, y: letterHeight/2), CGPoint(x: 0, y: letterHeight/2),
                  CGPoint(x: 0, y: letterHeight/2), CGPoint(x: letterWidth*3/4, y: letterHeight/2),
                  CGPoint(x: letterWidth*3/4, y: letterHeight/2), CGPoint(x: letterWidth, y: letterHeight/4),
                  CGPoint(x: letterWidth, y: letterHeight/4), CGPoint(x: letterWidth*3/4, y: 0),
                  CGPoint(x: letterWidth*3/4, y: 0), CGPoint(x: 0, y: 0)],
            "C": [CGPoint(x: letterWidth, y: letterHeight), CGPoint(x: 0, y: letterHeight),
                  CGPoint(x: 0, y: letterHeight), CGPoint(x: 0, y: 0),
                  CGPoint(x: 0, y: 0), CGPoint(x: letterWidth, y: 0)],
            "D": [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: letterHeight),
                  CGPoint(x: 0, y: letterHeight), CGPoint(x: letterWidth*3/4, y: letterHeight),
                  CGPoint(x: letterWidth*3/4, y: letterHeight), CGPoint(x: letterWidth, y: letterHeight*3/4),
                  CGPoint(x: letterWidth, y: letterHeight*3/4), CGPoint(x: letterWidth, y: letterHeight/4),
                  CGPoint(x: letterWidth, y: letterHeight/4), CGPoint(x: letterWidth*3/4, y: 0),
                  CGPoint(x: letterWidth*3/4, y: 0), CGPoint(x: 0, y: 0)],
            "E": [CGPoint(x: letterWidth, y: letterHeight), CGPoint(x: 0, y: letterHeight),
                  CGPoint(x: 0, y: letterHeight), CGPoint(x: 0, y: 0),
                  CGPoint(x: 0, y: 0), CGPoint(x: letterWidth, y: 0),
                  CGPoint(x: 0, y: letterHeight/2), CGPoint(x: letterWidth*3/4, y: letterHeight/2)],
            "F": [CGPoint(x: letterWidth, y: letterHeight), CGPoint(x: 0, y: letterHeight),
                  CGPoint(x: 0, y: letterHeight), CGPoint(x: 0, y: 0),
                  CGPoint(x: 0, y: letterHeight/2), CGPoint(x: letterWidth*3/4, y: letterHeight/2)],
            "G": [CGPoint(x: letterWidth, y: letterHeight), CGPoint(x: 0, y: letterHeight),
                  CGPoint(x: 0, y: letterHeight), CGPoint(x: 0, y: 0),
                  CGPoint(x: 0, y: 0), CGPoint(x: letterWidth, y: 0),
                  CGPoint(x: letterWidth, y: 0), CGPoint(x: letterWidth, y: letterHeight/2),
                  CGPoint(x: letterWidth, y: letterHeight/2), CGPoint(x: letterWidth/2, y: letterHeight/2)],
            "H": [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: letterHeight),
                  CGPoint(x: letterWidth, y: 0), CGPoint(x: letterWidth, y: letterHeight),
                  CGPoint(x: 0, y: letterHeight/2), CGPoint(x: letterWidth, y: letterHeight/2)],
            "I": [CGPoint(x: letterWidth/2, y: 0), CGPoint(x: letterWidth/2, y: letterHeight)],
            "J": [CGPoint(x: letterWidth, y: letterHeight), CGPoint(x: letterWidth, y: letterHeight/4),
                  CGPoint(x: letterWidth, y: letterHeight/4), CGPoint(x: letterWidth*3/4, y: 0),
                  CGPoint(x: letterWidth*3/4, y: 0), CGPoint(x: letterWidth/4, y: 0)],
            "K": [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: letterHeight),
                  CGPoint(x: 0, y: letterHeight/2), CGPoint(x: letterWidth, y: letterHeight),
                  CGPoint(x: 0, y: letterHeight/2), CGPoint(x: letterWidth, y: 0)],
            "L": [CGPoint(x: 0, y: letterHeight), CGPoint(x: 0, y: 0),
                  CGPoint(x: 0, y: 0), CGPoint(x: letterWidth, y: 0)],
            "M": [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: letterHeight),
                  CGPoint(x: 0, y: letterHeight), CGPoint(x: letterWidth/2, y: letterHeight/2),
                  CGPoint(x: letterWidth/2, y: letterHeight/2), CGPoint(x: letterWidth, y: letterHeight),
                  CGPoint(x: letterWidth, y: letterHeight), CGPoint(x: letterWidth, y: 0)],
            "N": [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: letterHeight),
                  CGPoint(x: 0, y: letterHeight), CGPoint(x: letterWidth, y: 0),
                  CGPoint(x: letterWidth, y: 0), CGPoint(x: letterWidth, y: letterHeight)],
            "O": [CGPoint(x: 0, y: 0), CGPoint(x: letterWidth, y: 0),
                  CGPoint(x: letterWidth, y: 0), CGPoint(x: letterWidth, y: letterHeight),
                  CGPoint(x: letterWidth, y: letterHeight), CGPoint(x: 0, y: letterHeight),
                  CGPoint(x: 0, y: letterHeight), CGPoint(x: 0, y: 0)],
            "P": [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: letterHeight),
                  CGPoint(x: 0, y: letterHeight), CGPoint(x: letterWidth, y: letterHeight),
                  CGPoint(x: letterWidth, y: letterHeight), CGPoint(x: letterWidth, y: letterHeight/2),
                  CGPoint(x: letterWidth, y: letterHeight/2), CGPoint(x: 0, y: letterHeight/2)],
            "Q": [CGPoint(x: 0, y: 0), CGPoint(x: letterWidth, y: 0),
                  CGPoint(x: letterWidth, y: 0), CGPoint(x: letterWidth, y: letterHeight),
                  CGPoint(x: letterWidth, y: letterHeight), CGPoint(x: 0, y: letterHeight),
                  CGPoint(x: 0, y: letterHeight), CGPoint(x: 0, y: 0),
                  CGPoint(x: letterWidth/2, y: letterHeight/2), CGPoint(x: letterWidth, y: 0)],
            "R": [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: letterHeight),
                  CGPoint(x: 0, y: letterHeight), CGPoint(x: letterWidth, y: letterHeight),
                  CGPoint(x: letterWidth, y: letterHeight), CGPoint(x: letterWidth, y: letterHeight/2),
                  CGPoint(x: letterWidth, y: letterHeight/2), CGPoint(x: 0, y: letterHeight/2),
                  CGPoint(x: 0, y: letterHeight/2), CGPoint(x: letterWidth, y: 0)],
            "S": [CGPoint(x: letterWidth, y: letterHeight), CGPoint(x: 0, y: letterHeight),
                  CGPoint(x: 0, y: letterHeight), CGPoint(x: 0, y: letterHeight/2),
                  CGPoint(x: 0, y: letterHeight/2), CGPoint(x: letterWidth, y: letterHeight/2),
                  CGPoint(x: letterWidth, y: letterHeight/2), CGPoint(x: letterWidth, y: 0),
                  CGPoint(x: letterWidth, y: 0), CGPoint(x: 0, y: 0)],
            "T": [CGPoint(x: 0, y: letterHeight), CGPoint(x: letterWidth, y: letterHeight),
                  CGPoint(x: letterWidth/2, y: letterHeight), CGPoint(x: letterWidth/2, y: 0)],
            "U": [CGPoint(x: 0, y: letterHeight), CGPoint(x: 0, y: 0),
                  CGPoint(x: 0, y: 0), CGPoint(x: letterWidth, y: 0),
                  CGPoint(x: letterWidth, y: 0), CGPoint(x: letterWidth, y: letterHeight)],
            "V": [CGPoint(x: 0, y: letterHeight), CGPoint(x: letterWidth/2, y: 0),
                  CGPoint(x: letterWidth/2, y: 0), CGPoint(x: letterWidth, y: letterHeight)],
            "W": [CGPoint(x: 0, y: letterHeight), CGPoint(x: letterWidth/4, y: 0),
                  CGPoint(x: letterWidth/4, y: 0), CGPoint(x: letterWidth/2, y: letterHeight/2),
                  CGPoint(x: letterWidth/2, y: letterHeight/2), CGPoint(x: letterWidth*3/4, y: 0),
                  CGPoint(x: letterWidth*3/4, y: 0), CGPoint(x: letterWidth, y: letterHeight)],
            "X": [CGPoint(x: 0, y: 0), CGPoint(x: letterWidth, y: letterHeight),
                  CGPoint(x: 0, y: letterHeight), CGPoint(x: letterWidth, y: 0)],
            "Y": [CGPoint(x: 0, y: letterHeight), CGPoint(x: letterWidth/2, y: letterHeight/2),
                  CGPoint(x: letterWidth/2, y: letterHeight/2), CGPoint(x: letterWidth, y: letterHeight),
                  CGPoint(x: letterWidth/2, y: letterHeight/2), CGPoint(x: letterWidth/2, y: 0)],
            "Z": [CGPoint(x: 0, y: letterHeight), CGPoint(x: letterWidth, y: letterHeight),
                  CGPoint(x: letterWidth, y: letterHeight), CGPoint(x: 0, y: 0),
                  CGPoint(x: 0, y: 0), CGPoint(x: letterWidth, y: 0)],
            " ": []  // HalfSpace - empty points array
        ]
        
        // Convert text to uppercase and process each character
        let chars = text.uppercased().map { String($0) }
        var totalWidth: CGFloat = 0
        
        // Calculate total width
        totalWidth = CGFloat(chars.count) * (letterWidth + letterSpacing) - letterSpacing
        
        // Start drawing from the left, accounting for total width
        var currentX: CGFloat = -totalWidth / 2
        
        for char in chars {
            let charNode = SKNode()
            
            if let points = letterPoints[char] {
                for i in stride(from: 0, to: points.count, by: 2) {
                    let line = SKShapeNode()
                    let path = CGMutablePath()
                    path.move(to: points[i])
                    path.addLine(to: points[i + 1])
                    line.path = path
                    line.strokeColor = .white
                    line.lineWidth = 2
                    charNode.addChild(line)
                }
            }
            
            // Position each character with proper spacing
            charNode.position = CGPoint(x: currentX, y: 0)
            letterNode.addChild(charNode)
            
            // Move to next character position
            currentX += letterWidth + letterSpacing
        }
        
        letterNode.position = position
        return letterNode
    }
}
