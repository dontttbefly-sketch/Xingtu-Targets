import SwiftUI

struct ReviewPanel: View {
    @ObservedObject var viewModel: GoalsViewModel
    private let motion = StarfieldMotionProfile.silky

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("今日检查")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text("补记最近 7 天，把完成的 routine 点亮。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(backfillDates(through: viewModel.today), id: \.self) { date in
                        Button {
                            viewModel.reviewDate = date
                        } label: {
                            Text(dateLabel(date))
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    viewModel.reviewDate == date ? Color.white.opacity(0.22) : Color.white.opacity(0.08),
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal)
            }

            ReviewSummaryCard(viewModel: viewModel)
                .padding(.horizontal)

            if viewModel.reviewItems.isEmpty {
                ContentUnavailableView(
                    "这一天没有待点亮轨道",
                    systemImage: "checkmark.seal",
                    description: Text("已经达到本日或本周的 routine 目标。")
                )
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(viewModel.reviewItems) { item in
                        Toggle(isOn: Binding(
                            get: { item.completed },
                            set: { completed in
                                withAnimation(.spring(response: motion.cameraResponse, dampingFraction: motion.cameraDampingFraction)) {
                                    viewModel.toggleCheckIn(
                                        routineId: item.routineId,
                                        date: viewModel.reviewDate,
                                        completed: completed
                                    )
                                }
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.routineTitle)
                                    .font(.headline)
                                Text("\(item.goalTitle) · \(item.frequencyLabel)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                        .padding(.vertical, 6)
                        .listRowBackground(Color.white.opacity(0.08))
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .scrollContentBackground(.hidden)
                .animation(.spring(response: motion.drawerResponse, dampingFraction: motion.drawerDampingFraction), value: viewModel.reviewItems.count)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func dateLabel(_ date: ISODate) -> String {
        date == viewModel.today ? "今天" : String(date.suffix(5))
    }
}

private struct ReviewSummaryCard: View {
    @ObservedObject var viewModel: GoalsViewModel

    var body: some View {
        let items = viewModel.reviewItems
        let completed = items.filter(\.completed).count
        let total = items.count

        HStack(spacing: 10) {
            SummaryPill(label: "今日点亮", value: "\(completed)/\(total)")
            SummaryPill(label: "连续航行", value: "\(viewModel.streakSummary.currentDays) 天")
            SummaryPill(label: "待补记", value: "\(max(0, total - completed))")
        }
        .padding(10)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        )
    }
}

private struct SummaryPill: View {
    var label: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.58))
            Text(value)
                .font(.subheadline.bold())
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
