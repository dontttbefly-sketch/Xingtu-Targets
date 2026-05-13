import StarfieldGoalsCore
import SwiftUI
#if os(macOS)
@preconcurrency import AppKit
#endif

struct StarMapView: View {
    var goals: [Goal]
    var routines: [Routine]
    var checkIns: [CheckIn]
    @Binding var selectedGoalId: String?

    var onSelectGoal: (String) -> Void
    var onExitFocus: () -> Void
    var onSelectRoutine: (String) -> Void

    @State private var pan: CGSize = .zero
    @State private var dragStart: CGSize?
    @State private var zoom: CGFloat = 1
    @State private var zoomStart: CGFloat?
    @State private var hoverLocation: CGPoint?
    @State private var hoveredGoalId: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let camera = cameraState(in: size)
            let inverseCameraScale = StarMapLayout.screenFixedScale(cameraZoom: camera.zoom)
            let parallax = parallaxOffset(in: size)

            ZStack {
                CosmicBackground(
                    cameraOffset: camera.offset,
                    parallax: parallax,
                    focusActive: selectedGoalId != nil
                )

#if os(macOS)
                ScrollWheelZoomCapture(enabled: selectedGoalId == nil) { delta, location in
                    applyWheelZoom(delta: delta, at: location)
                }
#endif

                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if selectedGoalId != nil {
                            onExitFocus()
                        }
                    }

                ZStack {
                    StarfieldConnections(
                        goals: goals,
                        selectedGoalId: selectedGoalId,
                        size: size,
                        positionForGoal: { index in
                            goalPosition(index: index, total: goals.count, in: size)
                        }
                    )

                    ForEach(Array(goals.enumerated()), id: \.element.id) { index, goal in
                        let goalRoutines = routines.filter { $0.goalId == goal.id }
                        let isSelected = selectedGoalId == goal.id
                        let isHovered = hoveredGoalId == goal.id
                        let position = goalPosition(index: index, total: goals.count, in: size)

                        StarSystemVisual(
                            goal: goal,
                            routines: goalRoutines,
                            checkIns: checkIns,
                            focused: isSelected,
                            hovered: isHovered
                        )
                        .position(position)
                        .opacity(selectedGoalId == nil || isSelected ? 1 : 0.22)
                        .blur(radius: selectedGoalId == nil || isSelected ? 0 : 1.6)
                        .allowsHitTesting(false)

                        if isSelected {
                            FocusRoutineLabels(
                                routines: Array(goalRoutines.prefix(8)),
                                checkIns: checkIns,
                                compact: size.width < 760,
                                onSelectRoutine: onSelectRoutine
                            )
                            .scaleEffect(inverseCameraScale)
                            .position(position)
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                            .zIndex(5)
                        }

                        Button {
                            if selectedGoalId == nil {
                                onSelectGoal(goal.id)
                            }
                        } label: {
                            Color.clear
                                .frame(
                                    width: StarMapLayout.starHitDiameter(focused: isSelected),
                                    height: StarMapLayout.starHitDiameter(focused: isSelected)
                                )
                                .contentShape(Circle())
                        }
                        .accessibilityLabel(goal.title)
                        .buttonStyle(.plain)
                        .scaleEffect(inverseCameraScale)
                        .position(position)
                        .onHover { hovering in
                            hoveredGoalId = hovering ? goal.id : (hoveredGoalId == goal.id ? nil : hoveredGoalId)
                        }
                        .allowsHitTesting(selectedGoalId == nil)
                        .zIndex(3)
                    }

                    if goals.isEmpty {
                        EmptyStarfieldHint()
                            .position(x: size.width * 0.5, y: size.height * 0.53)
                    }
                }
                .scaleEffect(camera.zoom, anchor: .topLeading)
                .offset(camera.offset)
                .rotation3DEffect(.degrees(Double(parallax.height) * 0.34), axis: (x: 1, y: 0, z: 0), perspective: 0.82)
                .rotation3DEffect(.degrees(Double(parallax.width) * -0.28), axis: (x: 0, y: 1, z: 0), perspective: 0.82)
                .animation(.smooth(duration: selectedGoalId == nil ? 0.72 : 0.95), value: selectedGoalId)
                .animation(.smooth(duration: 0.22), value: zoom)
                .animation(.smooth(duration: 0.18), value: pan)

