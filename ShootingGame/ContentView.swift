import SwiftUI
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

    var appTitle: String { lang == .traditionalChinese ? "10米奧運射擊" : "10m Olympic Shooting" }
    var appSubtitle: String { lang == .traditionalChinese ? "專業精準射擊模擬器" : "Precision Shooting Simulator" }
    var startButton: String { lang == .traditionalChinese ? "開始射擊" : "Start Shooting" }
    var instructionsButton: String { lang == .traditionalChinese ? "操作說明" : "How to Play" }
    var historyButton: String { lang == .traditionalChinese ? "歷史記錄" : "Match History" }
    var languageLabel: String { lang == .traditionalChinese ? "語言 / Language" : "Language" }

    var pistolMode: String { lang == .traditionalChinese ? "10米手槍" : "10m Pistol" }
    var rifleMode: String { lang == .traditionalChinese ? "10米步槍" : "10m Rifle" }
    var pistolSub: String { lang == .traditionalChinese ? "大W瞄具 · 6環光隙" : "Large W-Sight · Ring 6 Gap" }
    var rifleSub: String { lang == .traditionalChinese ? "同心圓 · 覘孔包覆4環" : "Diopter · Ring 4 Clearance" }

    var lastShot: String { lang == .traditionalChinese ? "上一發" : "Last" }
    var seriesSubtotal: String { lang == .traditionalChinese ? "當前組" : "Series" }
    var grandTotal: String { lang == .traditionalChinese ? "大賽總分" : "Total" }
    var shotProgress: String { lang == .traditionalChinese ? "總發數" : "Shots" }
    var scorecardBtn: String { lang == .traditionalChinese ? "成績單" : "Card" }
    var finishBtn: String { lang == .traditionalChinese ? "結束" : "Finish" }

    var maxShotsLabel: String { lang == .traditionalChinese ? "靶面彈印:" : "Target Marks:" }
    var fiveShots: String { lang == .traditionalChinese ? "5 發" : "5 Shots" }
    var tenShots: String { lang == .traditionalChinese ? "10 發" : "10 Shots" }

    var holdBreath: String { lang == .traditionalChinese ? "長按螢幕瞄準 · 鬆開射擊" : "Hold to Aim · Release to Shoot" }
    var holdingBreath: String { lang == .traditionalChinese ? "屏息瞄準中 · 鬆開擊發" : "Aiming · Release to Fire" }
    var clickToShot: String { lang == .traditionalChinese ? "長按瞄準 · 鬆開射擊" : "HOLD TO AIM · RELEASE TO SHOOT" }
    var shootHint: String { lang == .traditionalChinese ? "長按靶面屏息瞄準，鬆手瞬間擊發！" : "Hold target to steady aim, release to shoot!" }
    var backToMenu: String { lang == .traditionalChinese ? "主選單" : "Menu" }
    var resetMatch: String { lang == .traditionalChinese ? "清空" : "Clear" }

    var instructionsTitle: String { lang == .traditionalChinese ? "奧運射擊規則與操作說明" : "Rules & Instructions" }
    var closeButton: String { lang == .traditionalChinese ? "關閉" : "Close" }
}

// MARK: - Sound & Haptic FX Engine
final class SoundManager {
    static let shared = SoundManager()
    private init() {}

