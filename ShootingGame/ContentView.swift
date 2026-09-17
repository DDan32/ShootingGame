import SwiftUI
import AVFoundation
import Combine
#if canImport(AudioToolbox)
import AudioToolbox
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - App Language Support
enum AppLanguage: String, CaseIterable, Identifiable {
    case traditionalChinese = "繁體中文"
    case english = "English"

    var id: String { rawValue }
}

// MARK: - Localization
struct L10n {
    let lang: AppLanguage

    var appTitle: String { lang == .traditionalChinese ? "1 0 米 射 擊" : "10M SHOOTING" }
    var appSubtitle: String { lang == .traditionalChinese ? "射 擊 模 擬 器" : "SHOOTING SIMULATOR" }
    var startButton: String { lang == .traditionalChinese ? "開 始 射 擊" : "Start Shooting" }
    var instructionsButton: String { lang == .traditionalChinese ? "操 作 說 明" : "Instructions" }
    var historyButton: String { lang == .traditionalChinese ? "歷 史 記 錄" : "Match History" }
    var languageLabel: String { lang == .traditionalChinese ? "語 言 / Language" : "語 言 / Language" }

    var pistolMode: String { lang == .traditionalChinese ? "10米手槍" : "10m Pistol" }
    var rifleMode: String { lang == .traditionalChinese ? "10米步槍" : "10m Rifle" }

    var lastShot: String { lang == .traditionalChinese ? "上一發" : "Last" }
    var seriesSubtotal: String { lang == .traditionalChinese ? "當前組" : "Series" }
    var grandTotal: String { lang == .traditionalChinese ? "大賽總分" : "Total" }
    var shotProgress: String { lang == .traditionalChinese ? "總發數" : "Shots" }
    var scorecardBtn: String { lang == .traditionalChinese ? "計分表" : "Card" }
    var finishBtn: String { lang == .traditionalChinese ? "結束" : "Finish" }

    // Mode Selection & Finish Confirmation Dialogs
    var selectWeaponTitle: String { lang == .traditionalChinese ? "選擇射擊項目" : "Select Event" }
    var selectWeaponMessage: String { lang == .traditionalChinese ? "請選擇本次要練習的射擊項目：" : "Please select the event for this session:" }
    var finishTitle: String { lang == .traditionalChinese ? "結束本場射擊" : "Finish Match" }
    var finishMessage: String { lang == .traditionalChinese ? "請選擇如何處理目前的射擊成績：" : "Choose how to handle your match results:" }
    var saveAndExit: String { lang == .traditionalChinese ? "儲存成績並結束" : "Save & Finish" }
    var exitWithoutSaving: String { lang == .traditionalChinese ? "退出不儲存" : "Exit Without Saving" }
    var cancel: String { lang == .traditionalChinese ? "取消" : "Cancel" }

    var maxShotsLabel: String { lang == .traditionalChinese ? "靶面彈印:" : "Target Marks:" }
    var oneShot: String { lang == .traditionalChinese ? "1 發" : "1 Shot" }
    var fiveShots: String { lang == .traditionalChinese ? "5 發" : "5 Shots" }
    var tenShots: String { lang == .traditionalChinese ? "10 發" : "10 Shots" }

    var holdBreath: String { lang == .traditionalChinese ? "長按螢幕瞄準 · 鬆開射擊" : "Hold to Aim · Release to Shoot" }
    var holdingBreath: String { lang == .traditionalChinese ? "屏息瞄準中 · 鬆開擊發" : "Aiming · Release to Fire" }
    var clickToShot: String { lang == .traditionalChinese ? "長按瞄準 · 鬆開射擊" : "HOLD TO AIM · RELEASE TO SHOOT" }
    var shootHint: String { lang == .traditionalChinese ? "長按靶面屏息瞄準，鬆手瞬間擊發！" : "Hold target to steady aim, release to shoot!" }
    var backToMenu: String { lang == .traditionalChinese ? "主選單" : "Menu" }
    var resetMatch: String { lang == .traditionalChinese ? "清空" : "Clear" }

    var instructionsTitle: String { lang == .traditionalChinese ? "射擊規則與操作說明" : "Rules & Instructions" }
    var closeButton: String { lang == .traditionalChinese ? "關閉" : "Close" }
}

// MARK: - Sound & Haptic FX Engine
final class SoundManager {
    static let shared = SoundManager()
    private var audioPlayer: AVAudioPlayer?

    private init() {
        configureAudioSession()
        prepareAudioPlayer()
    }

    private func configureAudioSession() {
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
        #endif
    }

    private func prepareAudioPlayer() {
        if let url = Bundle.main.url(forResource: "metal_hit", withExtension: "wav") ??
                     Bundle.main.url(forResource: "metal_hit", withExtension: "m4a") {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.prepareToPlay()
            } catch {
                print("Failed to load metal hit sound: \(error)")
            }
        }
    }

    func playGunshot() {
        if let player = audioPlayer {
            player.stop()
            player.currentTime = 0
            player.play()
        } else {
            prepareAudioPlayer()
            if let player = audioPlayer {
                player.play()
            } else {
                #if canImport(AudioToolbox)
                AudioServicesPlaySystemSound(1104)
                #endif
            }
        }

        #if canImport(UIKit)
        let gen = UIImpactFeedbackGenerator(style: .heavy)
        gen.prepare()
        gen.impactOccurred()
        #endif
    }
}

// MARK: - Aiming Modes
enum AimMode: String, CaseIterable, Identifiable, Codable {
    case pistol = "10米手槍"
    case rifle = "10米步槍"

    var id: String { rawValue }

    func displayName(lang: AppLanguage) -> String {
        switch self {
        case .pistol:
            return lang == .traditionalChinese ? "10米手槍" : "10m Pistol"
        case .rifle:
            return lang == .traditionalChinese ? "10米步槍" : "10m Rifle"
        }
    }
}

// MARK: - Shot Record with Deviation Direction
struct ShotRecord: Identifiable, Codable {
    let id: UUID
    let offsetX: Double
    let offsetY: Double
    let score: Double
    let mode: AimMode
    let shotNumber: Int

    init(id: UUID = UUID(), offset: CGPoint, score: Double, mode: AimMode, shotNumber: Int) {
        self.id = id
        self.offsetX = Double(offset.x)
        self.offsetY = Double(offset.y)
        self.score = score
        self.mode = mode
        self.shotNumber = shotNumber
    }

    var offset: CGPoint {
        CGPoint(x: offsetX, y: offsetY)
    }

    var isPerfect: Bool {
        score >= 10.9
    }

    // Deviation angle for directional arrow (relative to target center)
    var deviationAngle: Angle {
        Angle(radians: atan2(offsetY, offsetX) + .pi / 2)
    }

    // Clock hour direction (e.g. 2點鐘方向 / 2 o'clock)
    var clockDirection: String {
        clockDirection(lang: .traditionalChinese)
    }

    func clockDirection(lang: AppLanguage) -> String {
        if isPerfect { return "◎" }
        var deg = atan2(offsetY, offsetX) * 180.0 / .pi
        if deg < 0 { deg += 360.0 }
        let rawHour = Int((deg + 90.0).truncatingRemainder(dividingBy: 360.0) / 30.0)
        let hour = (rawHour == 0) ? 12 : rawHour
        return lang == .traditionalChinese ? "\(hour)點" : "\(hour)h"
    }
}

// MARK: - Match History Model & Storage
struct MatchHistoryRecord: Identifiable, Codable {
    let id: UUID
    let date: Date
    let mode: AimMode
    let totalScore: Double
    let shotCount: Int
    let shots: [ShotRecord]

    init(id: UUID = UUID(), date: Date = Date(), mode: AimMode, totalScore: Double, shots: [ShotRecord]) {
        self.id = id
        self.date = date
        self.mode = mode
        self.totalScore = totalScore
        self.shotCount = shots.count
        self.shots = shots
    }
}

final class HistoryManager {
    static let shared = HistoryManager()
    private let key = "OlympicShooting_MatchHistory_V1"

    func loadHistory() -> [MatchHistoryRecord] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let records = try? JSONDecoder().decode([MatchHistoryRecord].self, from: data) else {
            return []
        }
        return records
    }

    func saveMatch(mode: AimMode, shots: [ShotRecord]) {
        guard !shots.isEmpty else { return }
        var current = loadHistory()
        let total = shots.reduce(0.0) { $0 + $1.score }
        let record = MatchHistoryRecord(mode: mode, totalScore: total, shots: shots)
        current.insert(record, at: 0) // Newest first
        if let encoded = try? JSONEncoder().encode(current) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }

    func clearHistory() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

// MARK: - Main Container View
struct ContentView: View {
    @State private var language: AppLanguage = .traditionalChinese
    @State private var isPlaying: Bool = false
    @State private var showInstructions: Bool = false
    @State private var showHistory: Bool = false

    var body: some View {
        ZStack {
            if isPlaying {
                GameView(language: language, onExit: {
                    withAnimation(.easeInOut(duration: 0.25)) { isPlaying = false }
                })
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .trailing)))
            } else {
                MainMenuView(
                    language: $language,
                    onStart: { withAnimation(.easeInOut(duration: 0.25)) { isPlaying = true } },
                    onShowInstructions: { showInstructions = true },
                    onShowHistory: { showHistory = true }
                )
                .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .leading)))
            }
        }
        .sheet(isPresented: $showInstructions) {
            InstructionsSheetView(language: language) { showInstructions = false }
        }
        .sheet(isPresented: $showHistory) {
            MatchHistoryView(language: language) { showHistory = false }
        }
    }
}

// MARK: - Dynamic Olympic Metallic Ripples Background (向量精準同心波紋，波紋間距細密精緻)
struct OlympicMetallicRipplesBackground: View {
    let logoCenter: CGPoint

    var body: some View {
        Canvas { context, size in
            let center = logoCenter.x > 0 ? logoCenter : CGPoint(x: size.width / 2, y: size.height * 0.22)
            let maxRadius = sqrt(size.width * size.width + size.height * size.height)

            // 1. 底層深邃午夜海軍藍
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(Color(red: 0.04, green: 0.07, blue: 0.15))
            )

            // 2. 自 Logo 中心發散的金色漸層光暈
            let radialGlow = Gradient(
                colors: [
                    Color(red: 0.98, green: 0.86, blue: 0.50).opacity(0.85),
                    Color(red: 0.85, green: 0.68, blue: 0.32).opacity(0.55),
                    Color(red: 0.50, green: 0.38, blue: 0.18).opacity(0.35),
                    Color(red: 0.14, green: 0.23, blue: 0.44).opacity(0.60),
                    Color(red: 0.04, green: 0.07, blue: 0.15).opacity(0.95)
                ]
            )
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .radialGradient(radialGlow, center: center, startRadius: 15, endRadius: size.width * 0.95)
            )

            // 3. 幾何精確細緻同心金屬微波紋路（波紋寬度變細、間距縮小為 9pt，更細膩密緻）
            var r: CGFloat = 80.0
            while r < maxRadius {
                let t = r / maxRadius
                let wave = sin(Double(r) * 0.08) * 0.5 + 0.5

                let goldWeight = max(0.0, 1.0 - t * 1.8)
                let blueWeight = min(1.0, t * 1.5)

                let red = (0.95 * goldWeight + 0.25 * blueWeight) * (0.85 + 0.15 * wave)
                let green = (0.82 * goldWeight + 0.38 * blueWeight) * (0.85 + 0.15 * wave)
                let blue = (0.45 * goldWeight + 0.70 * blueWeight) * (0.85 + 0.15 * wave)
                let alpha = (0.22 + 0.25 * wave) * (1.0 - t * 0.45)

                let path = Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
                // 波紋細度收窄：1.2pt ~ 1.8pt
                let lineWidth = 1.2 + 0.8 * (1.0 - t)
                context.stroke(
                    path,
                    with: .color(Color(red: red, green: green, blue: blue).opacity(alpha)),
                    lineWidth: lineWidth
                )

                r += 9.0 // 間距由 16pt 縮小為 9pt，呈現更細密的同心金屬波紋
            }

            // 4. 微細金屬磨砂質感紋理
            var y: CGFloat = 0
            while y < size.height {
                let linePath = Path { p in
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(
                    linePath,
                    with: .color(Color(red: 0.9, green: 0.8, blue: 0.6).opacity(0.025)),
                    lineWidth: 1.0
                )
                y += 4.0
            }
        }
        .drawingGroup()
    }
}

// MARK: - Main Menu View (開始、操作說明、歷史記錄)
struct MainMenuView: View {
    @Binding var language: AppLanguage
    let onStart: () -> Void
    let onShowInstructions: () -> Void
    let onShowHistory: () -> Void

    @State private var logoCenterInScreen: CGPoint = .zero

    private var l10n: L10n { L10n(lang: language) }

