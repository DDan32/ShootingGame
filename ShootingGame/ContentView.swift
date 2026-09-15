import SwiftUI
#if canImport(AudioToolbox)
import AudioToolbox
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Aiming Modes
enum AimMode: String, CaseIterable, Identifiable {
    case pistol = "10米手槍"
    case rifle = "10米步槍"

    var id: String { rawValue }

    var englishTitle: String {
        switch self {
        case .pistol: return "10m Pistol"
        case .rifle: return "10m Rifle"
        }
    }
}

// MARK: - Shot Record
struct ShotRecord: Identifiable {
    let id = UUID()
    let offset: CGPoint // offset from target center in points
    let score: Double   // e.g. 10.9
    let mode: AimMode
    let shotNumber: Int
    let date: Date = Date()

    var isPerfect: Bool {
        score >= 10.9
    }
}

// MARK: - Main Content View
struct ContentView: View {
    // Game State
    @State private var aimMode: AimMode = .pistol
    @State private var shots: [ShotRecord] = []
    @State private var lastShotScore: Double? = nil
    @State private var count10_9: Int = 0
    @State private var totalScore: Double = 0.0

    // Aim & Sway State
    @State private var aimOffset: CGPoint = .zero // Player manual aim adjustment
    @State private var isHoldingBreath: Bool = false
    @State private var breathStartTime: Date? = nil
    @State private var isShooting: Bool = false
    @State private var showScorePopup: Bool = false
    @State private var popupScore: Double = 0.0

    // Target geometry settings
    private let targetRadius: CGFloat = 160.0 // Target diameter: 320pt
    private let bullseyeRadius: CGFloat = 62.0 // Black center bullseye

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background paper color (classic ISSF target paper)
                Color(red: 0.91, green: 0.81, blue: 0.61)
                    .ignoresSafeArea()