                if selectedGoalId != nil {
                    FocusObservationOverlay(target: focusTarget(in: size))
                        .transition(.opacity.combined(with: .scale(scale: 1.04)))
                        .allowsHitTesting(false)
                }

                VStack {
                    Spacer()
                    HStack {
                        zoomControls
                        Spacer()
                    }
                    .padding(.leading, 22)
                    .padding(.bottom, 22)
                }
            }
            .gesture(freeDragGesture)
            .simultaneousGesture(freeMagnificationGesture)
            .onContinuousHover { phase in
                switch phase {
                case let .active(location):
                    if reduceMotion {
                        hoverLocation = location
                    } else {
                        withAnimation(.smooth(duration: 0.24)) {
                            hoverLocation = location
                        }
                    }
                case .ended:
                    if reduceMotion {
                        hoverLocation = nil
                    } else {
                        withAnimation(.smooth(duration: 0.32)) {
                            hoverLocation = nil
                        }
                    }
                    hoveredGoalId = nil
                }
            }
        }
        .ignoresSafeArea()
    }

    private var zoomControls: some View {
        HStack(spacing: 6) {
            Button("-") {
                zoom = clampZoom(zoom - 0.12)
            }
            Button("归位") {
                pan = .zero
                zoom = 1
            }
            Button("+") {
                zoom = clampZoom(zoom + 0.12)
            }
        }
        .font(.system(size: 12, weight: .semibold, design: .rounded))
        .buttonStyle(HUDButtonStyle())
        .opacity(selectedGoalId == nil ? 1 : 0.2)
        .disabled(selectedGoalId != nil)
    }

    private var freeDragGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                guard selectedGoalId == nil else {
                    return
                }
                let start = dragStart ?? pan
                dragStart = start
                pan = CGSize(width: start.width + value.translation.width, height: start.height + value.translation.height)
            }
            .onEnded { _ in
                dragStart = nil
                pan = CGSize(
                    width: min(420, max(-420, pan.width)),
                    height: min(320, max(-320, pan.height))
                )
            }
    }

    private var freeMagnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                guard selectedGoalId == nil else {
                    return
                }
                let start = zoomStart ?? zoom
                zoomStart = start
                zoom = clampZoom(start * value)
            }
            .onEnded { _ in
                zoomStart = nil
            }
    }

    private func cameraState(in size: CGSize) -> (zoom: CGFloat, offset: CGSize) {
        if let selectedGoalId,
           let selectedIndex = goals.firstIndex(where: { $0.id == selectedGoalId }) {
            let selectedRoutines = routines.filter { $0.goalId == selectedGoalId }
            let focusZoom = StarMapLayout.focusZoom(routineCount: selectedRoutines.count, viewportWidth: size.width)
            let position = goalPosition(index: selectedIndex, total: goals.count, in: size)
            let target = focusTarget(in: size)
            return (
                zoom: focusZoom,
                offset: CGSize(
                    width: target.x - position.x * focusZoom,
                    height: target.y - position.y * focusZoom
                )
            )
        }

        let automatic = StarMapLayout.automaticZoom(goalCount: goals.count)
        return (automatic * zoom, pan)
    }

    private func focusTarget(in size: CGSize) -> CGPoint {
        if size.width < 760 {
            return CGPoint(x: size.width * 0.5, y: size.height * 0.32)
        }
        return CGPoint(x: size.width * 0.34, y: size.height * 0.53)
    }

    private func goalPosition(index: Int, total: Int, in size: CGSize) -> CGPoint {
        let presets: [(CGFloat, CGFloat)] = [
            (0.45, 0.50), (0.56, 0.43), (0.38, 0.62), (0.62, 0.60),
            (0.34, 0.42), (0.51, 0.68), (0.66, 0.36), (0.42, 0.35),
            (0.58, 0.70), (0.31, 0.54), (0.69, 0.53), (0.50, 0.37)
        ]
        if index < presets.count {
            return CGPoint(x: size.width * presets[index].0, y: size.height * presets[index].1)
        }

        let angle = CGFloat(index) * 2.399963
        let radius = min(size.width, size.height) * min(0.24, 0.12 + CGFloat(index % 5) * 0.025)
        return CGPoint(
            x: size.width * 0.5 + cos(angle) * radius,
            y: size.height * 0.52 + sin(angle) * radius * 0.76
        )
    }

    private func clampZoom(_ value: CGFloat) -> CGFloat {
        min(1.55, max(0.72, value))
    }

    private func applyWheelZoom(delta: CGFloat, at location: CGPoint) {
        guard selectedGoalId == nil else {
            return
        }

        let boundedDelta = min(28, max(-28, delta))
        let nextZoom = clampZoom(zoom * exp(boundedDelta * 0.006))
        guard abs(nextZoom - zoom) > 0.001 else {
            return
        }

        let automatic = StarMapLayout.automaticZoom(goalCount: goals.count)
        let nextPan = StarMapLayout.anchoredPanAfterZoom(
            pointer: location,
            currentPan: pan,
            oldCameraZoom: automatic * zoom,
            newCameraZoom: automatic * nextZoom
        )
        let updates = {
            zoom = nextZoom
            pan = clampedPan(nextPan)
        }

        if reduceMotion {
            updates()
        } else {
            withAnimation(.smooth(duration: 0.18)) {
                updates()
            }
        }
    }

    private func clampedPan(_ value: CGSize) -> CGSize {
        CGSize(
            width: min(520, max(-520, value.width)),
            height: min(380, max(-380, value.height))
        )
    }

    private func parallaxOffset(in size: CGSize) -> CGSize {
        guard let hoverLocation, selectedGoalId == nil, reduceMotion == false else {
            return .zero
        }
        let normalizedX = (hoverLocation.x / max(size.width, 1) - 0.5) * 2
        let normalizedY = (hoverLocation.y / max(size.height, 1) - 0.5) * 2
        return CGSize(width: normalizedX * 10, height: normalizedY * 8)
    }
}

