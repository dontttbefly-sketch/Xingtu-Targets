import SwiftUI

struct StarMapView: View {
    var goals: [GoalSnapshot]
    var routines: [RoutineSnapshot]
    var stats: (GoalSnapshot) -> GoalStats
    var completedCheckInCount: (String) -> Int
    var showsControls: Bool
    var selectedGoalId: String?
    var selectedRoutineId: String?
    var onSelectGoal: (String) -> Void
    var onSelectRoutine: (RoutineSnapshot) -> Void
    var onDismissFocus: (() -> Void)?

    @State private var offset: CGSize = .zero
    @State private var scale: CGFloat = 1
    @State private var isDragging = false
    @GestureState private var dragOffset: CGSize = .zero
    @GestureState private var gestureScale: CGFloat = 1

    private let motion = StarfieldMotionProfile.silky

    var body: some View {
        GeometryReader { proxy in
            if goals.isEmpty {
                ContentUnavailableView(
                    "还没有恒星",
                    systemImage: "sparkles",
                    description: Text("新建一个目标，把它放进你的私人星图。")
                )
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ZStack {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedGoalId != nil {
                                onDismissFocus?()
                            }
                        }

                    starfieldLayer(size: proxy.size)
                        .scaleEffect(currentScale)
                        .offset(currentOffset)
                    .animation(cameraAnimation, value: offset)
                    .animation(cameraAnimation, value: scale)
                    .animation(focusAnimation, value: selectedGoalId)
                    .accessibilityElement(children: .contain)

                    if showsControls {
                        StarMapControls(
                            scalePercent: Int((currentScale * 100).rounded()),
                            canZoomOut: scale > 0.72,
                            canZoomIn: scale < 1.58,
                            onZoomOut: {
                                withAnimation(cameraAnimation) {
                                    scale = clampedScale(scale - 0.15)
                                    offset = clampedOffset(offset)
                                }
                            },
                            onReset: resetCamera,
                            onZoomIn: {
                                withAnimation(cameraAnimation) {
                                    scale = clampedScale(scale + 0.15)
                                    offset = clampedOffset(offset)
                                }
                            }
                        )
                        .padding(.trailing, 14)
                        .padding(.bottom, 20)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottomTrailing)))
                    }
                }
                .contentShape(Rectangle())
                .gesture(dragGesture)
                .simultaneousGesture(zoomGesture)
            }
        }
    }

    @ViewBuilder
    private func starfieldLayer(size: CGSize) -> some View {
        ZStack {
            if let selectedGoalId,
               let selectedIndex = goals.firstIndex(where: { $0.id == selectedGoalId }) {
                let center = displayPosition(index: selectedIndex, goal: goals[selectedIndex], size: size)
                FocusGlow()
                    .frame(width: size.width * 0.82, height: size.width * 0.82)
                    .position(center)
                    .transition(.scale(scale: 0.72).combined(with: .opacity))
                    .allowsHitTesting(false)
                    .zIndex(0)
            }

            ForEach(Array(goals.enumerated()), id: \.element.id) { index, goal in
                let point = displayPosition(index: index, goal: goal, size: size)
                let goalRoutines = routines.filter { $0.goalId == goal.id }
                let isFocused = selectedGoalId == goal.id
                let isDimmed = selectedGoalId != nil && selectedGoalId != goal.id

                ForEach(Array(goalRoutines.prefix(6).enumerated()), id: \.element.id) { orbitIndex, routine in
                    MiniOrbitShell(
                        routine: routine,
                        index: orbitIndex,
                        completedCount: completedCheckInCount(routine.id),
                        isFocused: isFocused,
                        isDimmed: isDimmed,
                        isSelected: selectedRoutineId == routine.id
                    )
                    .position(point)
                    .allowsHitTesting(false)
                    .zIndex(isFocused ? 8 : 0.5)
                }

                Button {
                    onSelectGoal(goal.id)
                } label: {
                    StarNode(
                        goal: goal,
                        stats: stats(goal),
                        index: index,
                        isFocused: isFocused,
                        isDimmed: isDimmed
                    )
                }
                .buttonStyle(.plain)
                .position(point)
                .accessibilityLabel("打开目标 \(goal.title)")
                .accessibilityHint("聚焦恒星并打开目标档案")
                .zIndex(isFocused ? 10 : 1)
            }

            if let selectedGoalId,
               let selectedIndex = goals.firstIndex(where: { $0.id == selectedGoalId }) {
                let goalRoutines = routines.filter { $0.goalId == selectedGoalId }
                let center = displayPosition(index: selectedIndex, goal: goals[selectedIndex], size: size)

                ForEach(Array(goalRoutines.prefix(8).enumerated()), id: \.element.id) { index, routine in
                    Button {
                        onSelectRoutine(routine)
                    } label: {
                        RoutineOrbitLabel(
                            routine: routine,
                            isSelected: selectedRoutineId == routine.id
                        )
                    }
                    .buttonStyle(.plain)
                    .position(routinePosition(index: index, count: min(goalRoutines.count, 8), center: center))
                    .contentShape(Rectangle())
                    .accessibilityLabel("打开轨道 \(routine.title)")
                    .accessibilityHint("快速打卡、编辑或进入所属目标")
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(20)
                }
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private var currentScale: CGFloat {
        clampedScale(scale * gestureScale)
    }

    private var currentOffset: CGSize {
        clampedOffset(
            CGSize(
                width: offset.width + dragOffset.width * 0.62,
                height: offset.height + dragOffset.height * 0.62
            )
        )
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { _ in
                if !isDragging {
                    isDragging = true
                }
            }
            .updating($dragOffset) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                let momentum = CGSize(
                    width: (value.predictedEndTranslation.width - value.translation.width) * 0.045,
                    height: (value.predictedEndTranslation.height - value.translation.height) * 0.045
                )
                withAnimation(cameraAnimation) {
                    offset = clampedOffset(
                        CGSize(
                            width: offset.width + value.translation.width * 0.62 + momentum.width,
                            height: offset.height + value.translation.height * 0.62 + momentum.height
                        )
                    )
                    isDragging = false
                }
            }
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .updating($gestureScale) { value, state, _ in
                state = value
            }
            .onEnded { value in
                withAnimation(cameraAnimation) {
                    scale = clampedScale(scale * value)
                }
            }
    }

    private var cameraAnimation: Animation {
        .spring(
            response: motion.cameraResponse,
            dampingFraction: motion.cameraDampingFraction,
            blendDuration: 0.08
        )
    }

    private var focusAnimation: Animation {
        .spring(
            response: motion.focusResponse,
            dampingFraction: motion.focusDampingFraction,
            blendDuration: 0.10
        )
    }

    private func resetCamera() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            offset = .zero
            scale = 1
        }
    }

    private func displayPosition(index: Int, goal: GoalSnapshot, size: CGSize) -> CGPoint {
        let point = starPosition(index: index, size: size)
        guard selectedGoalId != nil else {
            return point
        }
        guard let selectedIndex = goals.firstIndex(where: { $0.id == selectedGoalId }) else {
            return point
        }
        let unitPoint = starfieldFocusedUnitPoint(
            index: index,
            selectedIndex: selectedIndex,
            totalCount: goals.count
        )
        return CGPoint(x: size.width * unitPoint.x, y: size.height * unitPoint.y)
    }

    private func starPosition(index: Int, size: CGSize) -> CGPoint {
        let goal = goals[index]
        let unitPoint: StarfieldUnitPoint
        if goal.status == .completed {
            let completedGoals = goals.filter { $0.status == .completed }
            let completedIndex = completedGoals.firstIndex(where: { $0.id == goal.id }) ?? 0
            unitPoint = starfieldCompletedConstellationUnitPoint(index: completedIndex, totalCount: completedGoals.count)
        } else {
            let activeGoals = goals.filter { $0.status == .active }
            let activeIndex = activeGoals.firstIndex(where: { $0.id == goal.id }) ?? index
            unitPoint = starfieldOverviewUnitPoint(index: activeIndex, totalCount: activeGoals.count)
        }
        return CGPoint(x: size.width * unitPoint.x, y: size.height * unitPoint.y)
    }

    private func routinePosition(index: Int, count: Int, center: CGPoint) -> CGPoint {
        let angle = (Double(index) / Double(max(count, 1))) * .pi * 2 - .pi / 2
        let radius = CGFloat(112 + min(count, 4) * 9)
        return CGPoint(
            x: center.x + CGFloat(cos(angle)) * radius,
            y: center.y + CGFloat(sin(angle)) * radius * 0.72
        )
    }

    private func clampedScale(_ value: CGFloat) -> CGFloat {
        min(1.7, max(0.65, value))
    }

    private func clampedOffset(_ value: CGSize) -> CGSize {
        let clamped = clampedStarfieldCameraOffset(
            width: Double(value.width),
            height: Double(value.height),
            scale: Double(currentScale)
        )
        return CGSize(
            width: CGFloat(clamped.width),
            height: CGFloat(clamped.height)
        )
    }
}