                VStack(spacing: 8) {
                    // Top Dashboard
                    dashboardView
                        .padding(.horizontal, 16)
                        .padding(.top, 6)

                    // Mode Selection & Icons (matching top-left and top-right in screenshot)
                    modeSelectorRow
                        .padding(.horizontal, 18)
                        .padding(.top, 4)

                    Spacer(minLength: 4)

                    // Central Target Area with Swaying Sight
                    TimelineView(.animation) { timeline in
                        let now = timeline.date.timeIntervalSinceReferenceDate
                        let effectiveHolding = isBreathHoldingActive(now: timeline.date)
                        let sway = calculateSway(at: now, mode: aimMode, isHoldingBreath: effectiveHolding)

                        ZStack {
                            // The Target Face (ISSF 10m target with black bullseye & rainbow core)
                            TargetBoardView(
                                radius: targetRadius,
                                bullseyeRadius: bullseyeRadius,
                                shots: shots
                            )

                            // Sights Overlay (Sways slowly and randomly, also follows player aim drag)
                            sightOverlayView
                                .offset(
                                    x: aimOffset.x + sway.x,
                                    y: aimOffset.y + sway.y
                                )
                                .allowsHitTesting(false)

                            // Recoil flash effect
                            if isShooting {
                                Circle()
                                    .fill(Color.white.opacity(0.4))
                                    .frame(width: targetRadius * 2, height: targetRadius * 2)
                                    .transition(.opacity)
                            }

                            // Score Pop-up callout
                            if showScorePopup {
                                scorePopupView
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .frame(width: targetRadius * 2, height: targetRadius * 2)
                    }
                    // Drag gesture on the target area to fine-tune aim point
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let dragSens: CGFloat = 0.5
                                let proposedX = aimOffset.x + value.translation.width * dragSens * 0.05
                                let proposedY = aimOffset.y + value.translation.height * dragSens * 0.05
                                let maxDist: CGFloat = targetRadius * 0.7
                                aimOffset = CGPoint(
                                    x: max(-maxDist, min(maxDist, proposedX)),
                                    y: max(-maxDist, min(maxDist, proposedY))
                                )
                            }
                    )

                    Spacer(minLength: 6)

                    // Breath Control (Hold to steady aim)
                    breathControlBar
                        .padding(.horizontal, 28)

                    // "CLICK TO SHOT" trigger button (matching reference image)
                    shootButtonView
                        .padding(.bottom, 12)
                }
            }
        }
    }

    // MARK: - Top Dashboard (Last shot, 10.9 count, All shots, Total, RESET)
    private var dashboardView: some View {
        HStack(alignment: .center, spacing: 10) {
            // Left Group: Last shot & 10.9
            VStack(alignment: .trailing, spacing: 6) {
                HStack(spacing: 6) {
                    Text("Last shot:")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.15))
                    scoreBadge(text: lastShotScore != nil ? String(format: "%.1f", lastShotScore!) : "0")
                }

                HStack(spacing: 6) {
                    Text("10.9:")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.15))
                    scoreBadge(text: "\(count10_9)", highlight: count10_9 > 0)
                }
            }

            Spacer()

            // Middle Group: All shots & Total
            VStack(alignment: .trailing, spacing: 6) {
                HStack(spacing: 6) {
                    Text("All shots:")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.15))
                    scoreBadge(text: "\(shots.count)")
                }

                HStack(spacing: 6) {
                    Text("Total:")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.15))
                    scoreBadge(text: String(format: "%.1f", totalScore))
                }
            }

            Spacer()

            // RESET Button (matching the gray bevel button with red bold text)
            Button(action: resetGame) {
                Text("RESET")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundColor(Color(red: 0.9, green: 0.08, blue: 0.08))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color(white: 0.88), Color(white: 0.72)]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: Color.black.opacity(0.35), radius: 2, x: 0, y: 2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.black.opacity(0.25), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private func scoreBadge(text: String, highlight: Bool = false) -> some View {
        Text(text)
            .font(.system(size: 16, weight: .bold, design: .monospaced))
            .foregroundColor(highlight ? Color(red: 1.0, green: 0.85, blue: 0.2) : .white)
            .frame(width: 58, height: 26)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(red: 0.35, green: 0.33, blue: 0.28))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.black.opacity(0.3), lineWidth: 1)
            )
    }

    // MARK: - Mode Selector Row (Pistol on Left, Rifle on Right)
    private var modeSelectorRow: some View {
        HStack {
            // Left: 10m Pistol Button & Icon (U-notch + vertical post in middle)
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    aimMode = .pistol
                }
            }) {
                HStack(spacing: 8) {
                    PistolSightIcon(isSelected: aimMode == .pistol)
                        .frame(width: 46, height: 34)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("10米手槍")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(aimMode == .pistol ? .black : Color(white: 0.35))
                        Text("U型缺口·一豎準星")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(aimMode == .pistol ? Color(white: 0.2) : Color(white: 0.45))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(aimMode == .pistol ? Color.black.opacity(0.1) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(aimMode == .pistol ? Color.black.opacity(0.45) : Color.clear, lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)

            Spacer()

            // Right: 10m Rifle Button & Icon (Concentric circles)
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    aimMode = .rifle
                }
            }) {
                HStack(spacing: 8) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("10米步槍")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(aimMode == .rifle ? .black : Color(white: 0.35))
                        Text("同心圓·覘孔瞄準")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(aimMode == .rifle ? Color(white: 0.2) : Color(white: 0.45))
                    }

                    RifleSightIcon(isSelected: aimMode == .rifle)
                        .frame(width: 38, height: 34)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(aimMode == .rifle ? Color.black.opacity(0.1) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(aimMode == .rifle ? Color.black.opacity(0.45) : Color.clear, lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Sights Overlay
    @ViewBuilder
    private var sightOverlayView: some View {
        switch aimMode {
        case .rifle:
            // 步槍同心圓瞄具 (Concentric Circles Diopter Sight)
            RifleConcentricSightView()
        case .pistol:
            // 手槍U型照門 + 準星一豎 (U-notch rear sight with front post in middle)
            PistolUNotchSightView()
        }
    }

    // MARK: - Breath Control Bar (Hold breath to steady sway)
    private var breathControlBar: some View {
        HStack(spacing: 12) {
            Button(action: {}) {
                HStack(spacing: 6) {
                    Image(systemName: isHoldingBreath ? "lungs.fill" : "lungs")
                        .foregroundColor(isHoldingBreath ? .blue : .primary)
                    Text(isHoldingBreath ? "屏息中..." : "長按屏息穩瞄")
                        .font(.system(size: 13, weight: .medium))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isHoldingBreath ? Color.blue.opacity(0.2) : Color.black.opacity(0.06))
                )
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isHoldingBreath {
                            isHoldingBreath = true
                            breathStartTime = Date()
                        }
                    }
                    .onEnded { _ in
                        isHoldingBreath = false
                        breathStartTime = nil
                    }
            )

            // Recenter Aim Button
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    aimOffset = .zero
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "scope")
                        .font(.system(size: 13, weight: .bold))
                    Text("重置準星")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(Color.black.opacity(0.7))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(Color.black.opacity(0.06))
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Shoot Button (CLICK TO SHOT)
    private var shootButtonView: some View {
        Button(action: fireShot) {
            VStack(spacing: 3) {
                Text("CLICK TO SHOT")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .tracking(1.8)
                    .foregroundColor(Color(red: 0.12, green: 0.12, blue: 0.12))

                Text("點擊擊發 · 靶面滑動微調 · 最高10.9環")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.black.opacity(0.55))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.black.opacity(0.2), lineWidth: 1.5)
            )
            .padding(.horizontal, 24)
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Score Pop-up Callout
    private var scorePopupView: some View {
        VStack(spacing: 2) {
            Text(String(format: "%.1f", popupScore))
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundColor(popupScore >= 10.9 ? Color(red: 1.0, green: 0.84, blue: 0.0) : .white)

            if popupScore >= 10.9 {
                Text("★ PERFECT 10.9 ★")
                    .font(.system(size: 12, weight: .black))
                    .foregroundColor(Color(red: 1.0, green: 0.9, blue: 0.3))
            } else if popupScore >= 10.0 {
                Text("BULLSEYE 10 環")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.85))
                .shadow(color: Color.black.opacity(0.5), radius: 6, x: 0, y: 3)
        )
        .offset(y: -targetRadius * 0.65)
    }

    // MARK: - Breath Holding State Checker
    private func isBreathHoldingActive(now: Date) -> Bool {
        guard isHoldingBreath, let start = breathStartTime else { return false }
        // Breath can be held for up to 4.5 seconds before exhaustion
        let elapsed = now.timeIntervalSince(start)
        return elapsed < 4.5
    }

    // MARK: - Continuous Sway Engine (緩慢、隨機擺動)
    private func calculateSway(at time: TimeInterval, mode: AimMode, isHoldingBreath: Bool) -> CGPoint {
        let t = time
        // Low-frequency drifting (posture & breathing sway: ~0.2Hz - 0.5Hz)
        let driftX = sin(t * 0.68) * 11.0 + sin(t * 1.37 + 1.2) * 5.5
        let driftY = cos(t * 0.52 + 0.7) * 13.0 + cos(t * 1.15 + 2.1) * 6.5

        // Micro-tremors (muscle micro-oscillation: ~2-5Hz)
        let tremorX = sin(t * 3.7 + 0.4) * 1.6 + sin(t * 7.1) * 0.7
        let tremorY = cos(t * 3.2 + 1.1) * 1.6 + cos(t * 6.1) * 0.7

        var x = driftX + tremorX
        var y = driftY + tremorY

        // Mode multiplier:
        // Pistol (single hand extension): larger amplitude
        // Rifle (three points of contact): tighter, circular oscillation
        let modeFactor: CGFloat = (mode == .pistol) ? 1.4 : 0.85
        x *= modeFactor
        y *= modeFactor

        // Breath control reduces sway by ~75%
        if isHoldingBreath {
            x *= 0.25
            y *= 0.25
        }

        return CGPoint(x: x, y: y)
    }

    // MARK: - Fire Shot Logic
    private func fireShot() {
        // Trigger recoil flash
        withAnimation(.easeOut(duration: 0.05)) {
            isShooting = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.easeIn(duration: 0.1)) {
                isShooting = false
            }
        }

        // Haptics & Sound
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
        #endif
        #if canImport(AudioToolbox)
        AudioServicesPlaySystemSound(1104) // camera shutter / metallic crisp click
        #endif

        // Calculate impact position at current instant
        let now = Date().timeIntervalSinceReferenceDate
        let effectiveBreath = isBreathHoldingActive(now: Date())
        let sway = calculateSway(at: now, mode: aimMode, isHoldingBreath: effectiveBreath)

        let impactX = aimOffset.x + sway.x
        let impactY = aimOffset.y + sway.y
        let impactPoint = CGPoint(x: impactX, y: impactY)

        // Distance from target center
        let dist = sqrt(impactX * impactX + impactY * impactY)

        // ISSF Decimal Scoring formula (Maximum is 10.9)
        // Center 10.9 inner ring is at ~3.2 pt
        // Each tenth of a ring is ~1.5 pt
        let scoreStep: CGFloat = 1.45

        let computedScore: Double
        if dist <= scoreStep {
            computedScore = 10.9
        } else if dist >= scoreStep * 100.0 {
            computedScore = 0.0 // Off target (脫靶)
        } else {
            let stepsAway = floor(dist / scoreStep)
            let raw = 10.9 - Double(stepsAway) * 0.1
            computedScore = max(0.0, (raw * 10.0).rounded() / 10.0)
        }

        // Record shot
        let newShot = ShotRecord(
            offset: impactPoint,
            score: computedScore,
            mode: aimMode,
            shotNumber: shots.count + 1
        )
        shots.append(newShot)

        // Update statistics
        lastShotScore = computedScore
        totalScore += computedScore
        if computedScore >= 10.9 {
            count10_9 += 1
        }

        // Show Score Pop-up
        popupScore = computedScore
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            showScorePopup = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.3)) {
                showScorePopup = false
            }
        }
    }

    // MARK: - Reset Game
    private func resetGame() {
        withAnimation(.easeInOut(duration: 0.25)) {
            shots.removeAll()
            lastShotScore = nil
            count10_9 = 0
            totalScore = 0.0
            aimOffset = .zero
            showScorePopup = false
        }
    }
}

