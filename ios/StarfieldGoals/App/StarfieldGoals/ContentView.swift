import SwiftData
import SwiftUI
import UniformTypeIdentifiers

enum AppSheet: Identifiable {
    case goal(GoalSnapshot?)
    case routine(goalId: String, routine: RoutineSnapshot?)
    case task(goalId: String)

    var id: String {
        switch self {
        case .goal(let goal):
            return "goal-\(goal?.id ?? "new")"
        case .routine(let goalId, let routine):
            return "routine-\(goalId)-\(routine?.id ?? "new")"
        case .task(let goalId):
            return "task-\(goalId)"
        }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var notificationRouter: NotificationRouter
    @StateObject private var viewModel = GoalsViewModel()
    @StateObject private var iCloudStatus = ICloudStatusService()
    @State private var sheet: AppSheet?
    @State private var isImporting = false
    @State private var isExporting = false
    @State private var exportDocument = WebStateDocument(data: Data())
    private let motion = StarfieldMotionProfile.silky
    private let chrome = StarfieldTopChromeProfile.mobilePinned

    var body: some View {
        StarfieldBackground {
            GeometryReader { proxy in
                ZStack {
                    StarMapView(
                        goals: viewModel.snapshot.goals,
                        routines: viewModel.snapshot.routines,
                        stats: { viewModel.stats(for: $0) },
                        completedCheckInCount: viewModel.completedCheckInCount,
                        showsControls: viewModel.activePanel == .none,
                        selectedGoalId: viewModel.selectedGoalId,
                        selectedRoutineId: viewModel.selectedRoutineId,
                        onSelectGoal: viewModel.openGoal,
                        onSelectRoutine: { routine in
                            viewModel.openRoutineQuick(routine.id, goalId: routine.goalId)
                        },
                        onDismissFocus: viewModel.resetWorkspace
                    )
                    .ignoresSafeArea()

                    WorkspaceTopChrome(
                        safeAreaTop: proxy.safeAreaInsets.top,
                        profile: chrome
                    ) {
                        WorkspaceTopBar(
                            selectedGoal: viewModel.selectedGoal,
                            activePanel: viewModel.activePanel,
                            actionButtonSize: CGFloat(chrome.actionButtonSize),
                            onReset: viewModel.resetWorkspace,
                            onToday: viewModel.openTodayRoute,
                            onSearch: viewModel.openSearch,
                            onReview: viewModel.openReview,
                            onData: viewModel.openDataVault,
                            onQuickAdd: viewModel.openQuickAdd
                        )

                        if viewModel.activePanel.focusedGoalId == nil {
                            MetricStrip(viewModel: viewModel)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .allowsHitTesting(true)

                    if viewModel.shouldShowEveningReviewBanner && viewModel.activePanel == .none {
                        VStack {
                            Spacer()
                            EveningReviewBanner {
                                viewModel.acknowledgeEveningReviewBanner()
                            }
                            .padding(.horizontal, 14)
                            .padding(.bottom, max(proxy.safeAreaInsets.bottom, 12) + 72)
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity.combined(with: .scale(scale: 0.96, anchor: .bottom))
                        ))
                    }

                    if viewModel.activePanel.isDrawerPresented {
                        Color.black.opacity(0.24)
                            .ignoresSafeArea()
                            .onTapGesture {
                                viewModel.closePanel()
                            }
                            .transition(.opacity)

                        VStack {
                            Spacer()
                            WorkspaceDrawer(
                                title: drawerTitle(for: viewModel.activePanel),
                                subtitle: drawerSubtitle(for: viewModel.activePanel),
                                maxHeight: drawerHeight(for: viewModel.activePanel, containerHeight: proxy.size.height),
                                onClose: viewModel.closePanel
                            ) {
                                drawerContent(for: viewModel.activePanel)
                            }
                            .padding(.horizontal, 12)
                            .padding(.bottom, max(proxy.safeAreaInsets.bottom, 10))
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity.combined(with: .scale(scale: 0.96, anchor: .bottom))
                        ))
                    }
                }
                .animation(
                    .spring(
                        response: motion.drawerResponse,
                        dampingFraction: motion.drawerDampingFraction,
                        blendDuration: 0.10
                    ),
                    value: viewModel.activePanel
                )
                .animation(
                    .spring(
                        response: motion.focusResponse,
                        dampingFraction: motion.focusDampingFraction,
                        blendDuration: 0.10
                    ),
                    value: viewModel.selectedGoalId
                )
            }
        }
        .sheet(item: $sheet) { item in
            switch item {
            case .goal(let goal):
                GoalEditor(goal: goal) { title, startDate, dueDate, colorHex, symbolName, domain in
                    if let goal {
                        viewModel.updateGoal(
                            goal.id,
                            title: title,
                            startDate: startDate,
                            dueDate: dueDate,
                            colorHex: colorHex,
                            symbolName: symbolName,
                            domain: domain
                        )
                    } else {
                        viewModel.addGoal(
                            title: title,
                            startDate: startDate,
                            dueDate: dueDate,
                            colorHex: colorHex,
                            symbolName: symbolName,
                            domain: domain
                        )
                    }
                }
            case .routine(let goalId, let routine):
                RoutineEditor(routine: routine) { title, frequency in
                    if let routine {
                        viewModel.updateRoutine(routine.id, title: title, frequency: frequency)
                    } else {
                        viewModel.addRoutine(goalId: goalId, title: title, frequency: frequency)
                    }
                }
            case .task(let goalId):
                TaskEditor { title, date, priority, notes in
                    viewModel.addTask(goalId: goalId, title: title, date: date, priority: priority, notes: notes)
                }
            }
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                guard url.startAccessingSecurityScopedResource() else {
                    viewModel.errorMessage = "无法读取所选文件。"
                    return
                }
                defer { url.stopAccessingSecurityScopedResource() }
                viewModel.importWebState(from: try Data(contentsOf: url))
                viewModel.openDataVault()
            } catch {
                viewModel.errorMessage = error.localizedDescription
            }
        }
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "starfield-goals-backup-\(viewModel.today).json"
        ) { result in
            if case .failure(let error) = result {
                viewModel.errorMessage = error.localizedDescription
            }
        }
        .alert("星图", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .task {
            viewModel.configure(context: modelContext)
            await iCloudStatus.refresh()
            try? await NotificationService.requestAuthorizationAndScheduleDailyReview()
        }
        .onChange(of: notificationRouter.reviewOpenRequest) {
            viewModel.openTodayFromNotification()
        }
    }