    func playGunshot() {
        #if canImport(AudioToolbox)
        AudioServicesPlaySystemSound(1104)
        #endif
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

    // Clock hour direction (e.g. 2點鐘方向)
    var clockDirection: String {
        if isPerfect { return "◎" }
        var deg = atan2(offsetY, offsetX) * 180.0 / .pi
        if deg < 0 { deg += 360.0 }
        let rawHour = Int((deg + 90.0).truncatingRemainder(dividingBy: 360.0) / 30.0)
        let hour = (rawHour == 0) ? 12 : rawHour
        return "\(hour)點"
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

// MARK: - Main Menu View (開始、操作說明、歷史記錄)
struct MainMenuView: View {
    @Binding var language: AppLanguage
    let onStart: () -> Void
    let onShowInstructions: () -> Void
    let onShowHistory: () -> Void

    private var l10n: L10n { L10n(lang: language) }

    var body: some View {
        ZStack {
            Color(red: 0.93, green: 0.86, blue: 0.70).ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                // Official ISSF Logo & Branding
                VStack(spacing: 12) {
                    Image("ISSFLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 140, height: 140)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color.white.opacity(0.88))
                                .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
                        )

                    Text(l10n.appTitle)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(Color(red: 0.12, green: 0.12, blue: 0.12))

                    VStack(spacing: 2) {
                        Text(language == .traditionalChinese ? "國際射擊運動聯盟" : "International Shooting Sport Federation")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 0.15, green: 0.32, blue: 0.62))
                        Text(l10n.appSubtitle)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(Color.black.opacity(0.55))
                    }
                }

                Spacer()

                // Language Segmented Control
                VStack(spacing: 6) {
                    Text(l10n.languageLabel)
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundColor(Color.black.opacity(0.55))
                    Picker("Language", selection: $language) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.rawValue).tag(lang)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 220)
                }

                // Menu Buttons
                VStack(spacing: 11) {
                    // Start Button
                    Button(action: onStart) {
                        HStack(spacing: 8) {
                            Image(systemName: "scope")
                                .font(.system(size: 18, weight: .bold))
                            Text(l10n.startButton)
                                .font(.system(size: 19, weight: .heavy, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: 260)
                        .padding(.vertical, 13)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.2, green: 0.45, blue: 0.85), Color(red: 0.12, green: 0.3, blue: 0.65)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.25), radius: 5, x: 0, y: 3)
                    }
                    .buttonStyle(PressableButtonStyle())

                    // Match History Button
                    Button(action: onShowHistory) {
                        HStack(spacing: 7) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 16, weight: .semibold))
                            Text(l10n.historyButton)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(Color(red: 0.15, green: 0.28, blue: 0.45))
                        .frame(maxWidth: 260)
                        .padding(.vertical, 11)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.85)))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.15), lineWidth: 1.2))
                    }
                    .buttonStyle(PressableButtonStyle())

                    // Instructions Button
                    Button(action: onShowInstructions) {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle.fill")
                            Text(l10n.instructionsButton)
                                .font(.system(size: 14.5, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(Color(red: 0.25, green: 0.25, blue: 0.25))
                        .frame(maxWidth: 260)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.06)))
                    }
                    .buttonStyle(PressableButtonStyle())
                }

                Spacer()
            }
            .padding(.horizontal, 24)
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
    @State private var showFinishAlert: Bool = false

    // Aiming State
    @State private var isHoldingBreath: Bool = false
    @State private var breathStartTime: Date? = nil
    @State private var isShooting: Bool = false
    @State private var showScorePopup: Bool = false
    @State private var popupScore: Double = 0.0
    @State private var recoilOffset: CGSize = .zero

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

    private var grandTotalScore: Double {
        allMatchShots.reduce(0.0) { $0 + $1.score }
    }

    var body: some View {
        ZStack {
            Color(red: 0.93, green: 0.86, blue: 0.70).ignoresSafeArea()

            VStack(spacing: 6) {
                // Top Header: Back, Olympic Dashboard, Scorecard & Finish
                olympicDashboardHeader
                    .padding(.horizontal, 10)
                    .padding(.top, 4)

                // Mode Selector
                modeSelectorRow
                    .padding(.horizontal, 14)

                // Capacity Picker & Progress
                capacityPickerRow
                    .padding(.horizontal, 16)

                Spacer(minLength: 2)

                // Central Target Area with Swaying Sight
                TimelineView(.animation) { timeline in
                    let now = timeline.date.timeIntervalSinceReferenceDate
                    let effectiveHolding = isBreathHoldingActive(now: timeline.date)
                    let sway = calculateSway(at: now, mode: aimMode, isHoldingBreath: effectiveHolding)
                    let entryDrop = entryDropOffset(now: timeline.date)

                    ZStack {
                        // Target Card
                        TargetBoardView(
                            mode: aimMode,
                            radius: targetRadius,
                            shots: visibleTargetShots
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
        }
        .sheet(isPresented: $showScorecard) {
            OlympicScorecardView(
                language: language,
                allShots: allMatchShots,
                grandTotal: grandTotalScore
            ) { showScorecard = false }
        }
        .alert(language == .traditionalChinese ? "確定結束這場射擊？" : "End and Save this Match?", isPresented: $showFinishAlert) {
            Button(language == .traditionalChinese ? "取消" : "Cancel", role: .cancel) {}
            Button(language == .traditionalChinese ? "確認結束並記錄" : "Finish & Save", role: .destructive) {
                finishAndSaveMatch()
            }
        } message: {
            Text(language == .traditionalChinese ? "目前的 \(allMatchShots.count) 發總成績將永久儲存至「歷史記錄」中。" : "Your \(allMatchShots.count) shots will be permanently saved to Match History.")
        }
    }

    private var visualSightOffsetY: CGFloat {
        switch aimMode {
        case .pistol:
            // 瞄準在 6 環正中間 (距離中心 0.55 * targetRadius，加上瞄具自身半高)
            return targetRadius * 0.55 + 21.0
        case .rifle:
            return 0.0
        }
    }

    // MARK: - Olympic Dashboard Header (Includes "Finish" button)
    private var olympicDashboardHeader: some View {
        HStack(spacing: 5) {
            Button(action: onExit) {
                HStack(spacing: 2) {
                    Image(systemName: "chevron.left")
                    Text(l10n.backToMenu)
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color.black.opacity(0.75))
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.black.opacity(0.08)))
            }
            .buttonStyle(.plain)

            Spacer()

            scoreItem(title: l10n.lastShot, value: lastShotScore != nil ? String(format: "%.1f", lastShotScore!) : "-")
            scoreItem(title: "S\(currentSeriesNumber)", value: String(format: "%.1f", currentSeriesSubtotal))
            scoreItem(title: l10n.grandTotal, value: String(format: "%.1f", grandTotalScore), highlight: true)

            // Scorecard Button
            Button(action: { showScorecard = true }) {
                VStack(spacing: 1) {
                    Image(systemName: "list.clipboard.fill").font(.system(size: 12))
                    Text(l10n.scorecardBtn).font(.system(size: 9, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color(red: 0.18, green: 0.35, blue: 0.65)))
            }
            .buttonStyle(.plain)

            // Finish Button (結束)
            Button(action: {
                if allMatchShots.isEmpty {
                    onExit()
                } else {
                    showFinishAlert = true
                }
            }) {
                HStack(spacing: 2) {
                    Image(systemName: "flag.checkered")
                    Text(l10n.finishBtn)
                }
                .font(.system(size: 11, weight: .heavy))
                .foregroundColor(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color(red: 0.85, green: 0.25, blue: 0.15)))
            }
            .buttonStyle(.plain)
        }
    }

    private func scoreItem(title: String, value: String, highlight: Bool = false) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 8.5, weight: .semibold))
                .foregroundColor(Color.black.opacity(0.6))
            Text(value)
                .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                .foregroundColor(highlight ? Color(red: 0.9, green: 0.15, blue: 0.05) : Color.black)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 4).fill(highlight ? Color.yellow.opacity(0.35) : Color.white.opacity(0.75)))
        }
    }

    // MARK: - Mode Selector Row
    private var modeSelectorRow: some View {
        HStack {
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { aimMode = .pistol } }) {
                HStack(spacing: 5) {
                    WNotchShape()
                        .fill(aimMode == .pistol ? Color.black : Color.gray)
                        .frame(width: 26, height: 10)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(l10n.pistolMode)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(aimMode == .pistol ? .black : Color(white: 0.35))
                        Text(l10n.pistolSub)
                            .font(.system(size: 8))
                            .foregroundColor(aimMode == .pistol ? Color(white: 0.2) : Color(white: 0.45))
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6).fill(aimMode == .pistol ? Color.black.opacity(0.09) : Color.clear))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(aimMode == .pistol ? Color.black.opacity(0.35) : Color.clear, lineWidth: 1))
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { aimMode = .rifle } }) {
                HStack(spacing: 5) {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(l10n.rifleMode)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(aimMode == .rifle ? .black : Color(white: 0.35))
                        Text(l10n.rifleSub)
                            .font(.system(size: 8))
                            .foregroundColor(aimMode == .rifle ? Color(white: 0.2) : Color(white: 0.45))
                    }
                    Circle()
                        .stroke(aimMode == .rifle ? Color.black : Color.gray, lineWidth: 2)
                        .frame(width: 17, height: 17)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6).fill(aimMode == .rifle ? Color.black.opacity(0.09) : Color.clear))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(aimMode == .rifle ? Color.black.opacity(0.35) : Color.clear, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private var capacityPickerRow: some View {
        HStack(spacing: 6) {
            Text(l10n.maxShotsLabel)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color.black.opacity(0.55))
            Picker("Capacity", selection: $maxMarksCapacity) {
                Text(l10n.fiveShots).tag(5)
                Text(l10n.tenShots).tag(10)
            }
            .pickerStyle(.segmented)
            .frame(width: 120)
            .onChange(of: maxMarksCapacity) { _, newCap in
                if visibleTargetShots.count > newCap {
                    visibleTargetShots = Array(visibleTargetShots.suffix(newCap))
                }
            }

            Spacer()

            Text("\(l10n.shotProgress): \(allMatchShots.count)")
                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                .foregroundColor(Color.black.opacity(0.7))
        }
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

        var x = (driftX + tremorX) * (mode == .pistol ? 1.17 : 0.72)
        var y = (driftY + tremorY) * (mode == .pistol ? 1.17 : 0.72)

        if isHoldingBreath {
            // 原本壓至 0.25（晃動過小几乎都在 10.5 以上）
            // 現調整為手槍約在 7 環範圍（最大振幅約 33~36pt，乘數 0.78），步槍在 8 環範圍（最大振幅約 13~14pt，乘數 0.65）
            let factor = (mode == .pistol) ? 0.78 : 0.65
            x *= factor
            y *= factor
        }
        return CGPoint(x: x, y: y)
    }

    /// 真實射擊下壓瞄準（未長按時準星在上方，長按後緩緩下壓，時間調整為 2.8 秒平穩入瞄）
    private func entryDropOffset(now: Date) -> CGFloat {
        guard let start = breathStartTime else {
            // 未長按瞄準時，槍口抬在上方待命
            return -52.0
        }
        let elapsed = max(0.0, now.timeIntervalSince(start))
        let entryDuration: Double = 2.8 // 從 1.8s 放慢至 2.8s，更從容沉穩
        if elapsed >= entryDuration {
            return 0.0
        }
        // 三次平滑曲線 (Ease Out)，從 -52pt 慢慢下壓至 0pt
        let progress = elapsed / entryDuration
        let easeOut = 1.0 - pow(1.0 - progress, 3)
        return -52.0 * CGFloat(1.0 - easeOut)
    }

    private func fireShot() {
        withAnimation(.easeOut(duration: 0.05)) { isShooting = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.easeIn(duration: 0.1)) { isShooting = false }
        }

        SoundManager.shared.playGunshot()

        let now = Date().timeIntervalSinceReferenceDate
        let effectiveBreath = isBreathHoldingActive(now: Date())
        let sway = calculateSway(at: now, mode: aimMode, isHoldingBreath: effectiveBreath)
        let entryDrop = entryDropOffset(now: Date())

        let impactX = sway.x
        let impactY = entryDrop + sway.y
        let impactPoint = CGPoint(x: impactX, y: impactY)

        // 後座力物理模擬：瞬間依目前晃動前進方向急速跳動，隨後平復回到上方
        let deltaT = 0.05
        let swayNext = calculateSway(at: now + deltaT, mode: aimMode, isHoldingBreath: effectiveBreath)
        let dirX = swayNext.x - sway.x
        let dirY = swayNext.y - sway.y
        let dirLen = max(0.001, sqrt(dirX * dirX + dirY * dirY))
        let recoilPower: CGFloat = (aimMode == .pistol) ? 26.0 : 16.0
        let kickX = (dirX / dirLen) * recoilPower
        let kickY = (dirY / dirLen) * recoilPower - 8.0 // 加上槍口自然向上跳動

        withAnimation(.easeOut(duration: 0.08)) {
            recoilOffset = CGSize(width: kickX, height: kickY)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.easeOut(duration: 0.25)) {
                recoilOffset = .zero
            }
        }
        let dist = sqrt(impactX * impactX + impactY * impactY)

        let effectiveRadius = (aimMode == .rifle) ? (targetRadius * 0.42) : targetRadius
        let ringStep = effectiveRadius / 10.0
        let scoreStep = ringStep / 10.0

        let computedScore: Double
        if dist <= scoreStep {
            computedScore = 10.9
        } else if dist >= effectiveRadius {
            computedScore = 0.0
        } else {
            let stepsAway = floor(dist / scoreStep)
            let raw = 10.9 - Double(stepsAway) * 0.1
            computedScore = max(0.0, (raw * 10.0).rounded() / 10.0)
        }

        let newShot = ShotRecord(
            offset: impactPoint,
            score: computedScore,
            mode: aimMode,
            shotNumber: allMatchShots.count + 1
        )

        allMatchShots.append(newShot)

        if visibleTargetShots.count >= maxMarksCapacity {
            visibleTargetShots.removeFirst()
        }
        visibleTargetShots.append(newShot)

        lastShotScore = computedScore
        popupScore = computedScore
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { showScorePopup = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.3)) { showScorePopup = false }
        }
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
        NavigationView {
            ZStack {
                Color(red: 0.94, green: 0.91, blue: 0.85).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        // Grand Total Header Banner
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(language == .traditionalChinese ? "全場累積總分" : "Grand Total")
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
                            Text(language == .traditionalChinese ? "尚未進行擊發，請回到射擊場擊發子彈。" : "No shots fired yet. Return to the range and shoot.")
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
                                            VStack(spacing: 2) {
                                                HStack(spacing: 2) {
                                                    Text("#\(shot.shotNumber)")
                                                        .font(.system(size: 9, weight: .semibold))
                                                        .foregroundColor(Color.black.opacity(0.45))

                                                    // Small Direction Indicator Arrow or Bullseye Dot
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

                                                Text(shot.clockDirection)
                                                    .font(.system(size: 8, weight: .semibold))
                                                    .foregroundColor(Color.black.opacity(0.5))
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 3)
                                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.04)))
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
            .navigationTitle(language == .traditionalChinese ? "記分表" : "Scorecard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(language == .traditionalChinese ? "關閉" : "Close", action: onClose)
                        .font(.system(size: 15, weight: .bold))
                }
            }
        }
    }
}