#if os(macOS)
private struct ScrollWheelZoomCapture: NSViewRepresentable {
    var enabled: Bool
    var onScroll: (CGFloat, CGPoint) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSView {
        let view = PassthroughScrollView()
        context.coordinator.view = view
        context.coordinator.installMonitorIfNeeded()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.view = nsView
        context.coordinator.installMonitorIfNeeded()
    }

    @MainActor
    final class Coordinator {
        var parent: ScrollWheelZoomCapture
        weak var view: NSView?
        nonisolated(unsafe) private var monitor: Any?

        init(parent: ScrollWheelZoomCapture) {
            self.parent = parent
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }

        func installMonitorIfNeeded() {
            guard monitor == nil else {
                return
            }

            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                let windowNumber = event.windowNumber
                let pointX = event.locationInWindow.x
                let pointY = event.locationInWindow.y
                let delta = event.scrollingDeltaY == 0 ? -event.scrollingDeltaX : event.scrollingDeltaY
                Task { @MainActor [weak self] in
                    self?.handle(windowNumber: windowNumber, pointX: pointX, pointY: pointY, delta: delta)
                }
                return event
            }
        }

        private func handle(windowNumber: Int, pointX: CGFloat, pointY: CGFloat, delta: CGFloat) {
            guard parent.enabled,
                  let view,
                  view.window?.windowNumber == windowNumber
            else {
                return
            }

            let locationInView = view.convert(CGPoint(x: pointX, y: pointY), from: nil)
            guard view.bounds.contains(locationInView) else {
                return
            }

            let swiftUILocation = CGPoint(
                x: locationInView.x,
                y: view.bounds.height - locationInView.y
            )
            if abs(delta) > 0.01 {
                parent.onScroll(delta, swiftUILocation)
            }
        }
    }

    private final class PassthroughScrollView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }
    }
}
#endif