    var body: some View {
        ZStack {
            // 背景：向量級極致清晰的金色到深藍同心金屬波紋，保證 100% 以 Logo 為幾何圓心同心平行發散
            OlympicMetallicRipplesBackground(logoCenter: logoCenterInScreen)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 上部主視覺 Logo 與標題區域（固定垂直頂距與固定尺寸，切換中英文絕不位移）
                VStack(spacing: 12) {
                    ZStack {
                        // 金色與科技藍雙色漫射外暈
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color(red: 1.0, green: 0.88, blue: 0.50).opacity(0.40),
                                        Color(red: 0.20, green: 0.55, blue: 0.95).opacity(0.18),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 40,
                                    endRadius: 115
                                )
                            )
                            .frame(width: 215, height: 215)

                        // 官方奧運會徽標誌（精緻金屬浮雕質感 + 磨砂金屬光澤，同心平行）
                        ZStack {
                            Image("OlympicEmblem")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 154, height: 154)

                            // 金屬高光與磨砂質感疊層
                            Image("MetallicMatteTexture")
                                .resizable(resizingMode: .tile)
                                .opacity(0.25)
                                .blendMode(.colorDodge)

                            // 雙層立體金屬光澤高光漸層外圈
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 1.0, green: 0.96, blue: 0.78),
                                            Color(red: 0.85, green: 0.68, blue: 0.35),
                                            Color(red: 0.45, green: 0.32, blue: 0.15),
                                            Color(red: 0.90, green: 0.75, blue: 0.40)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 3.5
                                )

                            Circle()
                                .stroke(Color.white.opacity(0.4), lineWidth: 1.0)
                                .padding(2)
                        }
                        .frame(width: 154, height: 154)
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.7), radius: 18, x: 0, y: 8)
                    }
                    .background(
                        GeometryReader { geo in
                            let frame = geo.frame(in: .global)
                            Color.clear.preference(
                                key: LogoCenterPreferenceKey.self,
                                value: CGPoint(x: frame.midX, y: frame.midY)
                            )
                        }
                    )

                    // 主標題：10米射擊 / 10m SHOOTING（固定高 48pt，切換語言不跳動）
                    ZStack {
                        // 霓虹發光外邊框陰影層（Cyan / Electric Blue Glow）
                        Text(l10n.appTitle)
                            .font(language == .traditionalChinese
                                  ? .custom("DelaGothicOne-Regular", size: 50)
                                  : .custom("Orbitron-Bold", size: 40))
                            .foregroundColor(Color(red: 0.0, green: 0.95, blue: 0.85).opacity(0.75))
                            .blur(radius: 8)
                            .offset(y: 1)

                        // 核心發光文字：冰藍過渡至純白，並帶有電光青藍描邊
                        Text(l10n.appTitle)
                            .font(language == .traditionalChinese
                                  ? .custom("DelaGothicOne-Regular", size: 50)
                                  : .custom("Orbitron-Bold", size: 40))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color.white,
                                        Color(red: 0.85, green: 0.98, blue: 1.0),
                                        Color(red: 0.40, green: 0.88, blue: 0.95)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: Color(red: 0.0, green: 0.85, blue: 0.95).opacity(0.9), radius: 4, x: 0, y: 0)
                            .shadow(color: Color.black.opacity(0.7), radius: 6, x: 0, y: 3)
                    }
                    .frame(height: 48)

                    // 副標題：射擊模擬器 / SHOOTING SIMULATOR（固定高 26pt，切換語言不跳動）
                    Text(l10n.appSubtitle)
                        .font(language == .traditionalChinese
                              ? .custom("DelaGothicOne-Regular", size: 30)
                              : .custom("Orbitron-Bold", size: 20))
                        .tracking(language == .traditionalChinese ? 3.0 : 2.0)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.92, blue: 0.65),
                                    Color(red: 0.85, green: 0.72, blue: 0.40)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: Color(red: 0.95, green: 0.75, blue: 0.30).opacity(0.7), radius: 5, x: 0, y: 0)
                        .shadow(color: Color.black.opacity(0.65), radius: 4, x: 0, y: 2)
                        .frame(height: 26)
                }
                .padding(.top, 18)

                Spacer(minLength: 20)

                // 語言切換選單（Language Segmented Control，切換無跳躍）
                VStack(spacing: 5) {
                    Text(l10n.languageLabel)
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.85))
                        .shadow(color: Color.black.opacity(0.5), radius: 2, x: 0, y: 1)
                    Picker("Language", selection: $language) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.rawValue).tag(lang)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 220)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.16)))
                }
                .padding(.bottom, 16)

                // 金屬磨砂質感按鈕群組（固定高度排列）
                VStack(spacing: 12) {
                    // Start Button (主按鈕：深邃寶藍鈦金屬 + 微磨砂紋理 + 金色微光高光描邊)
                    Button(action: onStart) {
                        ZStack {
                            // 金屬磨砂紋理覆蓋層
                            Image("MetallicMatteTexture")
                                .resizable(resizingMode: .tile)
                                .opacity(0.18)
                                .blendMode(.overlay)

                            HStack(spacing: 10) {
                                Image(systemName: "scope")
                                    .font(.system(size: 19, weight: .heavy))
                                Text(l10n.startButton)
                                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .shadow(color: Color.black.opacity(0.5), radius: 2, x: 0, y: 1)
                        }
                        .frame(maxWidth: 280)
                        .frame(height: 52)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.22, green: 0.42, blue: 0.72),
                                    Color(red: 0.11, green: 0.22, blue: 0.45)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(15)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 1.0, green: 0.92, blue: 0.70).opacity(0.80),
                                            Color(red: 0.30, green: 0.50, blue: 0.85).opacity(0.30)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 1.3
                                )
                        )
                        .shadow(color: Color(red: 0.08, green: 0.16, blue: 0.35).opacity(0.6), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(PressableButtonStyle())

                    // Match History Button (啞光拉絲銀金屬 + 磨砂紋理 + 精密刻線)
                    Button(action: onShowHistory) {
                        ZStack {
                            // 金屬磨砂紋理覆蓋層
                            Image("MetallicMatteTexture")
                                .resizable(resizingMode: .tile)
                                .opacity(0.22)
                                .blendMode(.multiply)

                            HStack(spacing: 9) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 16.5, weight: .bold))
                                Text(l10n.historyButton)
                                    .font(.system(size: 15.5, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(Color(red: 0.14, green: 0.18, blue: 0.26))
                        }
                        .frame(maxWidth: 280)
                        .frame(height: 49)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.93, green: 0.94, blue: 0.96),
                                    Color(red: 0.78, green: 0.81, blue: 0.85)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(15)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.white, Color(red: 0.7, green: 0.75, blue: 0.82)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 1.2
                                )
                        )
                        .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(PressableButtonStyle())

                    // Instructions Button (陽極氧化啞光深灰金屬 + 磨砂質感)
                    Button(action: onShowInstructions) {
                        ZStack {
                            Image("MetallicMatteTexture")
                                .resizable(resizingMode: .tile)
                                .opacity(0.25)
                                .blendMode(.overlay)

                            HStack(spacing: 8) {
                                Image(systemName: "info.circle.fill")
                                    .font(.system(size: 15.5, weight: .bold))
                                Text(l10n.instructionsButton)
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .shadow(color: Color.black.opacity(0.5), radius: 2, x: 0, y: 1)
                        }
                        .frame(maxWidth: 280)
                        .frame(height: 48)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.35, green: 0.39, blue: 0.46),
                                    Color(red: 0.22, green: 0.25, blue: 0.31)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(15)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.40),
                                            Color.white.opacity(0.12)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 1.1
                                )
                        )
                        .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 3)
                    }
                    .buttonStyle(PressableButtonStyle())
                }

                Spacer(minLength: 15)
            }
            .padding(.horizontal, 24)
        }
        .onPreferenceChange(LogoCenterPreferenceKey.self) { center in
            if center != .zero {
                logoCenterInScreen = center
            }
        }
    }
}

// MARK: - PreferenceKey for Logo Center Point
struct LogoCenterPreferenceKey: PreferenceKey {
    static var defaultValue: CGPoint = .zero
    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {
        let next = nextValue()
        if next != .zero {
            value = next
        }
    }
}

// MARK: - Game View (With Finish Match & Save)
struct GameView: View {
    let language: AppLanguage
    let onExit: () -> Void

    @State private var aimMode: AimMode = .pistol
    @State private var maxMarksCapacity: Int = 5
    @State private var allMatchShots: [ShotRecord] = []
    @State private var visibleTargetShots: [ShotRecord] = []
    @State private var lastShotScore: Double? = nil
    @State private var showScorecard: Bool = false
    @State private var showFinishDialog: Bool = false
    @State private var showWeaponSelectDialog: Bool = true

    // Aiming State
    @State private var isHoldingBreath: Bool = false
    @State private var breathStartTime: Date? = nil
    @State private var isShooting: Bool = false
    @State private var showScorePopup: Bool = false
    @State private var popupScore: Double = 0.0
    @State private var recoilOffset: CGSize = .zero
    @State private var lastShotTime: Date? = nil
    @State private var targetCenterInScreen: CGPoint = .zero

    private let targetRadius: CGFloat = 110.0
    private var l10n: L10n { L10n(lang: language) }

    private var currentSeriesNumber: Int {
        (allMatchShots.count / 10) + 1
    }

    private var currentSeriesShots: [ShotRecord] {
        let currentSeriesIndex = (allMatchShots.count / 10)
        let startIndex = currentSeriesIndex * 10
        guard startIndex < allMatchShots.count else { return [] }
        return Array(allMatchShots[startIndex..<allMatchShots.count])
    }

    private var currentSeriesSubtotal: Double {
        currentSeriesShots.reduce(0.0) { $0 + $1.score }
    }

    private var priorSeriesSubtotal: Double? {
        guard currentSeriesNumber > 1 else { return nil }
        let priorIndex = currentSeriesNumber - 2
        let start = priorIndex * 10
        let end = min(start + 10, allMatchShots.count)
        guard start < allMatchShots.count else { return nil }
        return allMatchShots[start..<end].reduce(0.0) { $0 + $1.score }
    }

    private var grandTotalScore: Double {
        allMatchShots.reduce(0.0) { $0 + $1.score }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 10) {
                // Top Header: Back, Mode Badge, 12/60, Scorecard & Finish
                olympicDashboardHeader
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
                    .zIndex(10)

                // S1 S2 & Grand Total (Enlarged, Left) + Real-time Target Magnifier (Right)
                dashboardScoreAndMagnifierRow
                    .padding(.horizontal, 12)
                    .padding(.top, 4)

                Spacer(minLength: 2)

                // Central Target Area with Swaying Sight
                TimelineView(.animation) { timeline in
                    let now = timeline.date.timeIntervalSinceReferenceDate
                    let effectiveHolding = isBreathHoldingActive(now: timeline.date)
                    let sway = calculateSway(at: now, mode: aimMode, isHoldingBreath: effectiveHolding)
                    let entryDrop = entryDropOffset(now: timeline.date)

                    ZStack {
                        // Target Card (Centered on background yellow ripple)
                        TargetBoardView(
                            mode: aimMode,
                            radius: targetRadius,
                            shots: visibleTargetShots
                        )
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: LogoCenterPreferenceKey.self,
                                    value: CGPoint(x: geo.frame(in: .global).midX, y: geo.frame(in: .global).midY)
                                )
                            }
                        )

                        // Sights Overlay (包含後座力漂移 recoilOffset 與由上往下落入瞄區的 entryDrop)
                        sightOverlayView
                            .offset(
                                x: sway.x + recoilOffset.width,
                                y: visualSightOffsetY + entryDrop + sway.y + recoilOffset.height
                            )
                            .allowsHitTesting(false)

                        // Muzzle Flash
                        if isShooting {
                            Circle()
                                .fill(Color.white.opacity(0.4))
                                .frame(width: targetRadius * 2, height: targetRadius * 2)
                        }