private struct StarNode: View {
    var goal: GoalSnapshot
    var stats: GoalStats
    var index: Int
    var isFocused: Bool
    var isDimmed: Bool
    @State private var shimmer = false

    private let motion = StarfieldMotionProfile.silky

    var body: some View {
        VStack(spacing: 7) {
            ZStack {
                CelestialPlanet(
                    tone: planetTone,
                    progress: completionGlow,
                    size: innerSize,
                    outerSize: outerSize,
                    isFocused: isFocused,
                    isDimmed: isDimmed,
                    shimmerExpansion: shimmerExpansion
                )

                Text("\(stats.completionRate)%")
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(isDimmed ? 0.42 : 0.90))
                    .shadow(color: .black.opacity(0.45), radius: 3, y: 1)
            }

            Text(goal.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(isDimmed ? 0.34 : 0.92))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: isFocused ? 154 : 112)

            Text(goal.status == .completed ? "已点亮" : "\(stats.completionRate)%")
                .font(.caption2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(isDimmed ? 0.24 : 0.58))
        }
        .scaleEffect((isFocused ? 1.48 : 1) * (shimmer && !isDimmed ? 1.012 : 1))
        .opacity(isDimmed ? 0.42 : 1)
        .animation(
            .spring(
                response: motion.focusResponse,
                dampingFraction: motion.focusDampingFraction,
                blendDuration: 0.10
            ),
            value: isFocused
        )
        .animation(.easeInOut(duration: motion.ambientDriftDuration).repeatForever(autoreverses: true), value: shimmer)
        .onAppear {
            shimmer = true
        }
        .accessibilityLabel("进入 \(goal.title)")
    }

    private var completionGlow: Double {
        min(1, max(0, Double(stats.completionRate) / 100))
    }

    private var innerSize: CGFloat {
        let base = 54 + CGFloat(stats.routineCount * 6)
        let completion = CGFloat(stats.completionRate) * 0.18
        return min(98, max(52, base + completion))
    }

    private var outerSize: CGFloat {
        innerSize + (isFocused ? 48 : 32)
    }

    private var shimmerExpansion: CGFloat {
        shimmer && !isDimmed ? 8 : 0
    }

    private var planetTone: PlanetRenderTone {
        PlanetRenderTone(starfieldPlanetTone(index: index, customHex: goal.colorHex))
    }
}