// MARK: - Target Board View (ISSF 10-Meter Style with Rainbow Bullseye)
struct TargetBoardView: View {
    let radius: CGFloat
    let bullseyeRadius: CGFloat
    let shots: [ShotRecord]

    var body: some View {
        ZStack {
            // Outermost target paper circle
            Circle()
                .fill(Color(red: 0.91, green: 0.81, blue: 0.61))
                .frame(width: radius * 2, height: radius * 2)

            // Outer rings (Cream paper with black borders)
            ForEach(1...7, id: \.self) { ringIndex in
                let ringR = radius * CGFloat(11 - ringIndex) / 10.0
                Circle()
                    .stroke(
                        ringIndex == 1 ? Color.black : Color.black.opacity(0.65),
                        lineWidth: ringIndex == 1 ? 12.0 : 1.2
                    )
                    .frame(width: ringR * 2, height: ringR * 2)
            }

            // Black Bullseye (Center aiming mark)
            Circle()
                .fill(Color(red: 0.08, green: 0.08, blue: 0.08))
                .frame(width: bullseyeRadius * 2, height: bullseyeRadius * 2)

            // Inside Bullseye: Concentric Rainbow Rings (matching reference screenshot)
            Group {
                // Outer red/coral ring
                Circle()
                    .stroke(Color(red: 0.95, green: 0.25, blue: 0.2), lineWidth: 2.2)
                    .frame(width: 32, height: 32)

                // Cyan/blue ring
                Circle()
                    .stroke(Color(red: 0.2, green: 0.65, blue: 0.9), lineWidth: 2.0)
                    .frame(width: 25, height: 25)

                // Orange/amber ring
                Circle()
                    .stroke(Color(red: 0.95, green: 0.55, blue: 0.15), lineWidth: 1.8)
                    .frame(width: 19, height: 19)

                // Green ring
                Circle()
                    .stroke(Color(red: 0.2, green: 0.78, blue: 0.35), lineWidth: 1.6)
                    .frame(width: 13, height: 13)

                // Yellow ring
                Circle()
                    .stroke(Color(red: 0.95, green: 0.85, blue: 0.15), lineWidth: 1.4)
                    .frame(width: 8, height: 8)

                // Bullseye 10.9 Center Dot (Solid Red)
                Circle()
                    .fill(Color(red: 0.92, green: 0.15, blue: 0.15))
                    .frame(width: 4, height: 4)
            }

            // Bullet Holes on Target
            ForEach(shots) { shot in
                BulletHoleView(
                    shot: shot,
                    isLatest: shot.id == shots.last?.id
                )
                .offset(x: shot.offset.x, y: shot.offset.y)
            }
        }
    }
}

