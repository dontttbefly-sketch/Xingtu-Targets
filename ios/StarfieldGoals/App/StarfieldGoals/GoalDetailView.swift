import SwiftUI

struct GoalDetailView: View {
    @ObservedObject var viewModel: GoalsViewModel
    var goal: GoalSnapshot
    @Binding var sheet: AppSheet?
    @State private var showDeleteConfirmation = false
    private let motion = StarfieldMotionProfile.silky

    var body: some View {
        let stats = viewModel.stats(for: goal)
        let routines = viewModel.routines(for: goal.id)
        let tasks = viewModel.tasks(for: goal.id)

        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                GoalHeaderCard(goal: goal, stats: stats) {
                    sheet = .goal(goal)
                }

                GoalPanelSection(title: "行星 routine", systemImage: "orbit") {
                    sheet = .routine(goalId: goal.id, routine: nil)
                } content: {
                    if routines.isEmpty {
                        EmptyDetailRow("还没有 routine。添加一个每日或每周动作，让目标拥有稳定轨道。")
                    } else {
                        VStack(spacing: 8) {
                            ForEach(routines) { routine in
                                RoutineDetailRow(
                                    viewModel: viewModel,
                                    routine: routine,
                                    onOpenQuick: {
                                        viewModel.openRoutineQuick(routine.id, goalId: routine.goalId)
                                    },
                                    onEdit: {
                                        sheet = .routine(goalId: routine.goalId, routine: routine)
                                    }
                                )
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                    }
                }

                GoalPanelSection(title: "临时事项", systemImage: "checklist") {
                    sheet = .task(goalId: goal.id)
                } content: {
                    if tasks.isEmpty {
                        EmptyDetailRow("没有临时事项。需要推进目标时，可以临时加一个任务节点。")
                    } else {
                        VStack(spacing: 8) {
                            ForEach(tasks) { task in
                                TaskDetailRow(viewModel: viewModel, task: task)
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                    }
                }

                VStack(spacing: 10) {
                    if goal.status == .active {
                        Button {
                            withAnimation(.spring(response: motion.focusResponse, dampingFraction: motion.focusDampingFraction)) {
                                viewModel.completeGoal(goal.id)
                            }
                        } label: {
                            Label("标记目标完成", systemImage: "sparkles")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("删除目标", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding(.top, 4)
            }
            .padding(.bottom, 8)
            .animation(.spring(response: motion.drawerResponse, dampingFraction: motion.drawerDampingFraction), value: routines.count)
            .animation(.spring(response: motion.drawerResponse, dampingFraction: motion.drawerDampingFraction), value: tasks.count)
            .animation(.spring(response: motion.focusResponse, dampingFraction: motion.focusDampingFraction), value: goal.status)
        }
        .scrollIndicators(.hidden)
        .confirmationDialog("删除目标？", isPresented: $showDeleteConfirmation) {
            Button("删除目标及其所有记录", role: .destructive) {
                viewModel.deleteGoal(goal.id)
            }
        } message: {
            Text("删除目标会同时删除它的 routine、临时事项和所有打卡记录。")
        }
    }
}

private struct GoalHeaderCard: View {
    var goal: GoalSnapshot
    var stats: GoalStats
    var onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(headerColor.opacity(goal.status == .completed ? 0.28 : 0.22))
                        .frame(width: 58, height: 58)
                    Image(systemName: goal.status == .completed ? "sparkles" : goal.symbolName ?? "star.fill")
                        .font(.title2)
                        .foregroundStyle(goal.status == .completed ? .green : headerColor)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(goal.title)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.62))
                }

                Spacer()

                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.10), in: Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .accessibilityLabel("编辑目标")
            }

            ProgressView(value: Double(stats.completionRate), total: 100)
                .tint(.yellow)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                StatPill(label: "完成率", value: "\(stats.completionRate)%")
                StatPill(label: "已完成", value: "\(stats.completedCheckIns)")
                StatPill(label: "剩余", value: stats.daysRemaining.map { "\($0) 天" } ?? "未设定")
                StatPill(label: "事项", value: "\(stats.completedTaskCount)/\(stats.taskCount)")
            }
        }
        .padding()
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var headerColor: Color {
        goal.colorHex.flatMap { Color(goalHex: $0) } ?? .yellow
    }

    private var subtitle: String {
        let status = goal.status == .completed ? "已点亮恒星" : "航行第 \(stats.daysStarted) 天"
        guard let domain = goal.domain, !domain.isEmpty else {
            return status
        }
        return "\(domain) · \(status)"
    }
}