    @ViewBuilder
    private func drawerContent(for panel: WorkspacePanel) -> some View {
        switch panel {
        case .none:
            EmptyView()
        case .todayRoute:
            TodayRoutePanel(viewModel: viewModel)
        case .goalDetail(let goalId):
            if let goal = viewModel.snapshot.goals.first(where: { $0.id == goalId }) {
                GoalDetailView(viewModel: viewModel, goal: goal, sheet: $sheet)
            } else {
                ContentUnavailableView("目标不存在", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.white)
            }
        case .review:
            ReviewPanel(viewModel: viewModel)
        case .data:
            DataVaultPanel(
                viewModel: viewModel,
                iCloudState: iCloudStatus.state,
                onImport: { isImporting = true },
                onExport: exportBackup
            )
        case .routineQuick(let routineId, _):
            if let routine = viewModel.snapshot.routines.first(where: { $0.id == routineId }) {
                RoutineQuickPanel(
                    viewModel: viewModel,
                    routine: routine,
                    onEdit: { sheet = .routine(goalId: routine.goalId, routine: routine) },
                    onOpenGoal: viewModel.openSelectedRoutineGoal
                )
            } else {
                ContentUnavailableView("轨道不存在", systemImage: "orbit")
                    .foregroundStyle(.white)
            }
        case .quickAdd:
            QuickAddPanel(
                viewModel: viewModel,
                onAddGoal: { sheet = .goal(nil) },
                onAddRoutine: { goalId in sheet = .routine(goalId: goalId, routine: nil) },
                onAddTask: { goalId in sheet = .task(goalId: goalId) }
            )
        case .search:
            SearchPanel(
                viewModel: viewModel,
                onEditGoal: { goal in sheet = .goal(goal) }
            )
        }
    }

