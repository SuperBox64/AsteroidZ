//
//  GameScene.swift
//  AsteroidZ
//
//  Created by SuperBox64m on 12/31/24.
//

import SpriteKit
import GameplayKit

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
    
    private var score: Int = 0 {
        didSet {
            scoreLabel.text = "Score: \(score)"
            
            // Check for extra ship bonus
            if score >= lastExtraShipScore + extraShipBonus {
                awardExtraShip()
                lastExtraShipScore = score - (score % extraShipBonus)  // Reset to last milestone
            }
            
            // Update high score if needed
            if score > highScore {
                highScore = score
                UserDefaults.standard.set(highScore, forKey: "highScore")
            }
        }
    }
    private var lives: Int = 5 {
        didSet {
            livesLabel.text = "Lives: \(lives)"
        }
    }
    private var highScore: Int = UserDefaults.standard.integer(forKey: "highScore") {
        didSet {
            highScoreLabel.text = "High Score: \(highScore)"
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
    private let extraShipBonus = 500    // Points needed for extra ship
    private var thrustSound: SKAction!
    private let thrustSoundKey = "thrustSound"  // Unique key for the sound action
    private var thrustSoundNode: SKAudioNode?  // To track and stop the sound
    
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
    private let shipThrustSpeed: CGFloat = 15.0  // Reduced by 90% from 150 to 15
    
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
        saucer.physicsBody?.contactTestBitMask = shipCategory | bulletCategory
        saucer.physicsBody?.collisionBitMask = 0
        saucer.physicsBody?.affectedByGravity = false
        saucer.physicsBody?.isDynamic = true
        saucer.physicsBody?.usesPreciseCollisionDetection = true
        
        // Add these for better collision detection
        saucer.physicsBody?.mass = 1.0
        saucer.physicsBody?.linearDamping = 0
        saucer.physicsBody?.angularDamping = 0
        
        return saucer
    }
    
    override func sceneDidLoad() {
        // Set black background
        backgroundColor = .black
        
        // Enable physics world and contact delegate
        physicsWorld.contactDelegate = self
        
        // Initialize fade and throb actions with longer durations
        fadeInAction = SKAction.fadeIn(withDuration: 1.0)  // Longer fade-in (3 seconds)
        throbAction = SKAction.sequence([
            SKAction.group([
                SKAction.repeat(
                    SKAction.sequence([
                        SKAction.fadeAlpha(to: 0.5, duration: 0.5),
                        SKAction.scale(to: 0.9, duration: 0.5),      // Start at half size
                        SKAction.scale(to: 1.0, duration: 0.5),  // Scale up over 3 seconds
                        SKAction.fadeAlpha(to: 1.0, duration: 0.5)
                    ]),
                    count: 1
                )
            ])
        ])
        
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
        
        // Create a SOLID physics body for the ship, not an edge-based one
        player.physicsBody = SKPhysicsBody(polygonFrom: path)  // Changed from edgeLoopFrom
        player.physicsBody?.categoryBitMask = shipCategory
        player.physicsBody?.contactTestBitMask = allAsteroidsCategory
        player.physicsBody?.collisionBitMask = 0
        player.physicsBody?.affectedByGravity = false
        player.physicsBody?.isDynamic = true
        player.physicsBody?.usesPreciseCollisionDetection = true  // Add this for better collision detection
        
        player.alpha = 0  // Start completely invisible
        player.isHidden = true  // Hide it completely
        addChild(player)
        
        // Add initial asteroids
        for _ in 0..<10 {
            spawnAsteroid(size: .large)
        }
        
        // Add score label
        scoreLabel = SKLabelNode(fontNamed: "Helvetica")
        scoreLabel.text = "Score: 0"
        scoreLabel.fontSize = 20
        scoreLabel.position = CGPoint(x: 70, y: frame.maxY - 30)
        scoreLabel.horizontalAlignmentMode = .left
        addChild(scoreLabel)
        
        // Add lives label
        livesLabel = SKLabelNode(fontNamed: "Helvetica")
        livesLabel.text = "Lives: 5"
        livesLabel.fontSize = 20
        livesLabel.position = CGPoint(x: frame.maxX - 70, y: frame.maxY - 30)
        livesLabel.horizontalAlignmentMode = .right
        addChild(livesLabel)
        
        // Add high score label
        highScoreLabel = SKLabelNode(fontNamed: "Helvetica")
        highScoreLabel.text = "High Score: \(highScore)"
        highScoreLabel.fontSize = 20
        highScoreLabel.position = CGPoint(x: frame.midX, y: frame.maxY - 30)
        highScoreLabel.horizontalAlignmentMode = .center
        addChild(highScoreLabel)
        
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
        
        // Try to spawn player safely after everything is set up
        tryRespawn()
        
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
        
        // Start regular saucer spawning with longer initial delay
        startSaucerTimer()
        
        // Setup thrust sound
        thrustSoundAction = SKAction.playSoundFileNamed("thrust.wav", waitForCompletion: false)
      
        // Start background beats immediately after setup
        startBackgroundBeats()
        
        // Create reverse thrust visual
        let reverseFlame = SKShapeNode()
        let reverseThrustPath = CGMutablePath()
        reverseThrustPath.move(to: CGPoint(x: -8, y: 20))  // Left base at top
        reverseThrustPath.addLine(to: CGPoint(x: 0, y: 30)) // Thrust point at top
        reverseThrustPath.addLine(to: CGPoint(x: 8, y: 20))  // Right base at top
        
        reverseFlame.path = reverseThrustPath
        reverseFlame.strokeColor = .white
        reverseFlame.lineWidth = 2.0
        reverseFlame.fillColor = .clear
        reverseFlame.isHidden = true
        player.addChild(reverseFlame)
        
        reverseFlameNode = reverseFlame
    }
    
    func startSaucerTimer() {
        saucerTimer = Timer.scheduledTimer(withTimeInterval: 20.0, repeats: true) { [weak self] _ in
            self?.spawnSaucer()
        }
        
        // Add initial delay before first saucer spawn (30 seconds instead of immediate)
        saucerTimer?.fireDate = Date().addingTimeInterval(30.0)
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
        let asteroidPath = createAsteroidPath(radius: size.radius, points: size.points)
        let asteroid = SKShapeNode(path: asteroidPath)
        asteroid.strokeColor = .white
        asteroid.lineWidth = 2.0
        
        // Initialize userData dictionary
        asteroid.userData = NSMutableDictionary()
        asteroid.userData?["size"] = size
        
        if isNextAster {
            asteroid.fillColor = .black  // Aster type
            asteroid.physicsBody = SKPhysicsBody(polygonFrom: asteroidPath)  // SOLID physics body
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
        } else {
            asteroid.fillColor = .clear  // Roid type
            asteroid.physicsBody = SKPhysicsBody(polygonFrom: asteroidPath)  // SOLID physics body
            asteroid.physicsBody?.categoryBitMask = roidCategory
            asteroid.physicsBody?.contactTestBitMask = shipCategory
            asteroid.physicsBody?.collisionBitMask = 0
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
        
        asteroids.append(asteroid)
        addChild(asteroid)
        
        // Update beat tempo when new asteroid is added
        updateBeatTempo()
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
        // Create bullet
        let bullet = SKShapeNode(circleOfRadius: 2.0)
        bullet.strokeColor = .white
        bullet.fillColor = .white
        
        // Calculate position at tip of triangle (point facing forward)
        let tipOffset = CGPoint(x: -sin(player.zRotation) * 20,  // Negative sin for correct x direction
                               y: cos(player.zRotation) * 20)     // Positive cos for correct y direction
        bullet.position = CGPoint(x: player.position.x + tipOffset.x,
                                y: player.position.y + tipOffset.y)
        
        // Play fire sound
        run(fireSound)
        
        // Add physics body
        bullet.physicsBody = SKPhysicsBody(circleOfRadius: 2.0)
        bullet.physicsBody?.categoryBitMask = bulletCategory
        bullet.physicsBody?.collisionBitMask = 0
        bullet.physicsBody?.contactTestBitMask = allAsteroidsCategory | saucerCategory
        bullet.physicsBody?.affectedByGravity = false
        
        // Set velocity in same direction as ship is pointing
        let bulletSpeed: CGFloat = 400.0
        bullet.physicsBody?.velocity = CGVector(dx: -sin(player.zRotation) * bulletSpeed,  // Match direction
                                              dy: cos(player.zRotation) * bulletSpeed)
        
        bullets.append(bullet)
        addChild(bullet)
    }
    
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 123: // Left arrow
            rotationRate = 2.0
        case 124: // Right arrow
            rotationRate = -2.0
        case 126: // Up arrow
            thrustDirection = 1.0
            showThrustFlame()
        case 125: // Down arrow
            thrustDirection = -0.5  // Half strength of forward thrust
            showReverseFlame()  // Show reverse thrust flame
        case 49: // Spacebar
            let currentTime = CACurrentMediaTime()
            if currentTime - lastFireTime >= fireRate {
                lastFireTime = currentTime
                fireBullet()
            }
        case 8: // 'C' key
            if isGameOver {
                restartGame()
            }
        default:
            break
        }
        
        if isGameOver && event.keyCode == 8 { // 8 is 'C' key
            restartGame()
        }
    }
    
    override func keyUp(with event: NSEvent) {
        switch event.keyCode {
        case 123, 124: // Left/Right arrows
            rotationRate = 0
        case 126: // Up arrow
            thrustDirection = 0
            hideThrustFlame()
        case 125: // Down arrow
            thrustDirection = 0
            hideReverseFlame()
        default:
            break
        }
    }
    
    override func update(_ currentTime: TimeInterval) {
        // Move rotation update to the start and ensure it always happens
        if rotationRate != 0 {
            player.zRotation += rotationRate * CGFloat(0.05)
        }
        
        // Apply thrust and play sound
        if thrustDirection != 0 {
            let angle = player.zRotation
            let dx = -sin(angle) * shipThrustSpeed * thrustDirection
            let dy = cos(angle) * shipThrustSpeed * thrustDirection
            player.physicsBody?.applyForce(CGVector(dx: dx, dy: dy))
            
            // Show thrust visual
            thrustNode?.isHidden = false
            
            // Play thrust sound in spurts
            if action(forKey: "thrustSound") == nil {
                let playSound = SKAction.playSoundFileNamed("thrust.wav", waitForCompletion: false)
                let wait = SKAction.wait(forDuration: 0.1)  // Short pause between sounds
                let sequence = SKAction.sequence([playSound, wait])
                run(sequence, withKey: "thrustSound")
            }
        } else {
            // Hide thrust visual and stop sound when not thrusting
            thrustNode?.isHidden = true
            removeAction(forKey: "thrustSound")
        }
        
        // Update position
        player.position.x += velocity.dx
        player.position.y += velocity.dy
        
        // Screen wrapping
        if player.position.x > frame.maxX {
            player.position.x = frame.minX
        } else if player.position.x < frame.minX {
            player.position.x = frame.maxX
        }
        
        if player.position.y > frame.maxY {
            player.position.y = frame.minY
        } else if player.position.y < frame.minY {
            player.position.y = frame.maxY
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
        
        // Update beat tempo based on current asteroid count
        updateBeatTempo()
    }
    
    // Add these new methods for asteroid splitting
    func splitAsteroid(_ asteroid: SKShapeNode, awardPoints: Bool = false) {
        if let size = asteroid.userData?["size"] as? AsteroidSize {
            // Play appropriate explosion sound based on size
            switch size {
            case .large:
                run(bangLargeSound)
            case .medium:
                run(bangMediumSound)
            case .small:
                run(bangSmallSound)
            }
            
            // Only award score if awardPoints is true
            if awardPoints {
                switch size {
                case .large:
                    score += 5
                case .medium:
                    score += 10
                case .small:
                    score += 15
                }
            }
            
            // Remove the original asteroid
            if let index = asteroids.firstIndex(of: asteroid) {
                asteroids.remove(at: index)
            }
            asteroid.removeFromParent()
            
            // Determine new size and number of splits
            switch size {
            case .large:
                // Split into two medium asteroids
                spawnSplitAsteroids(at: asteroid.position, size: .medium, count: 2)
            case .medium:
                // Split into two small asteroids
                spawnSplitAsteroids(at: asteroid.position, size: .small, count: 2)
            case .small:
                // Small asteroids just disappear
                return
            }
            
            // Update beat tempo after splitting
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
            newAsteroid.fillColor = isNextAster ? .black : .clear
            
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
        // Play correct explosion sound
        run(bangMediumSound)
        
        // Create ship break-apart animation
        createShipDestructionAnimation()
        
        lives -= 1
        player.isHidden = true
        isRespawning = true
        
        if lives > 0 {
            let waitAction = SKAction.wait(forDuration: 2.0)
            run(waitAction) { [weak self] in
                self?.tryRespawn()
            }
        } else {
            // Wait 2 seconds then show game over
            let waitAction = SKAction.wait(forDuration: 2.0)
            run(waitAction) { [weak self] in
                self?.showGameOver()
            }
        }
    }
    
    func showGameOver() {
        isGameOver = true
        showMessage("GAME OVER - Press 'C' to Continue", duration: 3.0)
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
        // Always start in middle of screen
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
            // Safe to spawn in center
            player.position = centerPoint
            player.isHidden = false
            isRespawning = false
            
            // Reset thrust when spawning
            thrustDirection = 0
            player.physicsBody?.velocity = .zero
            player.physicsBody?.angularVelocity = 0
            
            // Start completely invisible and add the effects
            player.alpha = 0
            player.setScale(1.0)
            player.run(SKAction.group([fadeInAction, throbAction]))
        } else {
            // Try again in a second if area isn't clear
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
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
    
    // Add ship destruction animation
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
            $0.position = player.position
            $0.zRotation = player.zRotation
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
    
    // Add contact delegate method
    func didBegin(_ contact: SKPhysicsContact) {
        let collision = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask
        
        // Add check for saucer bullets hitting asteroids
        if collision == (saucerBulletCategory | asterCategory) || 
           collision == (saucerBulletCategory | roidCategory) {
            
            let bullet = (contact.bodyA.categoryBitMask == saucerBulletCategory) ? 
                         contact.bodyA.node : contact.bodyB.node
            let asteroid = (contact.bodyA.categoryBitMask == saucerBulletCategory) ? 
                           contact.bodyB.node : contact.bodyA.node
            
            // Remove the bullet
            bullet?.removeFromParent()
            
            // Split the asteroid if it exists
            if let asteroidNode = asteroid as? SKShapeNode {
                splitAsteroid(asteroidNode, awardPoints: false)  // Don't award points
            }
        }
        
        // Handle ship's bullets hitting asteroids or saucers
        if collision == (bulletCategory | asterCategory) || 
           collision == (bulletCategory | roidCategory) ||
           collision == (bulletCategory | saucerCategory) {
            
            let bullet = (contact.bodyA.categoryBitMask == bulletCategory) ? 
                         contact.bodyA.node : contact.bodyB.node
            let target = (contact.bodyA.categoryBitMask == bulletCategory) ? 
                         contact.bodyB.node : contact.bodyA.node
            
            // Only score if it's the player's bullet (not from saucer)
            if let bulletNode = bullet as? SKShapeNode,
               let targetNode = target as? SKShapeNode {
                
                // Check if bullet is from player (not from saucer)
                if bulletNode.physicsBody?.categoryBitMask == bulletCategory {
                    
                    // Score for hitting saucer
                    if target?.physicsBody?.categoryBitMask == saucerCategory {
                        // Check saucer size and play appropriate sound
                        if let saucer = target as? SKShapeNode {
                            let isLarge = saucer.xScale == 1.0
                            score += isLarge ? 25 : 50  // Large = 50, Small = 75 points
                            saucerDestroyed(saucer)
                        }
                    }
                    // Score for hitting asteroids
                    else if let size = targetNode.userData?["size"] as? AsteroidSize {
                        splitAsteroid(targetNode, awardPoints: true)  // Award points for player bullets
                    }
                }
                
                // Remove the bullet regardless of source
                bulletNode.removeFromParent()
            }
        }
        
        // Handle ship collisions
        if (contact.bodyA.categoryBitMask == shipCategory || 
            contact.bodyB.categoryBitMask == shipCategory) {
            if !isRespawning {
                playerDied()
            }
        }
    }
    
    func restartGame() {
        // Remove game over labels
        childNode(withName: "gameOverLabel")?.removeFromParent()
        childNode(withName: "restartLabel")?.removeFromParent()
        
        // Remove all existing asteroids
        asteroids.forEach { $0.removeFromParent() }
        asteroids.removeAll()
        
        // Reset game state
        lives = 5
        score = 0
        isGameOver = false
        
        // Spawn new asteroids
        for _ in 0..<10 {
            spawnAsteroid(size: .large)
        }
        
        // Try to spawn player
        tryRespawn()
        
        lastExtraShipScore = 0  // Reset extra ship counter
        currentAsteroidSpeed = initialAsteroidSpeed
        
        // Use these instead
        beatInterval = maxBeatInterval
        startBackgroundBeats()
    }
    
    func startBackgroundBeats() {
        // Stop any existing timer
        beatTimer?.invalidate()
        beatTimer = nil
        
        // Play first beat immediately
        run(beat1)
        currentBeat = 2
        
        // Create new timer that repeats
        beatTimer = Timer.scheduledTimer(withTimeInterval: beatInterval, repeats: true) { [weak self] _ in
            self?.playNextBeat()
        }
        
        // Make sure timer is added to current run loop
        RunLoop.current.add(beatTimer!, forMode: .common)
    }
    
    func updateBeatTempo() {
        // Count only small asteroids
        let smallAsteroidCount = asteroids.filter { asteroid in
            if let size = asteroid.userData?["size"] as? AsteroidSize {
                return size == .small
            }
            return false
        }.count
        
        // Store old interval to check if it changed
        let oldInterval = beatInterval
        
        // Update interval based on count
        switch smallAsteroidCount {
        case 0...4:
            beatInterval = 1.0  // Slowest
        case 5...9:
            beatInterval = 0.9
        case 10...14:
            beatInterval = 0.8
        case 15...19:
            beatInterval = 0.7
        case 20...29:
            beatInterval = 0.6
        case 30...39:
            beatInterval = 0.5
        case 40...49:
            beatInterval = 0.4
        default:  // 50 or more
            beatInterval = 0.3  // Fastest
        }
        
        // Only update timer if interval changed
        if oldInterval != beatInterval {
            beatTimer?.invalidate()
            beatTimer = Timer.scheduledTimer(withTimeInterval: beatInterval, repeats: true) { [weak self] _ in
                self?.playNextBeat()
            }
            RunLoop.current.add(beatTimer!, forMode: .common)
        }
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
        showMessage("EXTRA SHIP!")
    }
    
    func decideSaucerSize() -> SaucerSize {
        return Bool.random() ? .large : .small  // Simpler 50/50
    }
    
    func spawnSaucer(forcedSize: SaucerSize? = nil) {
        // Don't spawn if one already exists
        if activeSaucer != nil { return }
        
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
        // Determine size and play appropriate explosion sound
        let isLarge = saucer.xScale == 1.0
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
        // Flicker effect for thrust
        let flicker = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.3, duration: 0.1),
            SKAction.fadeAlpha(to: 1.0, duration: 0.1)
        ])
        thrustNode?.isHidden = false
        thrustNode?.run(SKAction.repeatForever(flicker))
    }
    
    func hideThrustFlame() {
        thrustNode?.removeAllActions()
        thrustNode?.isHidden = true
    }
    
    func showReverseFlame() {
        // Flicker effect for reverse thrust
        let flicker = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.3, duration: 0.1),
            SKAction.fadeAlpha(to: 1.0, duration: 0.1)
        ])
        reverseFlameNode?.isHidden = false
        reverseFlameNode?.run(SKAction.repeatForever(flicker))
    }
    
    func hideReverseFlame() {
        reverseFlameNode?.removeAllActions()
        reverseFlameNode?.isHidden = true
    }
    
    // Add this helper function
    func showMessage(_ text: String, duration: TimeInterval = 2.0) {
        let messageLabel = SKLabelNode(fontNamed: "Helvetica")
        messageLabel.text = text
        messageLabel.fontSize = 20
        messageLabel.alpha = 0.5  // 50% opacity
        messageLabel.position = CGPoint(x: frame.maxX - 100, y: 50)  // Lower right
        messageLabel.horizontalAlignmentMode = .right
        addChild(messageLabel)
        
        // Animate and remove
        let fadeIn = SKAction.fadeIn(withDuration: 0.3)
        let wait = SKAction.wait(forDuration: duration)
        let fadeOut = SKAction.fadeOut(withDuration: 0.3)
        let remove = SKAction.removeFromParent()
        messageLabel.run(SKAction.sequence([fadeIn, wait, fadeOut, remove]))
    }
}