                        // Pop-up callout
                        if showScorePopup {
                            scorePopupView
                        }
                    }
                    .frame(width: targetRadius * 2 + 16, height: targetRadius * 2 + 16)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            // 按住靶面立即進入屏息穩瞄，取消手動拖拉
                            if !isHoldingBreath {
                                isHoldingBreath = true
                                breathStartTime = Date()
                            }
                        }
                        .onEnded { _ in
                            // 鬆開瞬間立即擊發！先依據當前屏息與下壓進度擊發，再重置瞄準狀態
                            if isHoldingBreath {
                                fireShot()
                                isHoldingBreath = false
                                breathStartTime = nil
                            }
                        }
                )

                Spacer(minLength: 4)

                // 底部操作狀態提示（已取消重置鍵）
                bottomActionIndicatorBar
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }

            // 自訂正中央置中選擇視窗（置中顯示、精美金屬雙色質感）
            if showWeaponSelectDialog {
                Color.black.opacity(0.48)
                    .ignoresSafeArea()
                    .transition(.opacity)

                VStack(spacing: 18) {
                    VStack(spacing: 6) {
                        Image(systemName: "scope")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundColor(Color(red: 0.88, green: 0.68, blue: 0.22))

                        Text(l10n.selectWeaponTitle)
                            .font(.system(size: 20, weight: .black))
                            .foregroundColor(.black)

                        Text(l10n.selectWeaponMessage)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.black.opacity(0.65))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }

                    VStack(spacing: 12) {
                        Button(action: {
                            aimMode = .pistol
                            withAnimation(.easeInOut(duration: 0.22)) {
                                showWeaponSelectDialog = false
                            }
                        }) {
                            HStack(spacing: 12) {
                                WNotchShape()
                                    .fill(Color.white)
                                    .frame(width: 24, height: 10)
                                Text(l10n.pistolMode)
                                    .font(.system(size: 16, weight: .heavy))
                                Spacer()
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.system(size: 18))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(LinearGradient(
                                        colors: [Color(red: 0.22, green: 0.28, blue: 0.40), Color(red: 0.12, green: 0.16, blue: 0.25)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 3)
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            aimMode = .rifle
                            withAnimation(.easeInOut(duration: 0.22)) {
                                showWeaponSelectDialog = false
                            }
                        }) {
                            HStack(spacing: 12) {
                                Circle()
                                    .stroke(Color.white, lineWidth: 2.2)
                                    .frame(width: 17, height: 17)
                                Text(l10n.rifleMode)
                                    .font(.system(size: 16, weight: .heavy))
                                Spacer()
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.system(size: 18))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(LinearGradient(
                                        colors: [Color(red: 0.18, green: 0.35, blue: 0.32), Color(red: 0.10, green: 0.22, blue: 0.20)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 3)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 22)
                .frame(maxWidth: 310)
                .background(
                    RoundedRectangle(cornerRadius: 22)
                        .fill(Color(red: 0.98, green: 0.97, blue: 0.95))
                        .shadow(color: Color.black.opacity(0.35), radius: 28, x: 0, y: 14)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(
                            LinearGradient(
                                colors: [Color(red: 0.88, green: 0.72, blue: 0.38), Color(red: 0.65, green: 0.50, blue: 0.25)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .transition(.scale(scale: 0.9).combined(with: .opacity))
                .zIndex(100)
            }

            // 自訂成績單全螢幕彈窗 (直接置於 ZStack，無空 overlay 攔截點擊)
            if showScorecard {
                ZStack {
                    Color.black.opacity(0.55)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) { showScorecard = false }
                        }

                    OlympicScorecardView(
                        language: language,
                        allShots: allMatchShots,
                        grandTotal: grandTotalScore
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) { showScorecard = false }
                    }
                    .frame(maxWidth: 360, maxHeight: 600)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.35), radius: 20, x: 0, y: 8)
                    .padding(16)
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
                }
                .zIndex(200)
            }

            // 自訂結束比賽確認視窗 (直接置於 ZStack，無空 overlay 攔截點擊)
            if showFinishDialog {
                ZStack {
                    Color.black.opacity(0.55)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) { showFinishDialog = false }
                        }

                    finishConfirmationOverlay
                        .transition(.scale(scale: 0.92).combined(with: .opacity))
                }
                .zIndex(250)
            }
        }
        .background(Color(red: 0.93, green: 0.86, blue: 0.70).ignoresSafeArea())
        .onPreferenceChange(LogoCenterPreferenceKey.self) { center in
            if center != .zero {
                targetCenterInScreen = center
            }
        }
    }

    private var visualSightOffsetY: CGFloat {
        switch aimMode {
        case .pistol:
            // 手槍瞄準點微調至 5 環與 6 環之間（約 78.0pt）
            return 78.0
        case .rifle:
            return 0.0
        }
    }

    // MARK: - Olympic Dashboard Header (Back, Mode Badge, Shot Count, Scorecard & Finish)
    private var olympicDashboardHeader: some View {
        HStack(spacing: 8) {
            Button(action: {
                if allMatchShots.isEmpty {
                    onExit()
                } else {
                    showFinishDialog = true
                }
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "chevron.left")
                    Text(l10n.backToMenu)
                }
                .font(.system(size: 11.5, weight: .bold))
                .foregroundColor(Color.black.opacity(0.8))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.black.opacity(0.08)))
            }
            .buttonStyle(.plain)

            // Mode Badge (10m Pistol / 10m Rifle Locked)
            HStack(spacing: 5) {
                if aimMode == .pistol {
                    WNotchShape()
                        .fill(Color.black)
                        .frame(width: 18, height: 8)
                    Text(l10n.pistolMode)
                        .font(.system(size: 11.5, weight: .black))
                } else {
                    Circle()
                        .stroke(Color.black, lineWidth: 1.8)
                        .frame(width: 12, height: 12)
                    Text(l10n.rifleMode)
                        .font(.system(size: 11.5, weight: .black))
                }
                Image(systemName: "lock.fill")
                    .font(.system(size: 8))
                    .foregroundColor(Color.black.opacity(0.45))
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.06)))

            Spacer()

            // Total Shots Count: e.g. 12/60
            Text("\(allMatchShots.count)/60")
                .font(.system(size: 12.5, weight: .black, design: .monospaced))
                .foregroundColor(Color.black.opacity(0.75))

            // Scorecard Button (以 highPriorityGesture 確保 100% 秒級響應)
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    showScorecard = true
                }
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "list.clipboard.fill")
                        .font(.system(size: 11.5))
                    Text(l10n.scorecardBtn)
                        .font(.system(size: 10.5, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 7).fill(Color(red: 0.18, green: 0.35, blue: 0.65)))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .highPriorityGesture(TapGesture().onEnded {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    showScorecard = true
                }
            })

            // Finish Button (以 highPriorityGesture 確保 100% 秒級響應)
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    showFinishDialog = true
                }
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 11))
                    Text(l10n.finishBtn)
                }
                .font(.system(size: 10.5, weight: .heavy))
                .foregroundColor(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 7).fill(Color(red: 0.85, green: 0.25, blue: 0.15)))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .highPriorityGesture(TapGesture().onEnded {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    showFinishDialog = true
                }
            })
        }
    }

    // MARK: - S1 S2 & Grand Total (Left) + Real-time Target Magnifier (Right)
    private var dashboardScoreAndMagnifierRow: some View {
        HStack(spacing: 8) {
            leftScoreDashboard
            rightMagnifierHUD
        }
        .frame(height: 98)
    }

    // MARK: - Left: Grand Total & 3x2 Series Table + Capacity Picker
    private var leftScoreDashboard: some View {
        VStack(spacing: 3) {
            HStack(alignment: .center, spacing: 6) {
                // 總分 (大賽總分放大顯示)
                VStack(alignment: .leading, spacing: 0) {
                    Text(language == .traditionalChinese ? "大賽總分" : "TOTAL")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color.black.opacity(0.55))

                    Text(String(format: "%.1f", grandTotalScore))
                        .font(.system(size: 21, weight: .black, design: .monospaced))
                        .foregroundColor(Color(red: 0.86, green: 0.16, blue: 0.10))
                        .minimumScaleFactor(0.75)
                        .lineLimit(1)
                }
                .frame(width: 66, alignment: .leading)

                // 分隔線
                Rectangle()
                    .fill(Color.black.opacity(0.12))
                    .frame(width: 1, height: 38)

                // 3 * 2 表格 (S1 ~ S6 各組得分)
                VStack(spacing: 1.5) {
                    HStack(spacing: 4) {
                        seriesCell(index: 0) // S1
                        seriesCell(index: 1) // S2
                    }
                    HStack(spacing: 4) {
                        seriesCell(index: 2) // S3
                        seriesCell(index: 3) // S4
                    }
                    HStack(spacing: 4) {
                        seriesCell(index: 4) // S5
                        seriesCell(index: 5) // S6
                    }
                }
                .frame(maxWidth: .infinity)
            }

            Spacer(minLength: 0)

            // 靶面彈印選擇 (Capacity: 5發 / 10發)
            HStack(spacing: 4) {
                Text(l10n.maxShotsLabel)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color.black.opacity(0.6))
                    .lineLimit(1)

                Picker("Capacity", selection: $maxMarksCapacity) {
                    Text(l10n.oneShot).tag(1)
                    Text(l10n.fiveShots).tag(5)
                    Text(l10n.tenShots).tag(10)
                }
                .pickerStyle(.segmented)
                .frame(height: 20)
                .onChange(of: maxMarksCapacity) { _, newCap in
                    if visibleTargetShots.count > newCap {
                        visibleTargetShots = Array(visibleTargetShots.suffix(newCap))
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 11)
                .fill(Color.white.opacity(0.88))
                .shadow(color: Color.black.opacity(0.06), radius: 3, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11)
                .stroke(Color.black.opacity(0.1), lineWidth: 1)
        )
    }

    private func seriesCell(index: Int) -> some View {
        let sNum = index + 1
        let score = seriesScore(seriesIndex: index)
        let isCurrent = (currentSeriesNumber == sNum && allMatchShots.count < 60)

        return HStack(spacing: 1.5) {
            Text("S\(sNum):")
                .font(.system(size: 8.5, weight: .bold))
                .foregroundColor(isCurrent ? Color(red: 0.1, green: 0.38, blue: 0.85) : Color.black.opacity(0.55))

            if let val = score {
                Text(String(format: "%.1f", val))
                    .font(.system(size: 9, weight: isCurrent ? .heavy : .bold, design: .monospaced))
                    .foregroundColor(isCurrent ? Color(red: 0.1, green: 0.38, blue: 0.85) : Color.black.opacity(0.85))
            } else {
                Text("--.-")
                    .font(.system(size: 8.5, weight: .regular, design: .monospaced))
                    .foregroundColor(Color.black.opacity(0.25))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func seriesScore(seriesIndex: Int) -> Double? {
        let start = seriesIndex * 10
        guard start < allMatchShots.count else { return nil }
        let end = min(start + 10, allMatchShots.count)
        let shots = allMatchShots[start..<end]
        guard !shots.isEmpty else { return nil }
        return shots.reduce(0.0) { $0 + $1.score }
    }

    // MARK: - Right: Real-time Magnifier HUD (Zoomed 5 or 10 marks + Latest shot score & deviation info)
    private var rightMagnifierHUD: some View {
        VStack(spacing: 3) {
            // Header: 🔍 即時放大鏡 / MAGNIFIER
            HStack(spacing: 3) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundColor(Color(red: 0.2, green: 0.45, blue: 0.8))
                Text(language == .traditionalChinese ? "即時放大鏡" : "MAGNIFIER")
                    .font(.system(size: 8.5, weight: .heavy))
                    .foregroundColor(Color.black.opacity(0.6))
            }

            // Real-time Zoomed Lens View (58x58 circle)
            // 手槍與步槍放大鏡均看到 8 環以內（手槍 scale 0.78，步槍 scale 2.5）
            ZStack {
                // Zoomed Target Board View
                TargetBoardView(
                    mode: aimMode,
                    radius: targetRadius,
                    shots: visibleTargetShots,
                    showScoreTag: false
                )
                .scaleEffect(aimMode == .rifle ? 3.2 : 0.78)
                .frame(width: 58, height: 58)
                .clipShape(Circle())
                .contentShape(Circle())

                // Fine Crosshair Reticle
                Path { p in
                    p.move(to: CGPoint(x: 29, y: 0))
                    p.addLine(to: CGPoint(x: 29, y: 58))
                    p.move(to: CGPoint(x: 0, y: 29))
                    p.addLine(to: CGPoint(x: 58, y: 29))
                }
                .stroke(Color.red.opacity(0.35), lineWidth: 0.75)

                // Outer Metallic Bezel
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 0.90, green: 0.92, blue: 0.95),
                                Color(red: 0.55, green: 0.60, blue: 0.68),
                                Color(red: 0.25, green: 0.28, blue: 0.35)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2.2
                    )
                    .shadow(color: Color.black.opacity(0.25), radius: 2)

                // Lens Reflection
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.26), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .center
                        )
                    )
            }
            .frame(width: 58, height: 58)
            .contentShape(Circle())
            .allowsHitTesting(false)

            // Below the lens: Score & Deviation Info of the last shot fired
            if let last = allMatchShots.last {
                VStack(spacing: 1) {
                    HStack(spacing: 3) {
                        Text(String(format: "%.1f", last.score))
                            .font(.system(size: 13.5, weight: .black, design: .monospaced))
                            .foregroundColor(last.score >= 10.9 ? Color(red: 0.95, green: 0.65, blue: 0.0) : Color(red: 0.88, green: 0.15, blue: 0.1))

                        if last.isPerfect {
                            Text("◎")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color.orange)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 8.5, weight: .black))
                                .foregroundColor(.blue)
                                .rotationEffect(last.deviationAngle)
                        }
                    }

                    HStack(spacing: 3) {
                        let distPt = sqrt(last.offsetX * last.offsetX + last.offsetY * last.offsetY)
                        let distMm = (last.mode == .pistol) ? (distPt / (targetRadius / 77.75)) : (distPt / ((targetRadius * 0.30) / 22.75))
                        Text(last.isPerfect ? (language == .traditionalChinese ? "正中 0.0mm" : "Center 0.0mm") : String(format: "%.2fmm", distMm))
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.black.opacity(0.7))

                        if !last.isPerfect {
                            Text(last.clockDirection(lang: language))
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(Color(red: 0.1, green: 0.45, blue: 0.2))
                        }
                    }
                }
            } else {
                VStack(spacing: 1) {
                    Text("--.-")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.black.opacity(0.35))
                    Text(language == .traditionalChinese ? "待擊發" : "Ready")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(Color.black.opacity(0.4))
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .frame(width: 108)
        .background(
            RoundedRectangle(cornerRadius: 11)
                .fill(Color.white.opacity(0.88))
                .shadow(color: Color.black.opacity(0.06), radius: 3, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11)
                .stroke(Color.black.opacity(0.1), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var sightOverlayView: some View {
        switch aimMode {
        case .rifle:
            RifleConcentricSightView()
        case .pistol:
            PistolExtraLargeWSightView()
        }
    }

    // 底部操作狀態指示條（已完全移除重置鍵）
    private var bottomActionIndicatorBar: some View {
        HStack(spacing: 8) {
            Image(systemName: isHoldingBreath ? "scope" : "hand.tap.fill")
                .foregroundColor(isHoldingBreath ? .blue : Color.black.opacity(0.6))
                .font(.system(size: 14, weight: .bold))

            Text(isHoldingBreath ? l10n.holdingBreath : l10n.holdBreath)
                .font(.system(size: 12.5, weight: .bold))
                .foregroundColor(isHoldingBreath ? Color.blue : Color.black.opacity(0.75))

            Spacer()

            if isHoldingBreath {
                Text("RELEASE TO FIRE")
                    .font(.system(size: 10.5, weight: .black, design: .monospaced))
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHoldingBreath ? Color.blue.opacity(0.12) : Color.black.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isHoldingBreath ? Color.blue.opacity(0.35) : Color.black.opacity(0.12), lineWidth: 1)
        )
    }

    private var scorePopupView: some View {
        VStack(spacing: 1) {
            Text(String(format: "%.1f", popupScore))
                .font(.system(size: 27, weight: .heavy, design: .rounded))
                .foregroundColor(popupScore >= 10.9 ? Color(red: 1.0, green: 0.84, blue: 0.0) : .white)
            if popupScore >= 10.9 {
                Text("★ PERFECT 10.9 ★")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(Color(red: 1.0, green: 0.9, blue: 0.3))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.85)))
        .offset(y: -targetRadius * 0.7)
    }

    private func isBreathHoldingActive(now: Date) -> Bool {
        guard isHoldingBreath, let start = breathStartTime else { return false }
        return now.timeIntervalSince(start) < 7.0
    }

    /// 自然漂移與微震晃動（長按屏息時晃動適度擴大：手槍在 7 環範圍內，步槍在 8 環範圍內）
    private func calculateSway(at time: TimeInterval, mode: AimMode, isHoldingBreath: Bool) -> CGPoint {
        let t = time
        let driftX = sin(t * 0.68) * 7.65 + sin(t * 1.37 + 1.2) * 3.6
        let driftY = cos(t * 0.52 + 0.7) * 9.0 + cos(t * 1.15 + 2.1) * 4.05
        let tremorX = sin(t * 3.7 + 0.4) * 1.08 + sin(t * 7.1) * 0.36
        let tremorY = cos(t * 3.2 + 1.1) * 1.08 + cos(t * 6.1) * 0.36

        var x = (driftX + tremorX) * (mode == .pistol ? 1.88 : 0.72)
        var y = (driftY + tremorY) * (mode == .pistol ? 1.88 : 0.72)

        if isHoldingBreath {
            // 原本壓至 0.25（晃動過小几乎都在 10.5 以上）
            // 現調整為手槍約在 7 環範圍（最大振幅約 33~36pt，乘數 0.78），步槍在 8 環範圍（最大振幅約 13~14pt，乘數 0.65）
            // 手槍屏息時振幅適度收斂至 9 環以內（factor = 0.86），步槍則保持 8 環以內精密微動（factor = 0.65）
            let factor = (mode == .pistol) ? 0.86 : 0.65
            x *= factor
            y *= factor
        }
        return CGPoint(x: x, y: y)
    }

    /// 真實射擊下壓瞄準（射完或未長按時，準星回到上方起始點飄移；長按後緩緩下壓，時間約 2.8 秒平穩入瞄）
    private func entryDropOffset(now: Date) -> CGFloat {
        let topRestY: CGFloat = -52.0

        if isHoldingBreath, let start = breathStartTime {
            // 長按瞄準中：從上方緩緩往下壓入瞄區（約 2.8 秒）
            let elapsed = max(0.0, now.timeIntervalSince(start))
            let entryDuration: Double = 2.8
            if elapsed >= entryDuration {
                return 0.0
            }
            let progress = elapsed / entryDuration
            let easeOut = 1.0 - pow(1.0 - progress, 3)
            return topRestY * CGFloat(1.0 - easeOut)
        } else if let shotTime = lastShotTime {
            // 剛射擊完（鬆開後）：先輕微後座跳動，然後在約 1.2 秒內慢慢升回上方起始點飄移
            let elapsed = max(0.0, now.timeIntervalSince(shotTime))
            let returnDuration: Double = 1.2
            if elapsed >= returnDuration {
                return topRestY
            }
            let progress = elapsed / returnDuration
            // 平滑升起回頂部
            let ease = 1.0 - pow(1.0 - progress, 2)
            return topRestY * CGFloat(ease)
        } else {
            // 初始待命：在上方起始點飄移
            return topRestY
        }
    }

    private func fireShot() {
        withAnimation(.easeOut(duration: 0.05)) { isShooting = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.easeIn(duration: 0.1)) { isShooting = false }
        }

        SoundManager.shared.playGunshot()

        let fireDate = Date()
        lastShotTime = fireDate
        let now = fireDate.timeIntervalSinceReferenceDate
        let effectiveBreath = isBreathHoldingActive(now: fireDate)
        let sway = calculateSway(at: now, mode: aimMode, isHoldingBreath: effectiveBreath)
        let entryDrop = entryDropOffset(now: fireDate)

        let impactX = sway.x
        let impactY = entryDrop + sway.y
        let impactPoint = CGPoint(x: impactX, y: impactY)

        // 柔和後座力模擬（輕度反射）：瞬間隨前進方向微幅跳動
        let deltaT = 0.05
        let swayNext = calculateSway(at: now + deltaT, mode: aimMode, isHoldingBreath: effectiveBreath)
        let dirX = swayNext.x - sway.x
        let dirY = swayNext.y - sway.y
        let dirLen = max(0.001, sqrt(dirX * dirX + dirY * dirY))
        let recoilPower: CGFloat = (aimMode == .pistol) ? 9.0 : 5.5 // 輕量後座跳動
        let kickX = (dirX / dirLen) * recoilPower
        let kickY = (dirY / dirLen) * recoilPower - 4.0 // 輕微向上

        withAnimation(.easeOut(duration: 0.06)) {
            recoilOffset = CGSize(width: kickX, height: kickY)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            withAnimation(.easeOut(duration: 0.20)) {
                recoilOffset = .zero
            }
        }
        let dist = sqrt(impactX * impactX + impactY * impactY)

        let computedScore: Double
        if aimMode == .pistol {
            // ISSF 10m 手槍靶標準（17x17cm，1環半徑 77.75mm 對應 targetRadius = 110.0pt）
            // 子彈直徑 4.5mm（半徑 2.25mm）
            // 倒數第二個環為 10 環（直徑 11.5mm，半徑 5.75mm）；最內環為 10.9 環
            // 子彈外圍碰到 10 分環外圈即達 10.0 分：
            // 子彈中心距離靶心 = 10環半徑(5.75mm) + 子彈半徑(2.25mm) = 8.00mm
            // 每減少 0.8mm 多獲得 0.1 分（至 10.9 滿分）；每增加 0.8mm 扣 0.1 分
            let ptPerMm: CGFloat = targetRadius / 77.75
            let distMm = Double(dist / ptPerMm)
            let stepMm: Double = 0.80
            let maxTouchRadiusMm: Double = 77.75 + 2.25 // 80.00mm（碰觸1環外緣）

            if distMm > maxTouchRadiusMm {
                computedScore = 0.0
            } else if distMm <= stepMm {
                // 距離 <= 0.80mm 為 10.9 滿分
                computedScore = 10.9
            } else {
                let subdivisions = ceil((distMm - 1e-7) / stepMm)
                let raw = 11.0 - subdivisions * 0.1
                computedScore = max(0.0, min(10.9, (raw * 10.0).rounded() / 10.0))
            }
        } else {
            // ISSF 10m 步槍靶標準（1環半徑 22.75mm 對應 effectiveRadius = 33.0pt）
            // 子彈直徑 4.5mm（半徑 2.25mm）
            // 10.0分環為直徑 0.5mm 點（半徑 0.25mm）
            // 子彈外圍碰到 10 分點即達 10.0 分：
            // 子彈中心距離靶心 = 10分點半徑(0.25mm) + 子彈半徑(2.25mm) = 2.50mm
            // 每減少 0.25mm 多獲得 0.1 分（至 10.9 滿分）；每增加 0.25mm 扣 0.1 分
            let effectiveRadius = targetRadius * 0.30
            let ptPerMm: CGFloat = effectiveRadius / 22.75
            let distMm = Double(dist / ptPerMm)
            let stepMm: Double = 0.25
            let maxTouchRadiusMm: Double = 22.75 + 2.25 // 25.00mm（碰觸1環外緣）

            if distMm > maxTouchRadiusMm {
                computedScore = 0.0
            } else if distMm <= stepMm {
                // 距離 <= 0.25mm 為 10.9 滿分
                computedScore = 10.9
            } else {
                let subdivisions = ceil((distMm - 1e-7) / stepMm)
                let raw = 11.0 - subdivisions * 0.1
                computedScore = max(0.0, min(10.9, (raw * 10.0).rounded() / 10.0))
            }
        }
        let newShot = ShotRecord(
            offset: impactPoint,
            score: computedScore,
            mode: aimMode,
            shotNumber: allMatchShots.count + 1
        )

        allMatchShots.append(newShot)

        // 靶印選擇5時，射完第六發把前面5發清空；選擇10時，射完第11發把前面10發清空
        if visibleTargetShots.count >= maxMarksCapacity {
            visibleTargetShots.removeAll()
        }
        visibleTargetShots.append(newShot)

        lastShotScore = computedScore
        popupScore = computedScore
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { showScorePopup = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.3)) { showScorePopup = false }
        }
    }

    // 自訂結束比賽確認對話框
    private var finishConfirmationOverlay: some View {
        VStack(spacing: 16) {
            Image(systemName: "flag.checkered.circle.fill")
                .font(.system(size: 38))
                .foregroundColor(Color(red: 0.90, green: 0.25, blue: 0.20))

            Text(allMatchShots.isEmpty ? (language == .traditionalChinese ? "結束遊戲" : "Quit Game") : l10n.finishTitle)
                .font(.system(size: 19, weight: .black))
                .foregroundColor(.black)

            Text(allMatchShots.isEmpty ?
                 (language == .traditionalChinese ? "尚未進行任何擊發，確定要返回主選單嗎？" : "No shots fired yet. Return to main menu?") :
                 (language == .traditionalChinese ? "本場比賽共擊發 \(allMatchShots.count) 發，總分 \(String(format: "%.1f", grandTotalScore)) 分。請選擇處理方式：" : "Total \(allMatchShots.count) shots fired, Total Score \(String(format: "%.1f", grandTotalScore)). Please select an option:"))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.black.opacity(0.68))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            VStack(spacing: 9) {
                if !allMatchShots.isEmpty {
                    Button(action: {
                        showFinishDialog = false
                        finishAndSaveMatch()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.down.fill")
                            Text(l10n.saveAndExit)
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(red: 0.18, green: 0.65, blue: 0.35)))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                Button(action: {
                    showFinishDialog = false
                    onExit()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.uturn.left.circle.fill")
                        Text(allMatchShots.isEmpty ? (language == .traditionalChinese ? "返回主選單" : "Return to Menu") : l10n.exitWithoutSaving)
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(red: 0.85, green: 0.25, blue: 0.20)))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        showFinishDialog = false
                    }
                }) {
                    Text(l10n.cancel)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundColor(Color.black.opacity(0.65))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.06)))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(22)
        .frame(width: 300)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.28), radius: 18, x: 0, y: 6)
        )
    }

        private func finishAndSaveMatch() {
        HistoryManager.shared.saveMatch(mode: aimMode, shots: allMatchShots)
        onExit()
    }
}