private struct CosmicBackground: View {
    var cameraOffset: CGSize
    var parallax: CGSize
    var focusActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                draw(
                    context: &context,
                    size: size,
                    time: reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate,
                    activeParallax: reduceMotion ? .zero : parallax
                )
            }
        }
    }

    private func draw(context: inout GraphicsContext, size: CGSize, time: TimeInterval, activeParallax: CGSize) {
            let rect = CGRect(origin: .zero, size: size)
            context.fill(
                Path(rect),
                with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.015, green: 0.019, blue: 0.036),
                        Color(red: 0.028, green: 0.034, blue: 0.061),
                        Color(red: 0.019, green: 0.025, blue: 0.044)
                    ]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: size.width, y: size.height)
                )
            )

            drawNebula(in: &context, size: size, time: time, activeParallax: activeParallax)

            for index in 0..<210 {
                let depth = CGFloat((index % 5) + 1)
                let drift = CGFloat(sin(time * 0.018 + Double(index))) * depth * 0.8
                let xSeed = CGFloat((index * 89) % 997) / 997
                let ySeed = CGFloat((index * 233) % 991) / 991
                let x = wrap(xSeed * size.width + cameraOffset.width * 0.018 * depth + activeParallax.width * depth * 0.42 + drift, max: size.width)
                let y = wrap(ySeed * size.height + cameraOffset.height * 0.016 * depth + activeParallax.height * depth * 0.42, max: size.height)
                let radius = CGFloat((index % 3) + 1) * (focusActive ? 0.36 : 0.44)
                let alpha = 0.13 + Double((index * 37) % 70) / 115
                let path = Path(ellipseIn: CGRect(x: x, y: y, width: radius, height: radius))
                context.fill(path, with: .color(.white.opacity(alpha)))
            }

            let gridColor = Color(red: 0.66, green: 0.78, blue: 0.95).opacity(0.045)
            for x in stride(from: CGFloat(0), through: size.width, by: 86) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(gridColor), lineWidth: 0.6)
            }
            for y in stride(from: CGFloat(0), through: size.height, by: 86) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(gridColor), lineWidth: 0.6)
            }
    }

    private func drawNebula(in context: inout GraphicsContext, size: CGSize, time: TimeInterval, activeParallax: CGSize) {
        let centers = [
            CGPoint(x: size.width * 0.20 + activeParallax.width * 1.8, y: size.height * 0.24 + activeParallax.height * 1.4),
            CGPoint(x: size.width * 0.75 - activeParallax.width * 1.1, y: size.height * 0.68 - activeParallax.height * 1.2),
            CGPoint(x: size.width * 0.54 + CGFloat(sin(time * 0.016)) * 18, y: size.height * 0.42)
        ]

        for (index, center) in centers.enumerated() {
            let radius = min(size.width, size.height) * CGFloat(index == 2 ? 0.30 : 0.40)
            let colors: [Color] = index == 1
                ? [Color(red: 0.22, green: 0.36, blue: 0.52).opacity(0.22), .clear]
                : [Color(red: 0.43, green: 0.26, blue: 0.52).opacity(0.18), .clear]
            let path = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius * 0.62, width: radius * 2, height: radius * 1.24))
            context.fill(
                path,
                with: .radialGradient(
                    Gradient(colors: colors),
                    center: center,
                    startRadius: 0,
                    endRadius: radius
                )
            )
        }
    }

    private func wrap(_ value: CGFloat, max: CGFloat) -> CGFloat {
        guard max > 0 else {
            return value
        }
        let remainder = value.truncatingRemainder(dividingBy: max)
        return remainder >= 0 ? remainder : remainder + max
    }
}