private struct PlanetRenderTone {
    var core: Color
    var mantle: Color
    var shadow: Color
    var atmosphere: Color
    var accent: Color

    init(_ tone: StarfieldPlanetTone) {
        self.core = Color(starfieldHex: tone.coreHex) ?? .white
        self.mantle = Color(starfieldHex: tone.mantleHex) ?? Color(red: 0.58, green: 0.74, blue: 0.86)
        self.shadow = Color(starfieldHex: tone.shadowHex) ?? Color(red: 0.08, green: 0.10, blue: 0.16)
        self.atmosphere = Color(starfieldHex: tone.atmosphereHex) ?? Color(red: 0.56, green: 0.88, blue: 1.0)
        self.accent = Color(starfieldHex: tone.accentHex) ?? Color(red: 0.70, green: 0.92, blue: 0.82)
    }
}

private struct CelestialPlanet: View {
    var tone: PlanetRenderTone
    var progress: Double
    var size: CGFloat
    var outerSize: CGFloat
    var isFocused: Bool
    var isDimmed: Bool
    var shimmerExpansion: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            tone.atmosphere.opacity(isDimmed ? 0.07 : 0.24 + progress * 0.14),
                            tone.accent.opacity(isDimmed ? 0.03 : 0.10 + progress * 0.10),
                            .clear
                        ],
                        center: .center,
                        startRadius: 5,
                        endRadius: outerSize * 0.54
                    )
                )
                .frame(width: outerSize + shimmerExpansion, height: outerSize + shimmerExpansion)
                .blur(radius: isFocused ? 14 : 8)
                .blendMode(.screen)

            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            tone.atmosphere.opacity(0.02),
                            tone.atmosphere.opacity(isDimmed ? 0.08 : 0.42),
                            tone.accent.opacity(isDimmed ? 0.04 : 0.24),
                            tone.atmosphere.opacity(0.02)
                        ],
                        center: .center
                    ),
                    lineWidth: isFocused ? 1.2 : 0.8
                )
                .frame(width: size + 18, height: size + 18)
                .blur(radius: 0.5)

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(isDimmed ? 0.18 : 0.90),
                                tone.core.opacity(isDimmed ? 0.40 : 1),
                                tone.mantle.opacity(isDimmed ? 0.28 : 0.95),
                                tone.shadow.opacity(isDimmed ? 0.68 : 0.96)
                            ],
                            center: UnitPoint(x: 0.32, y: 0.24),
                            startRadius: 1,
                            endRadius: size * 0.82
                        )
                    )

                PlanetSurfaceBands(tone: tone, size: size, isDimmed: isDimmed)
                    .clipShape(Circle())
                    .opacity(isDimmed ? 0.28 : 0.72)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                .clear,
                                tone.shadow.opacity(isDimmed ? 0.44 : 0.28),
                                tone.shadow.opacity(isDimmed ? 0.74 : 0.52)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())

                Circle()
                    .trim(from: 0, to: CGFloat(max(0.05, progress)))
                    .stroke(
                        LinearGradient(
                            colors: [
                                tone.accent.opacity(isDimmed ? 0.18 : 0.86),
                                tone.atmosphere.opacity(isDimmed ? 0.12 : 0.50)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: isFocused ? 2.6 : 1.8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .padding(isFocused ? -5 : -3)

                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [
                                .white.opacity(isDimmed ? 0.10 : 0.46),
                                tone.atmosphere.opacity(isDimmed ? 0.08 : 0.28),
                                tone.shadow.opacity(isDimmed ? 0.18 : 0.42),
                                .white.opacity(isDimmed ? 0.05 : 0.22)
                            ],
                            center: .center
                        ),
                        lineWidth: 1.1
                    )

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                .white.opacity(isDimmed ? 0.08 : 0.50),
                                .white.opacity(isDimmed ? 0.02 : 0.12),
                                .clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: size * 0.23
                        )
                    )
                    .frame(width: size * 0.46, height: size * 0.46)
                    .offset(x: -size * 0.16, y: -size * 0.18)
            }
            .frame(width: size, height: size)
            .shadow(
                color: tone.atmosphere.opacity(isDimmed ? 0.12 : 0.34 + progress * 0.22),
                radius: (isFocused ? 26 : 17) + shimmerExpansion * 0.42,
                y: isFocused ? 0 : 2
            )
        }
    }
}