// MARK: - Match History View (查詢已結束練習或比賽)
struct MatchHistoryView: View {
    let language: AppLanguage
    let onClose: () -> Void

    @State private var history: [MatchHistoryRecord] = []
    @State private var selectedRecord: MatchHistoryRecord? = nil

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.94, green: 0.91, blue: 0.85).ignoresSafeArea()

                if history.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 44))
                            .foregroundColor(Color.black.opacity(0.3))
                        Text(language == .traditionalChinese ? "尚無已結束的射擊記錄" : "No match history recorded yet.")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Color.black.opacity(0.5))
                    }
                    .padding(30)
                } else {
                    List {
                        ForEach(history) { match in
                            Button(action: { selectedRecord = match }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 6) {
                                            Text(match.mode.rawValue)
                                                .font(.system(size: 13, weight: .bold))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Capsule().fill(match.mode == .pistol ? Color.orange.opacity(0.2) : Color.blue.opacity(0.2)))
                                            Text(formattedDate(match.date))
                                                .font(.system(size: 12))
                                                .foregroundColor(Color.black.opacity(0.55))
                                        }

                                        Text("\(language == .traditionalChinese ? "完成發數:" : "Shots:") \(match.shotCount) 發")
                                            .font(.system(size: 12))
                                            .foregroundColor(Color.black.opacity(0.65))
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(String(format: "%.1f", match.totalScore))
                                            .font(.system(size: 20, weight: .black, design: .monospaced))
                                            .foregroundColor(Color(red: 0.85, green: 0.15, blue: 0.1))
                                        Text(language == .traditionalChinese ? "總分" : "Total")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundColor(Color.black.opacity(0.5))
                                    }

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(Color.black.opacity(0.3))
                                        .padding(.leading, 4)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .onDelete(perform: deleteHistoryItem)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(language == .traditionalChinese ? "歷史射擊記錄" : "Match History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !history.isEmpty {
                        Button(language == .traditionalChinese ? "清空全部" : "Clear All") {
                            HistoryManager.shared.clearHistory()
                            history = []
                        }
                        .foregroundColor(.red)
                        .font(.system(size: 13, weight: .medium))
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(language == .traditionalChinese ? "關閉" : "Close", action: onClose)
                        .font(.system(size: 15, weight: .bold))
                }
            }
            .onAppear {
                history = HistoryManager.shared.loadHistory()
            }
            .sheet(item: $selectedRecord) { match in
                OlympicScorecardView(
                    language: language,
                    allShots: match.shots,
                    grandTotal: match.totalScore
                ) { selectedRecord = nil }
            }
        }
    }

    private func deleteHistoryItem(at offsets: IndexSet) {
        history.remove(atOffsets: offsets)
        if let encoded = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(encoded, forKey: "OlympicShooting_MatchHistory_V1")
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy/MM/dd HH:mm"
        return df.string(from: date)
    }
}