// MARK: - Bullet Hole View
struct BulletHoleView: View {
    let shot: ShotRecord
    let isLatest: Bool

    var body: some View {
        ZStack {
            // Lead grey rim (torn paper effect)
            Circle()
                .fill(Color(red: 0.25, green: 0.25, blue: 0.25))
                .frame(width: 9, height: 9)

            // Black puncture hole
            Circle()
                .fill(Color.black)
                .frame(width: 6.5, height: 6.5)

            // Latest shot highlight ring
            if isLatest {
                Circle()
                    .stroke(
                        shot.isPerfect ? Color.yellow : Color.red,
                        lineWidth: 1.8
                    )
                    .frame(width: 15, height: 15)

                // Score callout tag
                Text(String(format: "%.1f", shot.score))
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundColor(.white)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(
                        Capsule().fill(shot.isPerfect ? Color.orange : Color.black.opacity(0.8))
                    )
                    .offset(x: 14, y: -8)
            }
        }
    }
}

// MARK: - Rifle Concentric Sight View ("步槍是同心圓")
// Concentric circles diopter sight for 10m Air Rifle
struct RifleConcentricSightView: View {
    var body: some View {
        ZStack {
            // Outer diopter peep aperture rim (translucent dark vignette framing)
            Circle()
                .stroke(Color.black.opacity(0.75), lineWidth: 18)
                .frame(width: 170, height: 170)

            // Thin secondary alignment ring
            Circle()
                .stroke(Color.black.opacity(0.45), lineWidth: 1.5)
                .frame(width: 120, height: 120)

            // Front sight tunnel aperture (the classic concentric front sight ring)
            Circle()
                .stroke(Color.black.opacity(0.85), lineWidth: 3.5)
                .frame(width: 66, height: 66)

            // Horizontal fine support crossbars
            Rectangle()
                .fill(Color.black.opacity(0.75))
                .frame(width: 26, height: 1.5)
                .offset(x: -46)

            Rectangle()
                .fill(Color.black.opacity(0.75))
                .frame(width: 26, height: 1.5)
                .offset(x: 46)

            // Center inner fine circle (perfectly frames the bullseye for 10.9)
            Circle()
                .stroke(Color.red.opacity(0.65), lineWidth: 1.2)
                .frame(width: 18, height: 18)

            // Tiny central reference dot
            Circle()
                .fill(Color.red.opacity(0.8))
                .frame(width: 2.5, height: 2.5)
        }
    }
}