// MARK: - Target Board View
struct TargetBoardView: View {
    let mode: AimMode
    let radius: CGFloat // Base radius = 110pt
    let shots: [ShotRecord]

    var effectiveTargetRadius: CGFloat {
        (mode == .rifle) ? (radius * 0.42) : radius
    }

    var blackThreshold: Int {
        (mode == .pistol) ? 7 : 4
    }

    var bullseyeRadius: CGFloat {
        effectiveTargetRadius * CGFloat(11 - blackThreshold) / 10.0
    }

    var body: some View {
        ZStack {
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

            // Solid Black Bullseye (7以內 for 手槍, 4以內 for 步槍)
            Circle()
                .fill(Color(red: 0.1, green: 0.1, blue: 0.1))
                .frame(width: bullseyeRadius * 2, height: bullseyeRadius * 2)

            // Concentric Ring Lines
            ForEach(1...10, id: \.self) { ring in
                let ringR = effectiveTargetRadius * CGFloat(11 - ring) / 10.0
                let isInsideBlack = ring >= blackThreshold

                Circle()
                    .stroke(
                        isInsideBlack ? Color.white.opacity(0.9) : Color.black.opacity(0.8),
                        lineWidth: ring == 1 ? 1.2 : (isInsideBlack ? 0.9 : 0.75)
                    )
                    .frame(width: ringR * 2, height: ringR * 2)
            }

            // Center White Dot (10.9)
            Circle()
                .fill(Color.white)
                .frame(width: (mode == .rifle) ? 2.5 : 3.5, height: (mode == .rifle) ? 2.5 : 3.5)

            // Ring Numbers 1 through 8 along the 4 axes
            ringNumbersView

            // Target Corner Label
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text(mode == .pistol ? "krüger 1313 N" : "10M Air Rifle Target")
                        .font(.system(size: 7.5, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color.black.opacity(0.4))
                        .padding(4)
                }
            }
            .frame(width: radius * 2 + 14, height: radius * 2 + 14)

            // Grey Bullet Imprints (灰色的子彈印)
            ForEach(shots) { shot in
                BulletHoleView(
                    shot: shot,
                    isLatest: shot.id == shots.last?.id
                )
                .offset(x: shot.offset.x, y: shot.offset.y)
            }
        }
        .frame(width: radius * 2 + 14, height: radius * 2 + 14)
    }

    @ViewBuilder
    private var ringNumbersView: some View {
        ForEach(1...8, id: \.self) { num in
            let dist = effectiveTargetRadius * CGFloat(10.5 - Double(num)) / 10.0
            let isWhite = num >= blackThreshold
            let numColor = isWhite ? Color.white : Color.black
            let fontSize: CGFloat = (mode == .rifle) ? 6.0 : 7.5

            Text("\(num)").font(.system(size: fontSize, weight: .bold)).foregroundColor(numColor).offset(y: -dist)
            Text("\(num)").font(.system(size: fontSize, weight: .bold)).foregroundColor(numColor).offset(y: dist)
            Text("\(num)").font(.system(size: fontSize, weight: .bold)).foregroundColor(numColor).offset(x: -dist)
            Text("\(num)").font(.system(size: fontSize, weight: .bold)).foregroundColor(numColor).offset(x: dist)
        }
    }
}