    private func drawerTitle(for panel: WorkspacePanel) -> String {
        switch panel {
        case .none:
            return ""
        case .todayRoute:
            return "今日航线"
        case .goalDetail:
            return "恒星档案"
        case .review:
            return "今晚复盘"
        case .data:
            return "数据舱"
        case .routineQuick:
            return "轨道快捷面板"
        case .quickAdd:
            return "快速添加"
        case .search:
            return "搜索星图"
        }
    }

    private func drawerSubtitle(for panel: WorkspacePanel) -> String {
        switch panel {
        case .none:
            return ""
        case .todayRoute:
            return "今天该点亮的轨道、临时事项和已达标 routine"
        case .goalDetail:
            return "编辑目标、routine 和临时事项"
        case .review:
            return "补记最近 7 天，把完成的 routine 点亮"
        case .data:
            return "iCloud 状态、数据统计和 Web 备份"
        case .routineQuick:
            return "快速打卡、查看频次和编辑轨道"
        case .quickAdd:
            return "新建恒星，或给当前恒星添加轨道和事项"
        case .search:
            return "快速定位目标、routine 和临时事项"
        }
    }

    private func drawerHeight(for panel: WorkspacePanel, containerHeight: CGFloat) -> CGFloat {
        let fraction: CGFloat
        switch panel {
        case .routineQuick:
            fraction = 0.42
        case .quickAdd:
            fraction = 0.48
        case .goalDetail:
            fraction = 0.64
        case .todayRoute, .review, .data, .search:
            fraction = 0.74
        case .none:
            fraction = 0
        }
        return max(280, min(containerHeight * fraction, 720))
    }

    private func exportBackup() {
        if let data = viewModel.exportWebBackup() {
            exportDocument = WebStateDocument(data: data)
            isExporting = true
        }
    }
}

private struct WorkspaceTopChrome<Content: View>: View {
    var safeAreaTop: CGFloat
    var profile: StarfieldTopChromeProfile
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(.horizontal, CGFloat(profile.horizontalPadding))
        .padding(.top, CGFloat(profile.topContentPadding))
        .padding(.bottom, CGFloat(profile.bottomPadding))
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct WorkspaceTopBar: View {
    var selectedGoal: GoalSnapshot?
    var activePanel: WorkspacePanel
    var actionButtonSize: CGFloat
    var onReset: () -> Void
    var onToday: () -> Void
    var onSearch: () -> Void
    var onReview: () -> Void
    var onData: () -> Void
    var onQuickAdd: () -> Void
    private let motion = StarfieldMotionProfile.silky

    var body: some View {
        HStack(spacing: 12) {
            brandButton
            Spacer(minLength: 10)
            topActions
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(.black.opacity(0.38))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.28), radius: 28, y: 14)
        .animation(.spring(response: motion.drawerResponse, dampingFraction: motion.drawerDampingFraction), value: activePanel)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var brandButton: some View {
        Button(action: onReset) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    .white,
                                    Color(red: 0.96, green: 0.78, blue: 0.36),
                                    Color.cyan.opacity(0.46),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 1,
                                endRadius: 18
                            )
                        )
                        .frame(width: 32, height: 32)
                        .shadow(color: Color(red: 0.97, green: 0.84, blue: 0.46).opacity(0.62), radius: 17)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("星图")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(selectedGoal?.title ?? "私人航行日志")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.64))
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(SpringyGlassButtonStyle())
        .accessibilityLabel("返回完整星图")
    }

    private var topActions: some View {
        HStack(spacing: 6) {
            GlassActionButton(title: "今日航线", systemImage: "location.north.line.fill", size: actionButtonSize, isActive: activePanel == .todayRoute, action: onToday)
            GlassActionButton(title: "搜索", systemImage: "magnifyingglass", size: actionButtonSize, isActive: activePanel == .search, action: onSearch)
            GlassActionButton(title: "数据舱", systemImage: "externaldrive", size: actionButtonSize, isActive: activePanel == .data, action: onData)
            GlassActionButton(title: "复盘", systemImage: "moon.stars.fill", size: actionButtonSize, isActive: activePanel == .review, action: onReview)
            GlassActionButton(title: "新建", systemImage: "plus", size: actionButtonSize, isActive: activePanel == .quickAdd, action: onQuickAdd)
        }
    }
}