// MARK: - Olympic Scorecard Sheet View (With Deviation Direction Arrow)
struct OlympicScorecardView: View {
    let language: AppLanguage
    let allShots: [ShotRecord]
    let grandTotal: Double
    let onClose: () -> Void

    private var seriesChunks: [[ShotRecord]] {
        stride(from: 0, to: allShots.count, by: 10).map {
            Array(allShots[$0..<min($0 + 10, allShots.count)])
        }
    }

    private func seriesTitle(index: Int, count: Int) -> String {
        let start = index * 10 + 1
        let end = index * 10 + count
        if language == .traditionalChinese {
            return "第 \(index + 1) 組 (發數 \(start) ~ \(end))"
        } else {
            return "Series \(index + 1) (Shots \(start)-\(end))"
        }
    }

    private func subtotalText(total: Double) -> String {
        let label = (language == .traditionalChinese ? "小計" : "Subtotal")
        return String(format: "%@: %.1f", label, total)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "list.clipboard.fill")
                        .foregroundColor(Color(red: 0.18, green: 0.35, blue: 0.65))
                    Text(language == .traditionalChinese ? "計分表" : "Scorecard")
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(.black)
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color.black.opacity(0.45))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white)

            Divider()

            ZStack {
                Color(red: 0.94, green: 0.91, blue: 0.85).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        // Grand Total Header Banner
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {                                Text(language == .traditionalChinese ? "全場累積總分" : "Grand Total")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Color.black.opacity(0.6))
                                Text(String(format: "%.1f", grandTotal))
                                    .font(.system(size: 32, weight: .black, design: .monospaced))
                                    .foregroundColor(Color(red: 0.85, green: 0.15, blue: 0.1))
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(language == .traditionalChinese ? "總發數" : "Total Shots")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color.black.opacity(0.6))
                                Text("\(allShots.count) / 60")
                                    .font(.system(size: 20, weight: .heavy, design: .monospaced))
                            }
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white).shadow(color: Color.black.opacity(0.07), radius: 3, x: 0, y: 2))

                        // Series Breakdown Cards
                        if seriesChunks.isEmpty {
                            Text(language == .traditionalChinese ? "尚未進行擊發，請回到射擊場擊發。" : "No shots fired yet. Return to the range and shoot.")
                                .font(.system(size: 14))
                                .foregroundColor(Color.black.opacity(0.5))
                                .padding(40)
                        } else {
                            ForEach(Array(seriesChunks.enumerated()), id: \.offset) { index, chunk in
                                let seriesTotal = chunk.reduce(0.0) { $0 + $1.score }
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(seriesTitle(index: index, count: chunk.count))
                                            .font(.system(size: 13.5, weight: .heavy))
                                        Spacer()
                                        Text(subtotalText(total: seriesTotal))
                                            .font(.system(size: 14.5, weight: .black, design: .monospaced))
                                            .foregroundColor(Color(red: 0.1, green: 0.4, blue: 0.8))
                                    }

                                    // 10 shots score grid with deviation direction arrows
                                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 5), spacing: 6) {
                                        ForEach(chunk) { shot in
                                            ScorecardShotCell(shot: shot, language: language)
                                        }
                                    }
                                }
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white).shadow(color: Color.black.opacity(0.06), radius: 2, x: 0, y: 1))
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
    }
}


// MARK: - Scorecard Shot Cell
private struct ScorecardShotCell: View {
    let shot: ShotRecord
    let language: AppLanguage

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                Text("#\(shot.shotNumber)")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Color.black.opacity(0.45))

                if shot.isPerfect {
                    Text("◎")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundColor(Color(red: 0.9, green: 0.6, blue: 0.0))
                } else {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 7.5, weight: .black))
                        .foregroundColor(Color.blue)
                        .rotationEffect(shot.deviationAngle)
                }
            }

            Text(String(format: "%.1f", shot.score))
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(shot.isPerfect ? Color.orange : Color.black)

            Text(shot.clockDirection(lang: language))
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(Color.black.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 3)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.04)))
    }
}

// MARK: - Target Board View (精確採用 ISSF / Wikipedia 官方尺寸規格渲染)
struct TargetBoardView: View {
    let mode: AimMode
    let radius: CGFloat // Base radius = 110pt
    let shots: [ShotRecord]
    var showScoreTag: Bool = true

    // 各環精確半徑 (pt)
    func ringRadius(for ring: Int) -> CGFloat {
        switch mode {
        case .pistol:
            // 手槍靶：1環外徑 155.5mm (半徑 77.75mm) 對應 targetRadius = 110.0pt
            let ptPerMm: CGFloat = radius / 77.75
            switch ring {
            case 10: return 5.75 * ptPerMm  // 10環直徑 11.5mm (半徑 5.75mm)
            case 9:  return 13.75 * ptPerMm // 9環直徑 27.5mm (半徑 13.75mm)
            case 8:  return 21.75 * ptPerMm // 8環直徑 43.5mm (半徑 21.75mm)
            case 7:  return 29.75 * ptPerMm // 7環直徑 59.5mm (半徑 29.75mm，黑色瞄準區邊界)
            case 6:  return 37.75 * ptPerMm // 6環直徑 75.5mm
            case 5:  return 45.75 * ptPerMm // 5環直徑 91.5mm
            case 4:  return 53.75 * ptPerMm // 4環直徑 107.5mm
            case 3:  return 61.75 * ptPerMm // 3環直徑 123.5mm
            case 2:  return 69.75 * ptPerMm // 2環直徑 139.5mm
            case 1:  return 77.75 * ptPerMm // 1環直徑 155.5mm (總計分外徑)
            default: return 0
            }
        case .rifle:
            // 步槍靶：1環總外徑 45.5mm (半徑 22.75mm) 對應 effectiveRadius = 33.0pt
            let effectiveRadius = radius * 0.30
            let ptPerMm: CGFloat = effectiveRadius / 22.75
            switch ring {
            case 10: return 0.25 * ptPerMm  // 10環直徑 0.5mm 中心白點 (半徑 0.25mm)
            case 9:  return 2.75 * ptPerMm  // 9環直徑 5.5mm (半徑 2.75mm)
            case 8:  return 5.25 * ptPerMm  // 8環直徑 10.5mm (半徑 5.25mm)
            case 7:  return 7.75 * ptPerMm  // 7環直徑 15.5mm (半徑 7.75mm)
            case 6:  return 10.25 * ptPerMm // 6環直徑 20.5mm (半徑 10.25mm)
            case 5:  return 12.75 * ptPerMm // 5環直徑 25.5mm (半徑 12.75mm)
            case 4:  return 15.25 * ptPerMm // 4環直徑 30.5mm (半徑 15.25mm，黑色瞄準區邊界)
            case 3:  return 17.75 * ptPerMm // 3環直徑 35.5mm (半徑 17.75mm)
            case 2:  return 20.25 * ptPerMm // 2環直徑 40.5mm (半徑 20.25mm)
            case 1:  return 22.75 * ptPerMm // 1環直徑 45.5mm (半徑 22.75mm，總外徑)
            default: return 0
            }
        }
    }

    var bullseyeRadius: CGFloat {
        // 黑色瞄準區：手槍為 7 環邊界(59.5mm)，步槍為 4 環邊界(30.5mm)
        (mode == .pistol) ? ringRadius(for: 7) : ringRadius(for: 4)
    }

    var body: some View {
        ZStack {
            // 經典米色射擊靶紙背景
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.95, green: 0.89, blue: 0.74), Color(red: 0.92, green: 0.85, blue: 0.69)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: radius * 2 + 14, height: radius * 2 + 14)
                .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black.opacity(0.15), lineWidth: 1))

            // 黑色同心圓瞄準區（手槍7~10環，步槍4~9環）
            Circle()
                .fill(Color(red: 0.1, green: 0.1, blue: 0.1))
                .frame(width: bullseyeRadius * 2, height: bullseyeRadius * 2)

            // 同心計分環線（1~10環）
            ForEach(1...10, id: \.self) { ring in
                let r = ringRadius(for: ring)
                let isInsideBlack = (mode == .pistol) ? (ring >= 7) : (ring >= 4)

                if ring < 10 || mode == .pistol {
                    Circle()
                        .stroke(
                            isInsideBlack ? Color.white.opacity(0.9) : Color.black.opacity(0.8),
                            lineWidth: ring == 1 ? 1.1 : (isInsideBlack ? 0.85 : 0.7)
                        )
                        .frame(width: r * 2, height: r * 2)
                }
            }

            // 手槍內10環（直徑 5.0mm 內10環，十分由雙環組成）
            if mode == .pistol {
                let ptPerMm: CGFloat = radius / 77.75
                let inner10R = 2.50 * ptPerMm
                Circle()
                    .stroke(Color.white.opacity(0.92), lineWidth: 0.85)
                    .frame(width: inner10R * 2, height: inner10R * 2)
            }

            // 步槍中心 10 分白點（官方直徑 0.5mm，清晰中心白點）
            if mode == .rifle {
                let effectiveRadius = radius * 0.30
                let ptPerMm: CGFloat = effectiveRadius / 22.75
                let dotD = max(1.8, 0.5 * ptPerMm)
                Circle()
                    .fill(Color.white)
                    .frame(width: dotD, height: dotD)
            } else {
                Circle()
                    .fill(Color.white.opacity(0.7))
                    .frame(width: 1.2, height: 1.2)
            }

            // 1~8 環環數標註（四軸排列）
            ringNumbersView

            // 靶紙角落規格標註
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text(mode == .pistol ? "ISSF 10m Air Pistol (17x17cm)" : "ISSF 10m Air Rifle (Ø45.5mm)")
                        .font(.system(size: 7.2, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color.black.opacity(0.42))
                        .padding(4)
                }
            }
            .frame(width: radius * 2 + 14, height: radius * 2 + 14)

            // 灰色子彈印
            ForEach(shots) { shot in
                BulletHoleView(
                    shot: shot,
                    isLatest: shot.id == shots.last?.id,
                    showScoreTag: showScoreTag
                )
                .offset(x: shot.offset.x, y: shot.offset.y)
            }
        }
        .frame(width: radius * 2 + 14, height: radius * 2 + 14)
    }

    @ViewBuilder
    private var ringNumbersView: some View {
        ForEach(1...8, id: \.self) { num in
            let r1 = ringRadius(for: num)
            let r2 = ringRadius(for: num + 1)
            let dist = (r1 + r2) / 2.0
            let isWhite = (mode == .pistol) ? (num >= 7) : (num >= 4)
            let numColor = isWhite ? Color.white : Color.black
            let fontSize: CGFloat = (mode == .rifle) ? 4.8 : 7.2

            Text("\(num)").font(.system(size: fontSize, weight: .bold)).foregroundColor(numColor).offset(y: -dist)
            Text("\(num)").font(.system(size: fontSize, weight: .bold)).foregroundColor(numColor).offset(y: dist)
            Text("\(num)").font(.system(size: fontSize, weight: .bold)).foregroundColor(numColor).offset(x: -dist)
            Text("\(num)").font(.system(size: fontSize, weight: .bold)).foregroundColor(numColor).offset(x: dist)
        }
    }
}