private struct PlanetSurfaceBands: View {
    var tone: PlanetRenderTone
    var size: CGFloat
    var isDimmed: Bool

    var body: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { band in
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                .clear,
                                bandColor(band).opacity(isDimmed ? 0.10 : bandOpacity(band)),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(
                        width: size * (0.94 - CGFloat(band) * 0.08),
                        height: max(3, size * (0.052 + CGFloat(band % 2) * 0.018))
                    )
                    .rotationEffect(.degrees(-15 + Double(band) * 8))
                    .offset(
                        x: CGFloat(band.isMultiple(of: 2) ? -4 : 5),
                        y: -size * 0.22 + CGFloat(band) * size * 0.14
                    )
                    .blur(radius: band == 0 ? 0.55 : 0.25)
            }
        }
    }

    private func bandColor(_ index: Int) -> Color {
        index.isMultiple(of: 2) ? tone.accent : tone.atmosphere
    }

    private func bandOpacity(_ index: Int) -> Double {
        index.isMultiple(of: 2) ? 0.44 : 0.28
    }
}

private struct FocusGlow: View {
    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        .white.opacity(0.22),
                        Color(red: 0.61, green: 0.95, blue: 0.81).opacity(0.16),
                        Color(red: 0.41, green: 0.84, blue: 1.0).opacity(0.10),
                        .clear
                    ],
                    center: .center,
                    startRadius: 12,
                    endRadius: 260
                )
            )
            .blendMode(.screen)
            .blur(radius: 6)
    }
}