private struct GlassActionButton: View {
    var title: String
    var systemImage: String
    var size: CGFloat
    var isActive: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .frame(width: size, height: size)
                .background(
                    isActive ? Color.yellow.opacity(0.20) : Color.white.opacity(0.09),
                    in: Circle()
                )
                .overlay(
                    Circle()
                        .stroke(isActive ? Color.yellow.opacity(0.52) : Color.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: isActive ? Color.yellow.opacity(0.18) : .clear, radius: 10, y: 4)
        }
        .buttonStyle(SpringyGlassButtonStyle())
        .foregroundStyle(.white)
        .accessibilityLabel(title)
    }
}

private struct SpringyGlassButtonStyle: ButtonStyle {
    private let motion = StarfieldMotionProfile.silky

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? CGFloat(motion.pressScale) : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.spring(response: 0.18, dampingFraction: 0.78), value: configuration.isPressed)
    }
}

private struct WorkspaceDrawer<Content: View>: View {
    var title: String
    var subtitle: String
    var maxHeight: CGFloat
    var onClose: () -> Void
    @ViewBuilder var content: () -> Content
    @State private var appeared = false
    private let motion = StarfieldMotionProfile.silky

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Capsule()
                .fill(.white.opacity(0.24))
                .frame(width: 46, height: 5)
                .frame(maxWidth: .infinity)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.62))
                }

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .frame(width: 34, height: 34)
                        .background(.white.opacity(0.10), in: Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .accessibilityLabel("关闭面板")
            }

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .frame(maxHeight: maxHeight)
        .background(.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 8))
        .background(.ultraThinMaterial.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.42), radius: 22, y: 12)
        .scaleEffect(appeared ? 1 : 0.97, anchor: .bottom)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: motion.drawerResponse, dampingFraction: motion.drawerDampingFraction, blendDuration: 0.10)) {
                appeared = true
            }
        }
    }
}

private struct DataVaultPanel: View {
    @ObservedObject var viewModel: GoalsViewModel
    var iCloudState: ICloudAccountState
    var onImport: () -> Void
    var onExport: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ICloudStatusBanner(state: iCloudState)

                DataCountGrid(viewModel: viewModel)

                DataInsightGrid(viewModel: viewModel)

                DataInfoPanel(viewModel: viewModel)