// MARK: - Grey Bullet Hole View (灰色的子彈印，依手槍與步槍精確比例計算子彈直徑)
struct BulletHoleView: View {
    let shot: ShotRecord
    let isLatest: Bool
    var showScoreTag: Bool = true

    var bulletDiameter: CGFloat {
        // 嚴格依 4.5mm 競賽彈丸與靶紙尺寸精確換算：
        // 手槍靶：155.5mm 對應 110pt -> 4.5mm = 6.37pt
        // 步槍靶：45.5mm 對應 33pt -> 4.5mm = 6.53pt
        switch shot.mode {
        case .pistol:
            return 6.37
        case .rifle:
            return 6.53
        }
    }

    var body: some View {
        let d = bulletDiameter
        ZStack {
            Circle().fill(Color(white: 0.52)).frame(width: d, height: d)
            Circle().fill(Color(white: 0.28)).frame(width: d * 0.65, height: d * 0.65)
            Circle().stroke(Color(white: 0.7), lineWidth: 0.6).frame(width: d * 0.92, height: d * 0.92)

            if isLatest {
                Circle()
                    .stroke(shot.isPerfect ? Color.yellow : Color.red, lineWidth: 1.5)
                    .frame(width: d + 5.0, height: d + 5.0)

                if showScoreTag {
                    Text(String(format: "%.1f", shot.score))
                        .font(.system(size: 8.5, weight: .heavy))
                        .foregroundColor(.white)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(shot.isPerfect ? Color.orange : Color.black.opacity(0.85)))
                        .offset(x: d * 0.7 + 5, y: -7)
                }
            }
        }
    }
}

// MARK: - Extra Large Pistol W-Sight View (放得更大的W瞄具)
struct PistolExtraLargeWSightView: View {
    var body: some View {
        ZStack(alignment: .top) {
            // Enlarged W-Shape Rear Sight Blade (width: 156, height: 42)
            WNotchShape()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.26, green: 0.26, blue: 0.29), Color(red: 0.12, green: 0.12, blue: 0.14)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 156, height: 42)
                .shadow(color: Color.black.opacity(0.35), radius: 2.5, x: 0, y: 1.5)

            // Front Sight Post in Center (width: 16, height: 28)
            Rectangle()
                .fill(LinearGradient(colors: [Color(white: 0.22), Color(white: 0.08)], startPoint: .top, endPoint: .bottom))
                .frame(width: 16, height: 28)
                .overlay(
                    VStack {
                        Rectangle().fill(Color.white.opacity(0.65)).frame(height: 1.6)
                        Spacer()
                    }
                )
                .offset(y: 2)

            // White Reference Marks on Shoulders
            HStack(spacing: 62) {
                Rectangle().fill(Color.white.opacity(0.6)).frame(width: 2.5, height: 14)
                Rectangle().fill(Color.white.opacity(0.6)).frame(width: 2.5, height: 14)
            }
            .offset(y: 10)
        }
    }
}