private struct MiniOrbitShell: View {
    var routine: RoutineSnapshot
    var index: Int
    var completedCount: Int
    var isFocused: Bool
    var isDimmed: Bool
    var isSelected: Bool

    @State private var spinning = false

    var body: some View {
        ZStack {
            Ellipse()
                .stroke(orbitColor.opacity(orbitOpacity), lineWidth: isSelected ? 1.4 : 1)
                .frame(width: radius * 2, height: radius * 1.42)
                .shadow(color: orbitColor.opacity(isSelected ? 0.20 : 0.06), radius: isSelected ? 18 : 8)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .white.opacity(isDimmed ? 0.10 : 0.70),
                            planetColor.opacity(isDimmed ? 0.22 : planetOpacity),
                            planetShadow.opacity(isDimmed ? 0.28 : 0.72)
                        ],
                        center: UnitPoint(x: 0.30, y: 0.24),
                        startRadius: 0,
                        endRadius: planetSize
                    )
                )
                .frame(width: planetSize, height: planetSize)
                .shadow(color: planetColor.opacity(isDimmed ? 0.10 : 0.70), radius: isFocused ? 16 : 10)
                .offset(y: -(radius * 0.71))
                .rotationEffect(.degrees(spinning ? 360 : 0))
                .animation(
                    .linear(duration: spinDuration)
                    .repeatForever(autoreverses: false),
                    value: spinning
                )
        }
        .rotationEffect(.degrees(tilt))
        .scaleEffect(isFocused ? 1 : 0.72)
        .opacity(isDimmed ? 0.14 : 1)
        .animation(.spring(response: 0.52, dampingFraction: 0.82), value: isFocused)
        .animation(.easeInOut(duration: 0.20), value: isSelected)
        .onAppear {
            spinning = true
        }
        .accessibilityHidden(true)
    }

    private var radius: CGFloat {
        let base = isFocused ? CGFloat(116 + index * 28) : CGFloat(44 + index * 13)
        return base + CGFloat(abs(routine.id.hashValue % 9))
    }

    private var tilt: Double {
        Double(-18 + abs(routine.id.hashValue % 36))
    }

    private var spinDuration: Double {
        Double(32 + index * 8 + abs(routine.id.hashValue % 16))
    }

    private var planetSize: CGFloat {
        isFocused ? (completedCount > 0 ? 11 : 9) : CGFloat(6 + abs(routine.id.hashValue % 3))
    }

    private var orbitOpacity: Double {
        if isDimmed {
            return 0.08
        }
        if isSelected {
            return 0.58
        }
        return isFocused ? 0.32 + Double(index % 2) * 0.08 : 0.18 + Double(index % 3) * 0.05
    }

    private var planetOpacity: Double {
        completedCount > 0 ? 1 : 0.40
    }

    private var orbitColor: Color {
        isSelected ? Color(red: 1.0, green: 0.83, blue: 0.42) : Color(red: 0.56, green: 0.84, blue: 0.90)
    }

    private var planetColor: Color {
        isSelected ? Color(red: 1.0, green: 0.90, blue: 0.62) : Color(red: 0.74, green: 0.92, blue: 0.80)
    }

    private var planetShadow: Color {
        isSelected ? Color(red: 0.34, green: 0.22, blue: 0.13) : Color(red: 0.10, green: 0.20, blue: 0.24)
    }
}