                VStack(spacing: 12) {
                    Button(action: onImport) {
                        Label("导入 Web JSON", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button(action: onExport) {
                        Label("导出备份 JSON", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(.white)
                }

                if let dataMessage = viewModel.dataMessage {
                    Label(dataMessage, systemImage: "checkmark.seal.fill")
                        .font(.footnote)
                        .foregroundStyle(.green)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(.bottom, 8)
        }
        .scrollIndicators(.hidden)
    }
}

private struct RoutineQuickPanel: View {
    @ObservedObject var viewModel: GoalsViewModel
    var routine: RoutineSnapshot
    var onEdit: () -> Void
    var onOpenGoal: () -> Void

    var body: some View {
        let completedToday = isRoutineCompletedOnDate(
            viewModel.snapshot.checkIns,
            routineId: routine.id,
            date: viewModel.today
        )
        let allowed = canCompleteRoutineOnDate(routine, checkIns: viewModel.snapshot.checkIns, date: viewModel.today)
        let completedCount = viewModel.completedCheckInCount(for: routine.id)

        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(completedToday ? Color.green.opacity(0.22) : Color.yellow.opacity(0.18))
                        .frame(width: 52, height: 52)
                    Image(systemName: completedToday ? "checkmark.circle.fill" : "orbit")
                        .font(.title2)
                        .foregroundStyle(completedToday ? .green : .yellow)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(routine.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("\(frequencyLabel(routine.frequency)) · 已完成 \(completedCount) 次")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.62))
                }
            }

            Button {
                guard completedToday || allowed else {
                    return
                }
                withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) {
                    viewModel.toggleCheckIn(routineId: routine.id, date: viewModel.today, completed: !completedToday)
                }
            } label: {
                Label(completedToday ? "取消今天点亮" : allowed ? "点亮今天" : "本周已达标", systemImage: completedToday ? "checkmark.circle.fill" : "sparkle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!completedToday && !allowed)
            .animation(.spring(response: 0.22, dampingFraction: 0.82), value: completedToday)

            HStack(spacing: 10) {
                Button(action: onOpenGoal) {
                    Label("打开目标", systemImage: "scope")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.white)

                Button(action: onEdit) {
                    Label("编辑", systemImage: "pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.white)

                Button(role: .destructive) {
                    viewModel.deleteRoutine(routine.id)
                } label: {
                    Label("删除", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

private struct TodayRoutePanel: View {
    @ObservedObject var viewModel: GoalsViewModel
    @State private var showSatisfiedWeekly = false
    private let motion = StarfieldMotionProfile.silky

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TodayHeroCard(viewModel: viewModel)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(backfillDates(through: viewModel.today), id: \.self) { date in
                            DateChip(date: date, today: viewModel.today, isSelected: date == viewModel.reviewDate) {
                                viewModel.reviewDate = date
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }

                if viewModel.todayPendingRouteItems.isEmpty && viewModel.todayTasks.isEmpty {
                    EmptyRouteCard()
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        PanelSectionTitle("待点亮轨道", systemImage: "sparkle")
                        ForEach(viewModel.todayPendingRouteItems) { item in
                            TodayRouteRow(item: item, isEnabled: true) {
                                withAnimation(.spring(response: motion.cameraResponse, dampingFraction: motion.cameraDampingFraction)) {
                                    viewModel.toggleCheckIn(routineId: item.routineId, date: viewModel.today, completed: true)
                                }
                            }
                        }
                    }

                    if !viewModel.todayTasks.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            PanelSectionTitle("临时事项", systemImage: "checklist")
                            ForEach(viewModel.todayTasks) { task in
                                TodayTaskRow(task: task) {
                                    withAnimation(.spring(response: motion.cameraResponse, dampingFraction: motion.cameraDampingFraction)) {
                                        viewModel.toggleTask(task.id, completed: true)
                                    }
                                }
                            }
                        }
                    }
                }

                if !viewModel.todayCompletedRouteItems.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        PanelSectionTitle("今天已点亮", systemImage: "checkmark.seal.fill")
                        ForEach(viewModel.todayCompletedRouteItems) { item in
                            TodayRouteRow(item: item, isEnabled: true) {
                                withAnimation(.spring(response: motion.cameraResponse, dampingFraction: motion.cameraDampingFraction)) {
                                    viewModel.toggleCheckIn(routineId: item.routineId, date: viewModel.today, completed: false)
                                }
                            }
                        }
                    }
                }

                if !viewModel.todaySatisfiedWeeklyItems.isEmpty {
                    DisclosureGroup(isExpanded: $showSatisfiedWeekly) {
                        VStack(spacing: 8) {
                            ForEach(viewModel.todaySatisfiedWeeklyItems) { item in
                                TodayRouteRow(item: item, isEnabled: false) {}
                            }
                        }
                        .padding(.top, 8)
                    } label: {
                        Label("本周已达标 \(viewModel.todaySatisfiedWeeklyItems.count)", systemImage: "seal.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                    .tint(.white)
                    .padding()
                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(.bottom, 10)
        }
        .scrollIndicators(.hidden)
    }
}

private struct TodayHeroCard: View {
    @ObservedObject var viewModel: GoalsViewModel

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.yellow.opacity(0.20))
                    .frame(width: 58, height: 58)
                Image(systemName: "location.north.line.fill")
                    .font(.title2)
                    .foregroundStyle(.yellow)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(viewModel.nextSuggestedAction?.routineTitle ?? "今天的航线很清爽")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text("待点亮 \(viewModel.todayPendingRouteItems.count) · 已完成 \(viewModel.todayCompletedRouteItems.count) · 连续 \(viewModel.streakSummary.currentDays) 天")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
            }

            Spacer()
        }
        .padding()
        .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct DateChip: View {
    var date: ISODate
    var today: ISODate
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(date == today ? "今天" : String(date.suffix(5)))
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color.yellow.opacity(0.24) : Color.white.opacity(0.08), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.yellow.opacity(0.45) : Color.white.opacity(0.10), lineWidth: 1)
                )
        }
        .buttonStyle(SpringyGlassButtonStyle())
        .foregroundStyle(.white)
    }
}