private struct StarfieldConnections: View {
    var goals: [Goal]
    var selectedGoalId: String?
    var size: CGSize
    var positionForGoal: (Int) -> CGPoint

    var body: some View {
        Canvas { context, _ in
            guard goals.count > 1 else {
                return
            }

            for index in 1..<goals.count {
                let previous = positionForGoal(index - 1)
                let current = positionForGoal(index)
                var path = Path()
                path.move(to: previous)
                let control = CGPoint(
                    x: (previous.x + current.x) / 2,
                    y: (previous.y + current.y) / 2 - size.height * 0.05
                )
                path.addQuadCurve(to: current, control: control)
                context.stroke(
                    path,
                    with: .linearGradient(
                        Gradient(colors: [
                            .white.opacity(selectedGoalId == nil ? 0.08 : 0.035),
                            Color(red: 0.68, green: 0.77, blue: 0.96).opacity(selectedGoalId == nil ? 0.11 : 0.04)
                        ]),
                        startPoint: previous,
                        endPoint: current
                    ),
                    style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [4, 13])
                )
            }
        }
        .allowsHitTesting(false)
    }
}

private struct StarSystemVisual: View {
    var goal: Goal
    var routines: [Routine]
    var checkIns: [CheckIn]
    var focused: Bool
    var hovered: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let diameter = visualDiameter
        let center = diameter / 2

        TimelineView(.animation) { timeline in
            let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate

            ZStack {
                if focused || hovered {
                    CoronaSweep(starColor: starColor, focused: focused, time: time)
                        .frame(width: focused ? 238 : 78, height: focused ? 238 : 78)
                        .position(x: center, y: center)
                        .opacity(focused ? 0.88 : 0.48)
                }

                ForEach(Array(routines.prefix(focused ? 8 : 5).enumerated()), id: \.element.id) { index, routine in
                    let radius = orbitRadius(index: index, focused: focused)
                    let angle = time / orbitPeriod(index: index) + seededAngle(routine.id)
                    let completedToday = DomainLogic.isRoutineCompletedOnDate(checkIns, routineId: routine.id, date: DomainLogic.todayISO())
                    let planet = CGPoint(
                        x: center + cos(angle) * radius,
                        y: center + sin(angle) * radius * 0.72
                    )

                    Ellipse()
                        .stroke(
                            completedToday ? Color(red: 0.95, green: 0.82, blue: 0.50).opacity(focused ? 0.40 : 0.25) : .white.opacity(focused ? 0.24 : 0.11),
                            lineWidth: completedToday ? (focused ? 1.8 : 1.1) : (focused ? 1.2 : 0.7)
                        )
                        .frame(width: radius * 2, height: radius * 1.44)
                        .rotation3DEffect(.degrees(focused ? 4 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.75)
                        .position(x: center, y: center)

                    Circle()
                        .fill(planetColor(for: routine))
                        .frame(width: focused ? 8 : 5, height: focused ? 8 : 5)
                        .shadow(color: planetColor(for: routine).opacity(0.7), radius: focused ? 10 : 5)
                        .position(planet)
                }

                Circle()
                    .fill(starGradient)
                    .frame(width: focused ? 102 : (hovered ? 32 : 26), height: focused ? 102 : (hovered ? 32 : 26))
                    .shadow(color: starColor.opacity(goal.status == .completed ? 0.9 : 0.45 + completionSignal * 0.35), radius: focused ? 52 + completionSignal * 18 : (hovered ? 26 : 18) + completionSignal * 9)
                    .position(x: center, y: center)
                    .scaleEffect(1 + CGFloat(sin(time * 1.35)) * (focused ? 0.012 : 0.018))

                Circle()
                    .stroke(starColor.opacity(focused ? 0.22 : 0.16), lineWidth: focused ? 18 : 7)
                    .blur(radius: focused ? 18 : 8)
                    .frame(width: focused ? 178 : (hovered ? 68 : 52), height: focused ? 178 : (hovered ? 68 : 52))
                    .position(x: center, y: center)

                Text(goal.title)
                    .font(.system(size: focused ? 15 : 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(focused ? 0.92 : 0.72))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minWidth: focused ? 110 : 62, maxWidth: focused ? 230 : 118)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(focused ? 0.18 : 0.24))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .position(x: center, y: center + (focused ? 68 : 32))
            }
        }
        .frame(width: diameter, height: diameter)
    }

    private var visualDiameter: CGFloat {
        focused ? 620 : 170
    }

    private var starColor: Color {
        let hue = StarMapLayout.stableUnitInterval("star-\(goal.id)")
        return Color(hue: hue, saturation: 0.30, brightness: goal.status == .completed ? 0.98 : 0.76 + completionSignal * 0.18)
    }

    private var completionSignal: Double {
        Double(DomainLogic.goalStats(
            goal: goal,
            routines: routines,
            tasks: [],
            checkIns: checkIns,
            today: DomainLogic.todayISO()
        ).completionRate) / 100
    }

    private var starGradient: RadialGradient {
        RadialGradient(
            colors: [
                .white,
                starColor.opacity(0.92),
                starColor.opacity(0.18)
            ],
            center: .center,
            startRadius: 1,
            endRadius: focused ? 56 : 18
        )
    }

    private func orbitRadius(index: Int, focused: Bool) -> CGFloat {
        focused ? 84 + CGFloat(index) * 34 : 30 + CGFloat(index) * 12
    }

    private func orbitPeriod(index: Int) -> Double {
        10 + Double(index) * 3.8
    }

    private func seededAngle(_ id: String) -> Double {
        StarMapLayout.stableUnitInterval("orbit-\(id)") * .pi * 2
    }

    private func planetColor(for routine: Routine) -> Color {
        if DomainLogic.isRoutineCompletedOnDate(checkIns, routineId: routine.id, date: DomainLogic.todayISO()) {
            return Color(red: 0.94, green: 0.84, blue: 0.56)
        }
        return Color(red: 0.56, green: 0.70, blue: 0.84)
    }
}