private extension Color {
    init?(starfieldHex: String) {
        let raw = starfieldHex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard raw.count == 6, let value = UInt64(raw, radix: 16) else {
            return nil
        }
        let red = Double((value & 0xFF0000) >> 16) / 255
        let green = Double((value & 0x00FF00) >> 8) / 255
        let blue = Double(value & 0x0000FF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}

private struct RoutineOrbitLabel: View {
    var routine: RoutineSnapshot
    var isSelected: Bool
    @State private var appeared = false

    private let motion = StarfieldMotionProfile.silky

    var body: some View {
        Label(routine.title, systemImage: isSelected ? "largecircle.fill.circle" : "circle.dotted")
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(minWidth: 104, maxWidth: 156)
            .background(
                LinearGradient(
                    colors: [
                        (isSelected ? Color(red: 0.32, green: 0.22, blue: 0.10) : Color(red: 0.08, green: 0.12, blue: 0.18)).opacity(0.80),
                        (isSelected ? Color(red: 0.28, green: 0.30, blue: 0.22) : Color(red: 0.08, green: 0.18, blue: 0.23)).opacity(0.62)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isSelected
                            ? Color(red: 1.0, green: 0.83, blue: 0.42).opacity(0.54)
                            : Color(red: 0.56, green: 0.84, blue: 0.90).opacity(0.22),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.28), radius: 10, y: 6)
            .shadow(
                color: (isSelected ? Color(red: 1.0, green: 0.83, blue: 0.42) : Color(red: 0.56, green: 0.84, blue: 0.90)).opacity(isSelected ? 0.18 : 0.08),
                radius: isSelected ? 14 : 8
            )
            .scaleEffect(appeared ? 1 : 0.82)
            .opacity(appeared ? 1 : 0)
            .animation(
                .spring(response: motion.focusResponse, dampingFraction: motion.focusDampingFraction, blendDuration: 0.08),
                value: appeared
            )
            .animation(.easeInOut(duration: 0.18), value: isSelected)
            .onAppear {
                appeared = true
            }
    }
}

private struct StarMapControls: View {
    var scalePercent: Int
    var canZoomOut: Bool
    var canZoomIn: Bool
    var onZoomOut: () -> Void
    var onReset: () -> Void
    var onZoomIn: () -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            HStack(spacing: 6) {
                controlButton(systemImage: "minus", action: onZoomOut)
                    .disabled(!canZoomOut)
                controlButton(systemImage: "arrow.counterclockwise", action: onReset)
                controlButton(systemImage: "plus", action: onZoomIn)
                    .disabled(!canZoomIn)

                Text("\(scalePercent)%")
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.68))
                    .frame(width: 46)
            }
            .padding(7)
            .background(.black.opacity(0.36), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.white.opacity(0.14), lineWidth: 1)
            )

            Label("拖拽查看星域", systemImage: "scope")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white.opacity(0.62))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.black.opacity(0.50), in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.white.opacity(0.14), lineWidth: 1)
                )
        }
    }

    private func controlButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .frame(width: 32, height: 32)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(StarControlButtonStyle())
        .foregroundStyle(.white)
    }
}

private struct StarControlButtonStyle: ButtonStyle {
    private let motion = StarfieldMotionProfile.silky

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? CGFloat(motion.pressScale) : 1)
            .opacity(configuration.isPressed ? 0.78 : 1)
            .animation(.spring(response: 0.18, dampingFraction: 0.78), value: configuration.isPressed)
    }
}