private struct TodayRouteRow: View {
    var item: TodayRouteItem
    var isEnabled: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.title3)
                    .foregroundStyle(iconColor)
                    .frame(width: 34, height: 34)
                    .background(iconColor.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.routineTitle)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.60))
                        .lineLimit(2)
                }

                Spacer()
            }
            .contentShape(Rectangle())
            .padding(12)
            .background(.black.opacity(0.20), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(item.status == .available ? Color.yellow.opacity(0.16) : Color.white.opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.66)
    }

    private var iconName: String {
        switch item.status {
        case .available:
            return "circle"
        case .completedToday:
            return "checkmark.circle.fill"
        case .weeklySatisfied:
            return "seal.fill"
        }
    }

    private var iconColor: Color {
        switch item.status {
        case .available:
            return .yellow
        case .completedToday:
            return .green
        case .weeklySatisfied:
            return .cyan
        }
    }

    private var subtitle: String {
        if let weeklyCompletedCount = item.weeklyCompletedCount, let weeklyTarget = item.weeklyTarget {
            return "\(item.goalTitle) · \(item.frequencyLabel) · \(weeklyCompletedCount)/\(weeklyTarget)"
        }
        return "\(item.goalTitle) · \(item.frequencyLabel)"
    }
}

private struct TodayTaskRow: View {
    var task: OneOffTaskSnapshot
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "square")
                    .font(.title3)
                    .foregroundStyle(.yellow)
                    .frame(width: 34, height: 34)
                    .background(Color.yellow.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text(task.date ?? "无日期事项")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.60))
                }

                Spacer()
            }
            .contentShape(Rectangle())
            .padding(12)
            .background(.black.opacity(0.20), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

private struct EmptyRouteCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("今天没有待点亮动作", systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(.green)
            Text("可以去添加新的 routine，或在今晚复盘里补记过去 7 天。")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.62))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct QuickAddPanel: View {
    @ObservedObject var viewModel: GoalsViewModel
    var onAddGoal: () -> Void
    var onAddRoutine: (String) -> Void
    var onAddTask: (String) -> Void

    private var targetGoal: GoalSnapshot? {
        viewModel.selectedGoal ?? viewModel.activeGoals.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            QuickAddButton(
                title: "建立一颗新恒星",
                subtitle: "创建一个新的长期目标",
                systemImage: "star.fill",
                tint: .yellow,
                action: onAddGoal
            )

            QuickAddButton(
                title: targetGoal.map { "给「\($0.title)」添加 routine" } ?? "先建立目标再添加 routine",
                subtitle: "每日或每周重复的稳定行动",
                systemImage: "orbit",
                tint: .cyan
            ) {
                if let targetGoal {
                    onAddRoutine(targetGoal.id)
                }
            }
            .disabled(targetGoal == nil)
            .opacity(targetGoal == nil ? 0.55 : 1)

            QuickAddButton(
                title: targetGoal.map { "给「\($0.title)」添加临时事项" } ?? "先建立目标再添加事项",
                subtitle: "一次性的推进任务",
                systemImage: "checklist",
                tint: .green
            ) {
                if let targetGoal {
                    onAddTask(targetGoal.id)
                }
            }
            .disabled(targetGoal == nil)
            .opacity(targetGoal == nil ? 0.55 : 1)
        }
    }
}

private struct QuickAddButton: View {
    var title: String
    var subtitle: String
    var systemImage: String
    var tint: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(tint)
                    .frame(width: 44, height: 44)
                    .background(tint.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.62))
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.42))
            }
            .contentShape(Rectangle())
            .padding()
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.white.opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(SpringyGlassButtonStyle())
    }
}

private struct SearchPanel: View {
    @ObservedObject var viewModel: GoalsViewModel
    var onEditGoal: (GoalSnapshot) -> Void