private struct CoronaSweep: View {
    var starColor: Color
    var focused: Bool
    var time: TimeInterval

    var body: some View {
        Circle()
            .stroke(
                AngularGradient(
                    colors: [
                        .clear,
                        starColor.opacity(focused ? 0.18 : 0.12),
                        .white.opacity(focused ? 0.22 : 0.13),
                        .clear
                    ],
                    center: .center,
                    angle: .degrees(time * (focused ? 7 : 12))
                ),
                lineWidth: focused ? 18 : 8
            )
            .blur(radius: focused ? 8 : 4)
    }
}

private struct FocusObservationOverlay: View {
    var target: CGPoint

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.06), lineWidth: 1)
                .frame(width: 430, height: 430)
            Circle()
                .stroke(Color(red: 0.72, green: 0.82, blue: 0.96).opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [2, 15]))
                .frame(width: 520, height: 520)
            Text("近距观测")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.44))
                .tracking(3)
                .offset(y: -238)
        }
        .position(target)
    }
}

private struct FocusRoutineLabels: View {
    var routines: [Routine]
    var checkIns: [CheckIn]
    var compact: Bool
    var onSelectRoutine: (String) -> Void

    var body: some View {
        let diameter: CGFloat = 720
        let center = diameter / 2

        ZStack {
            Canvas { context, _ in
                for index in routines.indices {
                    let layout = labelLayout(index: index, total: routines.count, center: center)
                    var path = Path()
                    path.move(to: layout.anchor)
                    path.addLine(to: layout.elbow)
                    path.addLine(to: layout.labelEdge)
                    context.stroke(
                        path,
                        with: .linearGradient(
                            Gradient(colors: [
                                Color(red: 0.60, green: 0.72, blue: 0.90).opacity(0.22),
                                .white.opacity(0.08)
                            ]),
                            startPoint: layout.anchor,
                            endPoint: layout.labelEdge
                        ),
                        style: StrokeStyle(lineWidth: 1, lineCap: .round)
                    )
                    context.fill(
                        Path(ellipseIn: CGRect(x: layout.anchor.x - 2, y: layout.anchor.y - 2, width: 4, height: 4)),
                        with: .color(Color(red: 0.72, green: 0.84, blue: 1.0).opacity(0.55))
                    )
                }
            }
            .allowsHitTesting(false)

            ForEach(Array(routines.enumerated()), id: \.element.id) { index, routine in
                let layout = labelLayout(index: index, total: routines.count, center: center)
                let completed = DomainLogic.isRoutineCompletedOnDate(checkIns, routineId: routine.id, date: DomainLogic.todayISO())

                Button {
                    onSelectRoutine(routine.id)
                } label: {
                    HStack(spacing: 8) {
                        if layout.side < 0 {
                            Text(routine.title)
                                .lineLimit(1)
                            labelDot(completed: completed)
                        } else {
                            labelDot(completed: completed)
                            Text(routine.title)
                                .lineLimit(1)
                        }
                    }
                    .frame(width: labelWidth(for: routine.title), alignment: layout.side > 0 ? .leading : .trailing)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(.black.opacity(0.24))
                    .background(.ultraThinMaterial.opacity(0.55))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(.white.opacity(0.13), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .position(layout.labelCenter)
            }
        }
        .frame(width: diameter, height: diameter)
    }

    @ViewBuilder
    private func labelDot(completed: Bool) -> some View {
        Circle()
            .fill(completed ? Color(red: 0.96, green: 0.83, blue: 0.52) : Color(red: 0.52, green: 0.68, blue: 0.82))
            .frame(width: 7, height: 7)
    }

    private func labelWidth(for title: String) -> CGFloat {
        let estimated = CGFloat(title.count * 11 + 38)
        return min(compact ? 178 : 146, max(compact ? 96 : 84, estimated))
    }

    private func labelLayout(index: Int, total: Int, center: CGFloat) -> (side: CGFloat, anchor: CGPoint, elbow: CGPoint, labelEdge: CGPoint, labelCenter: CGPoint) {
        let side: CGFloat = index.isMultiple(of: 2) ? 1 : -1
        let radius = CGFloat(116 + index * 33)
        let centeredIndex = CGFloat(index) - CGFloat(max(0, total - 1)) / 2
        let yOffset = centeredIndex * 34
        let anchor = CGPoint(x: center + side * radius, y: center + yOffset * 0.44)
        let rawLabelOffset = radius + 86
        let labelOffset: CGFloat
        if compact {
            labelOffset = min(rawLabelOffset, 190)
        } else if side > 0 {
            labelOffset = min(rawLabelOffset, 144)
        } else {
            labelOffset = min(rawLabelOffset, 238)
        }
        let elbowOffset = min(radius + 34, max(108, labelOffset - 34))
        let labelCenter = CGPoint(x: center + side * labelOffset, y: center + yOffset)
        let labelEdge = CGPoint(x: labelCenter.x - side * (compact ? 70 : 58), y: labelCenter.y)
        let elbow = CGPoint(x: center + side * elbowOffset, y: labelCenter.y)
        return (side, anchor, elbow, labelEdge, labelCenter)
    }
}

private struct EmptyStarfieldHint: View {
    var body: some View {
        VStack(spacing: 10) {
            Circle()
                .fill(.white.opacity(0.86))
                .frame(width: 18, height: 18)
                .shadow(color: .white.opacity(0.75), radius: 24)
            Text("等待创建第一颗恒星")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.84))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.black.opacity(0.24))
        .background(.ultraThinMaterial.opacity(0.48))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