// W-Notch Shape
struct WNotchShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let midX = rect.midX
        let wingW = w * 0.32
        let notchW = w * 0.36
        let dipY = rect.minY + h * 0.65

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + wingW, y: rect.minY))
        path.addLine(to: CGPoint(x: midX - notchW * 0.45, y: dipY))
        path.addLine(to: CGPoint(x: midX + notchW * 0.45, y: dipY))
        path.addLine(to: CGPoint(x: rect.maxX - wingW, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Rifle Concentric Sight View (覘孔同心圓瞄準，瞄準環直徑約66pt，與1分外環精準重疊)
// Note: Rifle Ring 1 diameter is 66pt (110 * 0.30 * 2). Sight 2nd ring is 66pt, perfectly overlapping Ring 1!
struct RifleConcentricSightView: View {
    var body: some View {
        ZStack {
            // 1st circle (most outside housing): 108pt
            Circle()
                .stroke(Color.black.opacity(0.75), lineWidth: 11)
                .frame(width: 108, height: 108)

            // 2nd circle (瞄準環/同心圓瞄準環): 66pt，與步槍1分外環（直徑 66pt）精準重疊
            Circle()
                .stroke(Color.black.opacity(0.85), lineWidth: 2.4)
                .frame(width: 66, height: 66)

            // Horizontal crossbars supporting the 2nd aperture
            Rectangle()
                .fill(Color.black.opacity(0.75))
                .frame(width: 19, height: 1.4)
                .offset(x: -41)

            Rectangle()
                .fill(Color.black.opacity(0.75))
                .frame(width: 19, height: 1.4)
                .offset(x: 41)

            // Fine inner target alignment ring: 14pt
            Circle()
                .stroke(Color.red.opacity(0.65), lineWidth: 1.0)
                .frame(width: 14, height: 14)

            // Center red dot: 2.0pt
            Circle()
                .fill(Color.red.opacity(0.8))
                .frame(width: 2.0, height: 2.0)
        }
    }
}

// MARK: - Dynamic Tutorial Step Definition
enum TutorialStep: Int, CaseIterable, Identifiable {
    case startMenu = 1
    case selectRifle = 2
    case holdToAim = 3
    case releaseFire10_9 = 4
    case viewScorecard = 5
    case finishAndSave = 6

    var id: Int { rawValue }

    func title(lang: AppLanguage) -> String {
        switch self {
        case .startMenu:
            return lang == .traditionalChinese ? "步驟 1：主選單點擊【開始射擊】" : "Step 1: Tap [Start Shooting]"
        case .selectRifle:
            return lang == .traditionalChinese ? "步驟 2：選擇射擊項目【10米步槍】" : "Step 2: Select [10m Rifle]"
        case .holdToAim:
            return lang == .traditionalChinese ? "步驟 3：靶面右下方長按 · 屏息穩瞄" : "Step 3: Hold Bottom-Right to Aim"
        case .releaseFire10_9:
            return lang == .traditionalChinese ? "步驟 4：鬆手擊發 · 命中 10.9 滿分！" : "Step 4: Release & Score 10.9!"
        case .viewScorecard:
            return lang == .traditionalChinese ? "步驟 5：查看【計分表】偏差分析" : "Step 5: Review Match Scorecard"
        case .finishAndSave:
            return lang == .traditionalChinese ? "步驟 6：點擊【結束】儲存至歷史記錄" : "Step 6: Finish & Save to History"
        }
    }

    func shortLabel(lang: AppLanguage) -> String {
        switch self {
        case .startMenu:
            return lang == .traditionalChinese ? "1.開始" : "1.Start"
        case .selectRifle:
            return lang == .traditionalChinese ? "2.選步槍" : "2.Rifle"
        case .holdToAim:
            return lang == .traditionalChinese ? "3.長按穩瞄" : "3.Aim"
        case .releaseFire10_9:
            return lang == .traditionalChinese ? "4.擊發10.9" : "4.Fire 10.9"
        case .viewScorecard:
            return lang == .traditionalChinese ? "5.計分表" : "5.Card"
        case .finishAndSave:
            return lang == .traditionalChinese ? "6.儲存退出" : "6.Save"
        }
    }

    func detailedDesc(lang: AppLanguage) -> String {
        switch self {
        case .startMenu:
            return lang == .traditionalChinese ?
                "• 在主選單點擊【開始射擊】按鈕，進入射擊項目選擇視窗。" :
                "• Tap [Start Shooting] on the Main Menu to open event selection."
        case .selectRifle:
            return lang == .traditionalChinese ?
                "• 彈出視窗居中顯示，點擊【10米步槍】。進入比賽後項目自動鎖定，中途不可變更，直到結束本場重開。" :
                "• Centered modal: Tap [10m Rifle]. The event locks for the entire match until completed."
        case .holdToAim:
            return lang == .traditionalChinese ?
                """
                • 長按操作：手指在靶面右下方【長按】即可進入「屏息穩瞄」狀態，避免手指遮擋中央靶心。
                • 步槍瞄準訣竅：透過後方覘孔，讓瞄準圓環與靶紙最外圍的「1分外環」重疊，將黑心靶紙端正套在同心圓中央！
                """ :
                """
                • Hold Control: Press and hold at the bottom-right of the target to steady your aim without obstructing the bullseye.
                • Sighting Tip: Look through the rear peep hole so the front ring overlaps Ring 1, centering the black bullseye evenly!
                """
        case .releaseFire10_9:
            return lang == .traditionalChinese ?
                """
                • 鬆手擊發：抓準同心圓重疊至中心的一瞬間，鬆開手指開槍！
                • 擊發伴隨清脆金屬撞擊聲，可由右上方即時放大鏡檢視彈印！
                """ :
                """
                • Release to Fire: Release your finger at peak concentric alignment!
                • Real metallic hit audio plays, check real-time magnifier for bullet imprints!
                """
        case .viewScorecard:
            return lang == .traditionalChinese ?
                "• 點擊右上角【計分表】，可隨時檢視各組成績與每發子彈的精確偏差方向（例如：正中 •、偏向 2 點鐘方向 ↗）。" :
                "• Tap [Card] anytime to review series scores, cumulative totals, and directional deviation for each shot."
        case .finishAndSave:
            return lang == .traditionalChinese ?
                "• 點擊右上角【結束】，彈出確認選單：選擇【儲存成績並結束】。儲存後可在【歷史記錄】隨時複查每發成績！" :
                "• Tap [Finish] and choose [Save & Finish]. Results are permanently stored in Match History!"
        }
    }
}

// MARK: - Animated Touch Dot Indicator (只有圓點動：點擊縮小動態圈 / 長按多層同心縮小圈)
struct TutorialTouchDotView: View {
    let isLongPress: Bool
    @State private var pulse: Bool = false

    var body: some View {
        ZStack {
            if isLongPress {
                // 長按：多層動態縮小同心光環 (Multiple Concentric Contracting Rings)
                Circle()
                    .stroke(Color.yellow.opacity(0.7), lineWidth: 2)
                    .frame(width: pulse ? 22 : 48, height: pulse ? 22 : 48)
                    .opacity(pulse ? 0.2 : 0.8)

                Circle()
                    .stroke(Color(red: 0.2, green: 0.85, blue: 1.0).opacity(0.85), lineWidth: 2)
                    .frame(width: pulse ? 16 : 36, height: pulse ? 16 : 36)
                    .opacity(pulse ? 0.35 : 0.9)

                Circle()
                    .stroke(Color.white.opacity(0.95), lineWidth: 2.2)
                    .frame(width: pulse ? 10 : 24, height: pulse ? 10 : 24)
            } else {
                // 點擊：單個縮小動態光圈 (Single Contracting Tap Ring)
                Circle()
                    .stroke(Color.yellow, lineWidth: 2.2)
                    .frame(width: pulse ? 16 : 32, height: pulse ? 16 : 32)
                    .opacity(pulse ? 0.95 : 0.35)
            }

            // 中心觸發圓點 (Center Core Dot)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white, Color(red: 1.0, green: 0.82, blue: 0.2)],
                        center: .center,
                        startRadius: 2,
                        endRadius: 7
                    )
                )
                .frame(width: 12, height: 12)
                .shadow(color: .yellow, radius: 4)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: isLongPress ? 0.75 : 0.45).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

// MARK: - Instructions Sheet View (背景恢復與靶子同色，窗口固定不動，僅圓點動)
struct InstructionsSheetView: View {
    let language: AppLanguage
    let onClose: () -> Void

    @State private var selectedTab: Int = 0 // 0: 動態操作演示, 1: 詳細規則圖文
    @State private var currentStep: TutorialStep = .startMenu
    @State private var isPlaying: Bool = true
    @State private var stepTimer: Double = 0.0
    @State private var sightOffset: CGSize = CGSize(width: 10, height: -8)
    @State private var showHitEffect: Bool = false

    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationView {
            ZStack {
                // 操作說明背景改回原本的靶紙米色
                Color(red: 0.93, green: 0.86, blue: 0.70).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Tab Picker: 動態操作演示 vs 詳細圖文說明
                    Picker("", selection: $selectedTab) {
                        Text(language == .traditionalChinese ? "🎥 步槍動態操作演示" : "🎥 Rifle Gameplay Demo").tag(0)
                        Text(language == .traditionalChinese ? "📖 詳細操作與規則" : "📖 Full Rules").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.85))

                    if selectedTab == 0 {
                        dynamicWalkthroughView
                    } else {
                        staticInstructionsView
                    }
                }
            }
            .navigationTitle(language == .traditionalChinese ? "射擊操作說明" : "Instructions & Demo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(language == .traditionalChinese ? "關閉" : "Close", action: onClose)
                        .font(.system(size: 15, weight: .bold))
                }
            }
            .onReceive(timer) { _ in
                handleTimerTick()
            }
        }
    }

    // MARK: - 動態演示主視圖
    private var dynamicWalkthroughView: some View {
        ScrollView {
            VStack(spacing: 12) {
                // 1. 模擬手機螢幕框 (Simulated Screen Frame)
                ZStack {
                    simulatedScreenContent
                }
                .frame(width: 295, height: 410)
                .background(Color(red: 0.93, green: 0.86, blue: 0.70))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.80, green: 0.72, blue: 0.55),
                                    Color(red: 0.65, green: 0.58, blue: 0.42)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                )
                .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 4)
                .padding(.top, 4)

                // 2. 步驟切換控制按鈕列 (Step Quick Jump Bar)
                HStack(spacing: 4) {
                    ForEach(TutorialStep.allCases) { step in
                        Button {
                            currentStep = step
                            stepTimer = 0
                            triggerStepEffects(step: step)
                        } label: {
                            Text(step.shortLabel(lang: language))
                                .font(.system(size: 11, weight: currentStep == step ? .bold : .medium))
                                .foregroundColor(currentStep == step ? Color(red: 0.12, green: 0.16, blue: 0.28) : Color.black.opacity(0.65))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(
                                            currentStep == step ?
                                            LinearGradient(colors: [Color(red: 1.0, green: 0.88, blue: 0.55), Color(red: 0.95, green: 0.75, blue: 0.35)], startPoint: .top, endPoint: .bottom) :
                                            LinearGradient(colors: [Color.white, Color.white.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                                        )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(currentStep == step ? Color(red: 0.85, green: 0.65, blue: 0.2) : Color.black.opacity(0.12), lineWidth: 1)
                                )
                        }
                    }
                }
                .padding(.horizontal, 10)

                // 3. 播放控制欄 (Play/Pause, Replay)
                HStack(spacing: 16) {
                    Button {
                        isPlaying.toggle()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            Text(isPlaying ? (language == .traditionalChinese ? "暫停" : "Pause") : (language == .traditionalChinese ? "播放" : "Play"))
                        }
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Color(red: 0.18, green: 0.25, blue: 0.40)))
                    }

                    Button {
                        currentStep = .startMenu
                        stepTimer = 0
                        triggerStepEffects(step: .startMenu)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "gobackward")
                            Text(language == .traditionalChinese ? "從頭重播" : "Replay")
                        }
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundColor(Color(red: 0.18, green: 0.25, blue: 0.40))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Capsule().stroke(Color(red: 0.18, green: 0.25, blue: 0.40), lineWidth: 1.2))
                    }
                }

                // 4. 當前步驟詳細解說卡片
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(Color(red: 0.85, green: 0.55, blue: 0.1))
                            .font(.system(size: 15))
                        Text(currentStep.title(lang: language))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 0.12, green: 0.16, blue: 0.26))
                        Spacer()
                    }

                    Text(currentStep.detailedDesc(lang: language))
                        .font(.system(size: 12.5))
                        .foregroundColor(Color.black.opacity(0.78))
                        .lineSpacing(3)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
    }

    // MARK: - 模擬手機螢幕內容 (背景為與靶子同色之米色，步驟2~6窗口固定不動，僅圓點動)
    @ViewBuilder
    private var simulatedScreenContent: some View {
        ZStack {
            if currentStep == .startMenu {
                // 步驟 1：主畫面預覽（含金屬同心波紋背景）
                mockMainMenuView
            } else {
                // 步驟 2~6：靶場背景固定不動（與靶子一個顏色），窗口位置固定，只有圓點動
                ZStack {
                    Color(red: 0.93, green: 0.86, blue: 0.70).ignoresSafeArea()

                    // 固定靶場基本畫面（靶面居中）
                    mockBaseRangeScene

                    // 步驟覆蓋層（窗口固定在正中央，只有圓點動）
                    switch currentStep {
                    case .startMenu:
                        EmptyView()
                    case .selectRifle:
                        mockWeaponSelectOverlay
                    case .holdToAim:
                        mockAimingTouchOverlay
                    case .releaseFire10_9:
                        mockFiredCelebrationOverlay
                    case .viewScorecard:
                        mockScorecardOverlay
                    case .finishAndSave:
                        mockExitConfirmOverlay
                    }
                }
            }
        }
        .clipped()
    }

    // MARK: - 步驟 1：主畫面 (開始射擊置中對齊其他兩個按鈕，圓點懸浮於「射擊」後)
    private var mockMainMenuView: some View {
        ZStack {
            OlympicMetallicRipplesBackground(logoCenter: CGPoint(x: 147.5, y: 110))

            VStack(spacing: 8) {
                Spacer().frame(height: 24)

                // Logo
                Image("CustomAppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 78, height: 78)
                    .shadow(color: Color.black.opacity(0.4), radius: 4)

                VStack(spacing: 3) {
                    Text(language == .traditionalChinese ? "10米射擊" : "10M SHOOTING")
                        .font(.custom("DelaGothicOne-Regular", size: 17))
                        .foregroundColor(.white)
                    Text(language == .traditionalChinese ? "射擊模擬器" : "SHOOTING SIMULATOR")
                        .font(.custom("Orbitron-Bold", size: 10.5))
                        .foregroundColor(Color(red: 0.95, green: 0.8, blue: 0.4))
                }

                Spacer().frame(height: 14)

                // 按鈕群組：三個按鈕寬度一律 255pt，完全居中對齊
                VStack(spacing: 10) {
                    // 1. 開始射擊按鈕 (內容完全居中，圓點於「射擊」二字後動態縮小)
                    ZStack {
                        // 居中的按鈕內容 (與下方按鈕完全對齊)
                        HStack(spacing: 7) {
                            Image(systemName: "scope")
                                .font(.system(size: 15, weight: .heavy))
                            Text(language == .traditionalChinese ? "開 始 射 擊" : "Start Shooting")
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .shadow(color: Color.black.opacity(0.5), radius: 2, x: 0, y: 1)

                        // 點擊圓點懸浮於「射擊」字後 (右側)，不影響按鈕文字居中
                        HStack {
                            Spacer()
                            TutorialTouchDotView(isLongPress: false)
                                .padding(.trailing, 18)
                        }
                    }
                    .frame(width: 255, height: 46)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.22, green: 0.42, blue: 0.72),
                                Color(red: 0.11, green: 0.22, blue: 0.45)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(13)
                    .overlay(
                        RoundedRectangle(cornerRadius: 13)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color(red: 1.0, green: 0.92, blue: 0.70).opacity(0.85),
                                        Color(red: 0.30, green: 0.50, blue: 0.85).opacity(0.35)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1.3
                            )
                    )
                    .shadow(color: Color(red: 0.08, green: 0.16, blue: 0.35).opacity(0.6), radius: 6, x: 0, y: 3)

                    // 2. 歷史記錄按鈕 (居中對齊)
                    HStack(spacing: 6) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 13, weight: .bold))
                        Text(language == .traditionalChinese ? "歷 史 記 錄" : "Match History")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(Color(red: 0.14, green: 0.18, blue: 0.26))
                    .frame(width: 255, height: 38)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.93, green: 0.94, blue: 0.96), Color(red: 0.78, green: 0.81, blue: 0.85)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(11)

                    // 3. 操作說明按鈕 (居中對齊)
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text(language == .traditionalChinese ? "操 作 說 明" : "Instructions")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(width: 255, height: 38)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.28, green: 0.32, blue: 0.38), Color(red: 0.16, green: 0.19, blue: 0.24)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(11)
                }

                Spacer().frame(height: 20)
            }
        }
    }

    // MARK: - 固定靶場基底場景 (同步遊戲最新介面：左側總分與3x2表格、右側即時放大鏡)
    private var mockBaseRangeScene: some View {
        VStack(spacing: 5) {
            // 頂部儀表板 (返回選單、鎖定項目、發數、成績單、結束)
            HStack(spacing: 4) {
                HStack(spacing: 2) {
                    Image(systemName: "chevron.left")
                    Text(language == .traditionalChinese ? "選單" : "Menu")
                }
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(Color.black.opacity(0.75))
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.black.opacity(0.08)))

                HStack(spacing: 3) {
                    Circle().stroke(Color.black, lineWidth: 1.2).frame(width: 8, height: 8)
                    Text(language == .traditionalChinese ? "10米步槍" : "10m Rifle")
                        .font(.system(size: 8, weight: .black))
                    Image(systemName: "lock.fill")
                        .font(.system(size: 6))
                        .foregroundColor(Color.black.opacity(0.45))
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color.black.opacity(0.06)))

                Spacer()

                Text(currentStep == .releaseFire10_9 || currentStep == .viewScorecard || currentStep == .finishAndSave ? "1/60" : "0/60")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundColor(Color.black.opacity(0.75))

                HStack(spacing: 2) {
                    Image(systemName: "list.clipboard.fill").font(.system(size: 7.5))
                    Text(language == .traditionalChinese ? "計分表" : "Scores").font(.system(size: 7.5, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color(red: 0.18, green: 0.35, blue: 0.65)))

                HStack(spacing: 2) {
                    Image(systemName: "flag.checkered").font(.system(size: 7.5))
                    Text(language == .traditionalChinese ? "結束" : "Finish").font(.system(size: 7.5, weight: .heavy))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color(red: 0.85, green: 0.25, blue: 0.15)))
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)

            // 即時放大鏡與總分列 (同步實際遊戲之縮小視圖)
            HStack(spacing: 5) {
                // 左側總分與3x2表格
                let isFired = (currentStep == .releaseFire10_9 || currentStep == .viewScorecard || currentStep == .finishAndSave)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(alignment: .center, spacing: 4) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(language == .traditionalChinese ? "總分" : "TOTAL")
                                .font(.system(size: 6.5, weight: .bold))
                                .foregroundColor(Color.black.opacity(0.55))
                            Text(isFired ? "10.9" : "0.0")
                                .font(.system(size: 13, weight: .black, design: .monospaced))
                                .foregroundColor(Color(red: 0.86, green: 0.16, blue: 0.10))
                        }
                        .frame(width: 44, alignment: .leading)

                        Rectangle().fill(Color.black.opacity(0.12)).frame(width: 1, height: 22)

                        // 3x2 表格
                        VStack(spacing: 1) {
                            HStack(spacing: 3) {
                                Text(isFired ? "S1: 10.9" : "S1: --.-").font(.system(size: 6.5, weight: .bold, design: .monospaced)).foregroundColor(isFired ? Color.blue : Color.black.opacity(0.5))
                                Text("S2: --.-").font(.system(size: 6.5, weight: .regular, design: .monospaced)).foregroundColor(Color.black.opacity(0.3))
                            }
                            HStack(spacing: 3) {
                                Text("S3: --.-").font(.system(size: 6.5, weight: .regular, design: .monospaced)).foregroundColor(Color.black.opacity(0.3))
                                Text("S4: --.-").font(.system(size: 6.5, weight: .regular, design: .monospaced)).foregroundColor(Color.black.opacity(0.3))
                            }
                            HStack(spacing: 3) {
                                Text("S5: --.-").font(.system(size: 6.5, weight: .regular, design: .monospaced)).foregroundColor(Color.black.opacity(0.3))
                                Text("S6: --.-").font(.system(size: 6.5, weight: .regular, design: .monospaced)).foregroundColor(Color.black.opacity(0.3))
                            }
                        }
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.88)))

                // 右側即時放大鏡
                VStack(spacing: 1) {
                    HStack(spacing: 2) {
                        Image(systemName: "magnifyingglass").font(.system(size: 6))
                        Text(language == .traditionalChinese ? "即時放大" : "ZOOM").font(.system(size: 6, weight: .heavy))
                    }
                    .foregroundColor(Color.black.opacity(0.6))

                    ZStack {
                        TargetBoardView(
                            mode: .rifle,
                            radius: 20,
                            shots: isFired ? [ShotRecord(offset: .zero, score: 10.9, mode: .rifle, shotNumber: 1)] : [],
                            showScoreTag: false
                        )
                        .scaleEffect(2.5)
                        .frame(width: 26, height: 26)
                        .clipShape(Circle())
                        Circle().stroke(Color.gray, lineWidth: 1.0)
                    }
                    .frame(width: 26, height: 26)

                    Text(isFired ? "10.9 ◎" : "--.-")
                        .font(.system(size: 7.5, weight: .black, design: .monospaced))
                        .foregroundColor(Color(red: 0.95, green: 0.65, blue: 0.0))
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .frame(width: 60)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.88)))
            }
            .padding(.horizontal, 8)

            Spacer()

            // 步槍靶面 (半徑 55pt，位置完全固定在正中)
            let isFired = (currentStep == .releaseFire10_9 || currentStep == .viewScorecard || currentStep == .finishAndSave)
            ZStack {
                TargetBoardView(
                    mode: .rifle,
                    radius: 55,
                    shots: isFired ? [ShotRecord(offset: .zero, score: 10.9, mode: .rifle, shotNumber: 1)] : []
                )

                // 步槍瞄準同心圓
                RifleConcentricSightView()
                    .offset(currentStep == .holdToAim ? sightOffset : .zero)
                    .scaleEffect(55.0 / 110.0)
            }

            Spacer()
        }
    }

    // MARK: - 步驟 2 覆蓋層：選擇射擊項目視窗 (窗口位置固定，只有圓點動)
    private var mockWeaponSelectOverlay: some View {
        ZStack {
            Color.black.opacity(0.48).ignoresSafeArea()

            VStack(spacing: 12) {
                Image(systemName: "scope")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(Color(red: 0.88, green: 0.68, blue: 0.22))

                Text(language == .traditionalChinese ? "選擇射擊項目" : "Select Event")
                    .font(.system(size: 15, weight: .black))
                    .foregroundColor(.white)

                Text(language == .traditionalChinese ? "請選擇本場射擊項目：" : "Please select the event:")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.75))

                VStack(spacing: 9) {
                    // 10米手槍 (Pistol)
                    HStack(spacing: 10) {
                        WNotchShape()
                            .fill(Color.white.opacity(0.65))
                            .frame(width: 20, height: 8)
                        Text(language == .traditionalChinese ? "10米手槍" : "10m Pistol")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white.opacity(0.65))
                        Spacer()
                        Image(systemName: "arrow.right.circle")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.10)))

                    // 10米步槍 (Rifle - 窗口固定不動，僅圓點動)
                    ZStack {
                        HStack(spacing: 10) {
                            Circle()
                                .stroke(Color(red: 1.0, green: 0.88, blue: 0.35), lineWidth: 2)
                                .frame(width: 14, height: 14)
                            Text(language == .traditionalChinese ? "10米步槍" : "10m Rifle")
                                .font(.system(size: 13.5, weight: .heavy))
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 15))
                                .foregroundColor(Color(red: 1.0, green: 0.88, blue: 0.35))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red: 0.20, green: 0.38, blue: 0.35), Color(red: 0.10, green: 0.22, blue: 0.20)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.yellow, lineWidth: 1.8)
                        )

                        // 只有圓點在步槍按鈕右側動
                        HStack {
                            Spacer()
                            TutorialTouchDotView(isLongPress: false)
                                .padding(.trailing, 32)
                        }
                    }
                }
            }
            .padding(16)
            .frame(width: 245)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(red: 0.12, green: 0.16, blue: 0.25))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(red: 0.85, green: 0.70, blue: 0.35), lineWidth: 1.5))
            )
        }
    }

    // MARK: - 步驟 3 覆蓋層：長按穩瞄 (窗口不變，只有右下角圓點動)
    private var mockAimingTouchOverlay: some View {
        ZStack {
            // 只有圓點在靶子右下方動 (長按多同心圓縮小動態)
            TutorialTouchDotView(isLongPress: true)
                .offset(x: 58, y: 60)
        }
    }

    // MARK: - 步驟 4 覆蓋層：命中 10.9 慶祝 (靶面窗口不動)
    private var mockFiredCelebrationOverlay: some View {
        ZStack {
            // 命中光波紋
            Circle()
                .stroke(Color.yellow, lineWidth: 3)
                .frame(width: showHitEffect ? 45 : 10, height: showHitEffect ? 45 : 10)
                .opacity(showHitEffect ? 0.0 : 0.9)

            // 滿分標籤 (懸浮於靶心上方)
            VStack(spacing: 2) {
                Text("🎯 10.9")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundColor(Color(red: 1.0, green: 0.88, blue: 0.2))
                Text(language == .traditionalChinese ? "命中正中心！" : "DEAD CENTER!")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.black.opacity(0.8)).overlay(Capsule().stroke(Color.yellow, lineWidth: 1)))
            .offset(y: -55)
        }
    }

    // MARK: - 步驟 5 覆蓋層：成績單視窗 (窗口位置固定，只有圓點動)
    private var mockScorecardOverlay: some View {
        ZStack {
            Color.black.opacity(0.48).ignoresSafeArea()

            VStack(spacing: 8) {
                HStack {
                    Text(language == .traditionalChinese ? "歷史射擊計分表" : "Match Scorecard")
                        .font(.system(size: 12, weight: .bold))
                    Spacer()
                    Text("")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundColor(Color(red: 0.85, green: 0.15, blue: 0.1))
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)

                Divider()

                VStack(spacing: 6) {
                    HStack {
                        Text(language == .traditionalChinese ? "第 1 組 (發數 1~1)" : "Series 1 (Shot 1)")
                            .font(.system(size: 11, weight: .heavy))
                        Spacer()
                        Text("10.9")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundColor(Color(red: 0.1, green: 0.4, blue: 0.8))
                    }

                    // 第 1 發紀錄 (窗口固定，只有圓點動)
                    ZStack {
                        HStack {
                            Text("#1")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(Color.black.opacity(0.5))
                            Spacer()
                            Text(language == .traditionalChinese ? "正中 • 0.0mm" : "Center • 0.0mm")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundColor(Color(red: 0.15, green: 0.65, blue: 0.3))
                            Spacer()
                            Text("10.9")
                                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                                .foregroundColor(Color(red: 0.85, green: 0.15, blue: 0.1))
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color(red: 0.95, green: 0.95, blue: 0.97)))

                        // 只有圓點動
                        HStack {
                            Spacer()
                            TutorialTouchDotView(isLongPress: false)
                                .padding(.trailing, 28)
                        }
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white))
            }
            .frame(width: 245)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(red: 0.96, green: 0.94, blue: 0.90))
                    .shadow(color: Color.black.opacity(0.3), radius: 6)
            )
        }
    }

    // MARK: - 步驟 6 覆蓋層：結束確認視窗 (完全同步實際遊戲 finishConfirmationOverlay 樣式與佈局)
    private var mockExitConfirmOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 11) {
                // 1. 頂部紅色旗幟圓形圖標 (與實際遊戲一致)
                Image(systemName: "flag.checkered.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(Color(red: 0.90, green: 0.25, blue: 0.20))

                // 2. 標題 (黑色粗體)
                Text(language == .traditionalChinese ? "結束本場射擊" : "Finish Match")
                    .font(.system(size: 14.5, weight: .black))
                    .foregroundColor(.black)

                // 3. 說明文字 (居中灰色文字)
                Text(language == .traditionalChinese ? "本場比賽共擊發 1 發，總分 10.9 分。請選擇處理方式：" : "Total 1 shot fired, Total Score 10.9. Please select an option:")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(Color.black.opacity(0.68))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)

                // 4. 三個操作按鈕 (完全同步實際遊戲：綠色儲存並結束、紅色退出不儲存、灰色取消)
                VStack(spacing: 7) {
                    // (1) 儲存成績並結束 (綠色按鈕，動態點擊圓點懸浮於右側)
                    ZStack {
                        HStack(spacing: 5) {
                            Image(systemName: "square.and.arrow.down.fill")
                                .font(.system(size: 11))
                            Text(language == .traditionalChinese ? "儲存成績並結束" : "Save & Finish")
                                .font(.system(size: 11.5, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(red: 0.18, green: 0.65, blue: 0.35)))

                        // 只有圓點動
                        HStack {
                            Spacer()
                            TutorialTouchDotView(isLongPress: false)
                                .padding(.trailing, 10)
                        }
                    }

                    // (2) 退出不儲存 (紅色按鈕，與實際遊戲完全一致)
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.uturn.left.circle.fill")
                            .font(.system(size: 11))
                        Text(language == .traditionalChinese ? "退出不儲存" : "Exit Without Saving")
                            .font(.system(size: 11.5, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(red: 0.85, green: 0.25, blue: 0.20)))

                    // (3) 取消按鈕 (淺灰底黑字，與實際遊戲完全一致)
                    Text(language == .traditionalChinese ? "取消" : "Cancel")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color.black.opacity(0.65))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.06)))
                }
            }
            .padding(16)
            .frame(width: 245)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.28), radius: 14, x: 0, y: 5)
            )
        }
    }

    // MARK: - 動態循環計時器邏輯
    private func handleTimerTick() {
        guard isPlaying else { return }

        stepTimer += 0.1

        // 步槍瞄準晃動自然平穩化
        if currentStep == .holdToAim {
            withAnimation(.easeInOut(duration: 0.2)) {
                sightOffset.width = max(0, sightOffset.width - 0.35)
                sightOffset.height = min(0, sightOffset.height + 0.3)
            }
        }

        // 步驟切換 (每個步驟約 3.6 秒)
        if stepTimer >= 3.6 {
            stepTimer = 0.0
            switch currentStep {
            case .startMenu:
                currentStep = .selectRifle
            case .selectRifle:
                currentStep = .holdToAim
                sightOffset = CGSize(width: 10, height: -8)
            case .holdToAim:
                currentStep = .releaseFire10_9
                triggerStepEffects(step: .releaseFire10_9)
            case .releaseFire10_9:
                currentStep = .viewScorecard
            case .viewScorecard:
                currentStep = .finishAndSave
            case .finishAndSave:
                currentStep = .startMenu
            }
        }
    }

    private func triggerStepEffects(step: TutorialStep) {
        if step == .releaseFire10_9 {
            SoundManager.shared.playGunshot()
            showHitEffect = false
            withAnimation(.easeOut(duration: 0.6)) {
                showHitEffect = true
            }
        } else if step == .holdToAim {
            sightOffset = CGSize(width: 10, height: -8)
        }
    }

    // MARK: - 詳細圖文說明視圖 (原操作說明備查)
    private var staticInstructionsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                instructionItem(
                    title: language == .traditionalChinese ? "🎮 操作方式：長按瞄準，鬆手開槍" : "🎮 Controls: Hold to Aim, Release to Fire",
                    desc: language == .traditionalChinese ?
                        """
                        • 瞄準：手指長按靶面（推薦長按靶面右下方避免遮蔽視線）進入「屏息穩瞄」狀態。
                        • 擊發：抓準同心圓或準星微幅晃動至中心的時機，鬆開手指即可開槍。
                        """ :
                        """
                        • Aim: Press and hold the target area (holding bottom-right avoids blocking sight) to steady your breath.
                        • Fire: Time your shot with the subtle sight sway toward center, and release your finger to fire.
                        """
                )
                instructionItem(
                    title: language == .traditionalChinese ? "🎯 高分瞄準訣竅" : "🎯 Pro Sighting Tips for High Scores",
                    desc: language == .traditionalChinese ?
                        """
                        • 手槍（三點一線）：前方的凸起（準星）對齊後方缺口（照門）中央。將準星切在黑色靶心正下方一段距離，即可擊中高分。

                        • 步槍（同心圓）：透過後方圓孔（覘孔）看前方瞄準圓環。瞄準環與1分外環重疊，將整個靶心維持在同心圓正中央即可擊出10分！
                        """ :
                        """
                        • Pistol (3-Point Alignment): Align front post centered in rear notch, held below the black bullseye.

                        • Rifle (Concentric Circles): Look through rear peep hole so the front ring overlaps Ring 1, centering the bullseye target within it to score 10s!
                        """
                )
                instructionItem(
                    title: language == .traditionalChinese ? "📊 成績與紀錄" : "📊 Scores & Match Records",
                    desc: language == .traditionalChinese ?
                        """
                        • 打完每一發後，計分表會標示子彈的偏差方向（例如：正中 •、偏向 2 點鐘方向 ↗）。
                        • 點擊「結束」按鈕，即可選擇儲存成績並存入歷史記錄。
                        """ :
                        """
                        • After each shot, the scorecard indicates its exact deviation direction (e.g. drifting toward 2 o'clock ↗).
                        • Tap the 'Finish' button anytime to save your complete match to History.
                        """
                )
            }
            .padding(18)
        }
    }

    private func instructionItem(title: String, desc: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 15, weight: .bold)).foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.15))
            Text(desc).font(.system(size: 13)).foregroundColor(Color.black.opacity(0.75)).lineSpacing(3)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white).shadow(color: Color.black.opacity(0.06), radius: 2, x: 0, y: 1))
    }
}


// MARK: - Pressable Button Style
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeInOut(duration: 0.08), value: configuration.isPressed)
    }
}

#Preview {
    ContentView()
}