    private var query: String {
        viewModel.goalSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var matchingGoals: [GoalSnapshot] {
        let goals = viewModel.snapshot.goals
        guard !query.isEmpty else {
            return Array(goals.prefix(8))
        }
        return goals.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    private var matchingRoutines: [RoutineSnapshot] {
        guard !query.isEmpty else {
            return []
        }
        return viewModel.snapshot.routines.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    private var matchingTasks: [OneOffTaskSnapshot] {
        guard !query.isEmpty else {
            return []
        }
        return viewModel.snapshot.tasks.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.white.opacity(0.62))
                TextField("搜索目标、routine、事项", text: $viewModel.goalSearchText)
                    .textInputAutocapitalization(.never)
                    .foregroundStyle(.white)
            }
            .padding(12)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    SearchSection(title: query.isEmpty ? "最近恒星" : "目标", systemImage: "star.fill") {
                        if matchingGoals.isEmpty {
                            EmptySearchRow("没有匹配的目标。")
                        } else {
                            ForEach(matchingGoals) { goal in
                                SearchResultRow(title: goal.title, subtitle: goal.status == .completed ? "已点亮恒星" : "航行中", systemImage: "star.fill", tint: .yellow) {
                                    viewModel.openGoal(goal.id)
                                }
                            }
                        }
                    }

                    if !matchingRoutines.isEmpty {
                        SearchSection(title: "routine", systemImage: "orbit") {
                            ForEach(matchingRoutines) { routine in
                                SearchResultRow(title: routine.title, subtitle: ownerTitle(for: routine.goalId), systemImage: "orbit", tint: .cyan) {
                                    viewModel.openRoutineQuick(routine.id, goalId: routine.goalId)
                                }
                            }
                        }
                    }

                    if !matchingTasks.isEmpty {
                        SearchSection(title: "临时事项", systemImage: "checklist") {
                            ForEach(matchingTasks) { task in
                                SearchResultRow(title: task.title, subtitle: ownerTitle(for: task.goalId), systemImage: task.completed ? "checkmark.square.fill" : "square", tint: task.completed ? .green : .yellow) {
                                    viewModel.openGoal(task.goalId)
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 6)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func ownerTitle(for goalId: String) -> String {
        viewModel.snapshot.goals.first(where: { $0.id == goalId })?.title ?? "未知恒星"
    }
}

private struct SearchSection<Content: View>: View {
    var title: String
    var systemImage: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PanelSectionTitle(title, systemImage: systemImage)
            content()
        }
    }
}

private struct SearchResultRow: View {
    var title: String
    var subtitle: String
    var systemImage: String
    var tint: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.14), in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.60))
                }
                Spacer()
            }
            .contentShape(Rectangle())
            .padding(12)
            .background(.black.opacity(0.20), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

private struct EmptySearchRow: View {
    var text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.58))
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PanelSectionTitle: View {
    var title: String
    var systemImage: String

    init(_ title: String, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .foregroundStyle(.white)
    }
}

private struct StarfieldBackground<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.01, green: 0.03, blue: 0.08),
                    Color(red: 0.03, green: 0.05, blue: 0.13),
                    Color(red: 0.01, green: 0.02, blue: 0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [Color.cyan.opacity(0.20), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 380
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [Color.yellow.opacity(0.12), .clear],
                center: .bottomLeading,
                startRadius: 40,
                endRadius: 420
            )
            .ignoresSafeArea()

            CosmicDustLayer()
                .opacity(0.8)
                .ignoresSafeArea()

            content()
        }
    }
}

private struct CosmicDustLayer: View {
    var body: some View {
        Canvas { context, size in
            for index in 0..<120 {
                let x = size.width * unit(Double(index) * 12.9898)
                let y = size.height * unit(Double(index) * 78.233)
                let radius = CGFloat(0.6 + unit(Double(index) * 3.71) * 1.4)
                let opacity = 0.18 + Double(unit(Double(index) * 5.19)) * 0.42
                let rect = CGRect(x: x, y: y, width: radius, height: radius)
                context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(opacity)))
            }
        }
    }

    private func unit(_ value: Double) -> CGFloat {
        let raw = sin(value) * 10000
        return CGFloat(raw - floor(raw))
    }
}