// MARK: - Grey Bullet Hole View (灰色的子彈印)
struct BulletHoleView: View {
    let shot: ShotRecord
    let isLatest: Bool

    var body: some View {
        ZStack {
            Circle().fill(Color(white: 0.52)).frame(width: 7.5, height: 7.5)
            Circle().fill(Color(white: 0.28)).frame(width: 5.0, height: 5.0)
            Circle().stroke(Color(white: 0.7), lineWidth: 0.6).frame(width: 7.0, height: 7.0)

            if isLatest {
                Circle().stroke(shot.isPerfect ? Color.yellow : Color.red, lineWidth: 1.5).frame(width: 13, height: 13)
                Text(String(format: "%.1f", shot.score))
                    .font(.system(size: 8.5, weight: .heavy))
                    .foregroundColor(.white)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(shot.isPerfect ? Color.orange : Color.black.opacity(0.85)))
                    .offset(x: 12, y: -7)
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

// MARK: - Rifle Concentric Sight View (由外到內的第二個同心圓，比4分那一環大一點)
// Note: Ring 4 diameter is approx 65pt. The 2nd concentric circle is 78pt, clearly larger than ring 4!
struct RifleConcentricSightView: View {
    var body: some View {
        ZStack {
            // 1st circle (most outside housing): 124pt
            Circle()
                .stroke(Color.black.opacity(0.75), lineWidth: 12)
                .frame(width: 124, height: 124)

            // 2nd circle (由外到內第二個): 78pt (比4環的65pt直徑大，留有清晰白環光圈)
            Circle()
                .stroke(Color.black.opacity(0.85), lineWidth: 2.8)
                .frame(width: 78, height: 78)

            // Horizontal crossbars supporting the 2nd aperture
            Rectangle()
                .fill(Color.black.opacity(0.75))
                .frame(width: 22, height: 1.4)
                .offset(x: -48)

            Rectangle()
                .fill(Color.black.opacity(0.75))
                .frame(width: 22, height: 1.4)
                .offset(x: 48)

            // Fine inner target alignment ring: 16pt
            Circle()
                .stroke(Color.red.opacity(0.65), lineWidth: 1.0)
                .frame(width: 16, height: 16)

            // Center red dot: 2.2pt
            Circle()
                .fill(Color.red.opacity(0.8))
                .frame(width: 2.2, height: 2.2)
        }
    }
}

// MARK: - Instructions Sheet View
struct InstructionsSheetView: View {
    let language: AppLanguage
    let onClose: () -> Void

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.94, green: 0.90, blue: 0.82).ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        instructionItem(
                            title: language == .traditionalChinese ? "🎮 操作方式：長按瞄準，鬆手開槍" : "🎮 Controls: Hold to Aim, Release to Fire",
                            desc: language == .traditionalChinese ?
                                "• 瞄準：長按螢幕（靶面）進入「屏息穩瞄」狀態。\n• 擊發：抓準槍口微幅晃動的時機，鬆開手指即可開槍。" :
                                "• Aim: Press and hold the target area to steady your breath and aim.\n• Fire: Time your shot with the subtle barrel sway, and release your finger to fire."
                        )
                        instructionItem(
                            title: language == .traditionalChinese ? "🎯 高分瞄準訣竅" : "🎯 Pro Sighting Tips for High Scores",
                            desc: language == .traditionalChinese ?
                                "• 手槍（三點一線）：前方的凸起（準星）對齊後方缺口（照門）中央。將準星切在黑色靶心正下方一點點，即可擊中高分。\n\n• 步槍（同心圓）：透過後方圓孔（覘孔）看前方圓環。將黑心靶完整套在圓環正中間（留一圈均勻的白邊）即可。" :
                                "• Pistol (3-Point Alignment): Align the front sight post centrally inside the rear sight notch. Cut the top of the post just below the black bullseye to hit the high-score.\n\n• Rifle (Concentric Circles): Look through the rear peep hole to the front aperture ring. Center the black bullseye target completely within the front ring, leaving a uniform white border around it."
                        )
                        instructionItem(
                            title: language == .traditionalChinese ? "📊 成績與紀錄" : "📊 Scores & Match Records",
                            desc: language == .traditionalChinese ?
                                "• 打完每一發後，成績單會標示子彈的偏差方向（例如：偏向 2 點鐘方向 ↗）。\n• 點擊「結束」按鈕，即可將整場成績存入歷史記錄。" :
                                "• After each shot, the scorecard indicates its exact deviation direction (e.g. drifting toward 2 o'clock ↗).\n• Tap the 'Finish' button anytime to save your complete match to History."
                        )
                    }
                    .padding(18)
                }
            }
            .navigationTitle(language == .traditionalChinese ? "奧運射擊說明" : "Instructions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(language == .traditionalChinese ? "關閉" : "Close", action: onClose)
                        .font(.system(size: 15, weight: .bold))
                }
            }
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