private extension Color {
    init?(goalHex: String) {
        let raw = goalHex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard raw.count == 6, let value = UInt64(raw, radix: 16) else {
            return nil
        }
        self.init(
            red: Double((value & 0xFF0000) >> 16) / 255,
            green: Double((value & 0x00FF00) >> 8) / 255,
            blue: Double(value & 0x0000FF) / 255
        )
    }
}

private struct GoalPanelSection<Content: View>: View {
    var title: String
    var systemImage: String
    var onAdd: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(title, systemImage: systemImage)
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .frame(width: 32, height: 32)
                        .background(.white.opacity(0.10), in: Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .accessibilityLabel("添加 \(title)")
            }

            content()
        }
        .padding()
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        )
    }
}

private struct RoutineDetailRow: View {
    @ObservedObject var viewModel: GoalsViewModel
    var routine: RoutineSnapshot
    var onOpenQuick: () -> Void
    var onEdit: () -> Void
    private let motion = StarfieldMotionProfile.silky

    var body: some View {
        let completedToday = isRoutineCompletedOnDate(
            viewModel.snapshot.checkIns,
            routineId: routine.id,
            date: viewModel.today
        )
        let allowed = canCompleteRoutineOnDate(routine, checkIns: viewModel.snapshot.checkIns, date: viewModel.today)
        let completedCount = viewModel.completedCheckInCount(for: routine.id)

        HStack(spacing: 8) {
            Button {
                guard completedToday || allowed else {
                    return
                }
                withAnimation(.spring(response: motion.cameraResponse, dampingFraction: motion.cameraDampingFraction)) {
                    viewModel.toggleCheckIn(
                        routineId: routine.id,
                        date: viewModel.today,
                        completed: !completedToday
                    )
                }
            } label: {
                Image(systemName: completedToday ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(completedToday ? .green : .yellow)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!completedToday && !allowed)
            .accessibilityLabel(completedToday ? "取消点亮 \(routine.title)" : allowed ? "点亮 \(routine.title)" : "\(routine.title) 本周已达标")

            Button(action: onOpenQuick) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(routine.title)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .lineLimit(2)
                        Text("\(frequencyLabel(routine.frequency)) · 已完成 \(completedCount) 次 · \(completedToday ? "已点亮" : allowed ? "今日可点亮" : "本周达标")")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.58))
                            .lineLimit(2)
                    }

                    Spacer(minLength: 6)

                    Image(systemName: "chevron.up.forward")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.42))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("打开 \(routine.title) 快捷面板")

            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .frame(width: 32, height: 32)
                    .background(.white.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .accessibilityLabel("编辑 \(routine.title)")

            Button(role: .destructive) {
                viewModel.deleteRoutine(routine.id)
            } label: {
                Image(systemName: "trash")
                    .frame(width: 32, height: 32)
                    .background(.white.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("删除 \(routine.title)")
        }
        .padding(10)
        .background(.black.opacity(0.20), in: RoundedRectangle(cornerRadius: 8))
        .animation(.spring(response: motion.cameraResponse, dampingFraction: motion.cameraDampingFraction), value: completedToday)
    }
}

private struct TaskDetailRow: View {
    @ObservedObject var viewModel: GoalsViewModel
    var task: OneOffTaskSnapshot
    private let motion = StarfieldMotionProfile.silky

    var body: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.spring(response: motion.cameraResponse, dampingFraction: motion.cameraDampingFraction)) {
                    viewModel.toggleTask(task.id, completed: !task.completed)
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: task.completed ? "checkmark.square.fill" : "square")
                        .font(.title2)
                        .foregroundStyle(task.completed ? .green : .yellow)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(task.title)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .strikethrough(task.completed)
                            .lineLimit(2)
                        if let date = task.date {
                            Text(date)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.58))
                        }
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                viewModel.deleteTask(task.id)
            } label: {
                Image(systemName: "trash")
                    .frame(width: 32, height: 32)
                    .background(.white.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("删除 \(task.title)")
        }
        .padding(10)
        .background(.black.opacity(0.20), in: RoundedRectangle(cornerRadius: 8))
        .animation(.spring(response: motion.cameraResponse, dampingFraction: motion.cameraDampingFraction), value: task.completed)
    }
}

private struct StatPill: View {
    var label: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.58))
            Text(value)
                .font(.subheadline.bold())
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.black.opacity(0.20), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct EmptyDetailRow: View {
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