private struct EveningReviewBanner: View {
    var onStart: () -> Void
    @State private var floating = false
    private let motion = StarfieldMotionProfile.silky

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "moon.stars.fill")
                .font(.title2)
                .foregroundStyle(.yellow)

            VStack(alignment: .leading, spacing: 4) {
                Text("21:00 复盘窗口")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.yellow)
                Text("检查今天的轨道，把完成的 routine 点亮。")
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }

            Spacer()

            Button("开始", action: onStart)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.black.opacity(0.48), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.13), lineWidth: 1)
        )
        .offset(y: floating ? -4 : 0)
        .animation(.easeInOut(duration: motion.ambientDriftDuration).repeatForever(autoreverses: true), value: floating)
        .onAppear {
            floating = true
        }
    }
}

private struct DataCountGrid: View {
    @ObservedObject var viewModel: GoalsViewModel

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            DataMetric(label: "目标", value: "\(viewModel.snapshot.goals.count)")
            DataMetric(label: "routine", value: "\(viewModel.snapshot.routines.count)")
            DataMetric(label: "事项", value: "\(viewModel.snapshot.tasks.count)")
            DataMetric(label: "打卡", value: "\(viewModel.snapshot.checkIns.count)")
        }
    }
}

private struct DataMetric: View {
    var label: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.58))
            Text(value)
                .font(.title2.bold())
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct DataInsightGrid: View {
    @ObservedObject var viewModel: GoalsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("航行洞察", systemImage: "chart.line.uptrend.xyaxis")
                .font(.headline)
                .foregroundStyle(.white)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                DataMetric(label: "连续航行", value: "\(viewModel.streakSummary.currentDays) 天")
                DataMetric(label: "最佳连续", value: "\(viewModel.streakSummary.bestDays) 天")
                DataMetric(label: "今日待点亮", value: "\(viewModel.todayPendingRouteItems.count)")
                DataMetric(label: "平均完成率", value: "\(viewModel.averageCompletionRate)%")
            }

            if let attentionGoal = viewModel.attentionGoal {
                Label("需关注：\(attentionGoal.title) · 健康度 \(attentionGoal.score)", systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.orange)
                    .lineLimit(2)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
            }

            if let stableRoutine = viewModel.stableRoutine {
                Label("最稳定：\(stableRoutine.title) · \(stableRoutine.completedCount) 次", systemImage: "flame.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.green)
                    .lineLimit(2)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.green.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
            }

            if let next = viewModel.nextSuggestedAction {
                Label("下一步：\(next.routineTitle)", systemImage: "sparkle")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.yellow)
                    .lineLimit(2)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.yellow.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

private struct DataInfoPanel: View {
    @ObservedObject var viewModel: GoalsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Web 兼容备份", systemImage: "arrow.triangle.2.circlepath")
                .font(.headline)
                .foregroundStyle(.white)

            Text("导入支持 Web 版备份包装和早期裸 AppState；导出会生成 Web 版也能识别的备份文件。")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.64))

            Divider()
                .overlay(.white.opacity(0.18))

            LabeledContent("总记录数", value: "\(viewModel.totalRecordCount)")
            LabeledContent("最近导入", value: viewModel.importedWebStateAt.map(shortDateTime) ?? "尚未导入")
        }
        .foregroundStyle(.white)
        .padding()
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    private func shortDateTime(_ value: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: value) else {
            return value
        }
        return date.formatted(date: .numeric, time: .shortened)
    }
}

private struct ICloudStatusBanner: View {
    var state: ICloudAccountState

    var body: some View {
        Label(state.message, systemImage: state == .available ? "icloud.fill" : "icloud.slash")
            .font(.footnote)
            .foregroundStyle(state == .available ? .green : .yellow)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct MetricStrip: View {
    @ObservedObject var viewModel: GoalsViewModel

    var body: some View {
        HStack(spacing: 8) {
            MetricTile(label: "活跃恒星", value: "\(viewModel.activeGoals.count)")
            MetricTile(label: "完成恒星", value: "\(viewModel.completedGoals.count)")
            MetricTile(label: "坚持次数", value: "\(viewModel.totalCompletedCheckIns)")
            MetricTile(label: "累计航行天数", value: "\(viewModel.totalDays)")
        }
        .frame(maxWidth: .infinity)
    }
}

private struct MetricTile: View {
    var label: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.58))
            Text(value)
                .font(.headline)
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.13), lineWidth: 1)
        )
        .background(.ultraThinMaterial.opacity(0.42), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct WebStateDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