// MARK: - Pistol U-Notch Sight View ("手槍類似U，中間有多一豎")
// Open sights: rear U-notch blade with front sight post in the middle
struct PistolUNotchSightView: View {
    var body: some View {
        ZStack(alignment: .top) {
            // Rear sight blade (two blocks forming the U/square notch)
            PistolRearSightShape()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.22, green: 0.22, blue: 0.24),
                            Color(red: 0.12, green: 0.12, blue: 0.14)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 130, height: 36)
                .shadow(color: Color.black.opacity(0.35), radius: 2, x: 0, y: 1)

            // Front sight post ("中間有多一豎")
            // Sits vertically in the center notch of the U
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.18, green: 0.18, blue: 0.2),
                            Color(red: 0.05, green: 0.05, blue: 0.05)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 14, height: 26)
                .overlay(
                    // Crisp top edge highlight and center reference line
                    VStack {
                        Rectangle()
                            .fill(Color.white.opacity(0.35))
                            .frame(height: 1.5)
                        Spacer()
                    }
                )
                // Positioned so top of post aligns with top of rear notch
                .offset(y: 2)

            // Alignment reference marks
            HStack(spacing: 38) {
                Rectangle()
                    .fill(Color.white.opacity(0.4))
                    .frame(width: 2, height: 14)
                Rectangle()
                    .fill(Color.white.opacity(0.4))
                    .frame(width: 2, height: 14)
            }
            .offset(y: 8)
        }
        .offset(y: 0)
    }
}

// Shape for the rear sight blade with U-notch
struct PistolRearSightShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let notchWidth: CGFloat = 28.0
        let notchDepth: CGFloat = 22.0
        let midX = rect.midX

        // Left top
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        // Left notch corner
        path.addLine(to: CGPoint(x: midX - notchWidth / 2, y: rect.minY))
        // Down into notch
        path.addLine(to: CGPoint(x: midX - notchWidth / 2, y: rect.minY + notchDepth))
        // Across notch bottom
        path.addLine(to: CGPoint(x: midX + notchWidth / 2, y: rect.minY + notchDepth))
        // Up right notch corner
        path.addLine(to: CGPoint(x: midX + notchWidth / 2, y: rect.minY))
        // Right top
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        // Right bottom
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        // Left bottom
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()

        return path
    }
}

// MARK: - Icon Views (Matching Reference Image Header Icons)
// Left Icon: Pistol sight with bullseye circle above post
struct PistolSightIcon: View {
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 2) {
            // Target circle perched atop sight
            Circle()
                .fill(isSelected ? Color(red: 0.55, green: 0.52, blue: 0.42) : Color.gray.opacity(0.5))
                .frame(width: 14, height: 14)

            // U-notch with vertical post in center
            ZStack(alignment: .top) {
                PistolRearSightShape()
                    .fill(isSelected ? Color(red: 0.65, green: 0.62, blue: 0.5) : Color.gray.opacity(0.45))
                    .frame(width: 44, height: 14)

                // Front post
                Rectangle()
                    .fill(isSelected ? Color(red: 0.55, green: 0.52, blue: 0.42) : Color.gray.opacity(0.5))
                    .frame(width: 6, height: 12)
                    .offset(y: 1)
            }
        }
    }
}

// Right Icon: Concentric rings (IPPON shooting style)
struct RifleSightIcon: View {
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(isSelected ? Color(red: 0.55, green: 0.52, blue: 0.42) : Color.gray.opacity(0.45), lineWidth: 4)
                .frame(width: 28, height: 28)

            Circle()
                .fill(isSelected ? Color(red: 0.9, green: 0.55, blue: 0.38) : Color.gray.opacity(0.4))
                .frame(width: 14, height: 14)

            Circle()
                .stroke(Color.white.opacity(0.7), lineWidth: 1.5)
                .frame(width: 8, height: 8)
        }
    }
}

// MARK: - Tactile Press Button Style
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeInOut(duration: 0.08), value: configuration.isPressed)
    }
}

// MARK: - Preview
#Preview {
    ContentView()
}
