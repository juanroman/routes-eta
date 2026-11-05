import Domain
import SwiftUI

/// A commute's schedule rules: each is a set of weekdays plus one time of day.
/// Weekday chips owned by another rule are disabled, so overlap (which the API
/// rejects) can't be created here; the store still validates as a backstop.
struct ScheduleEditorView: View {
  let store: ConfigStore
  let commuteID: CommuteEntry.ID

  @State private var pendingDelete: Int?
  @State private var errorMessage: String?

  var body: some View {
    if let commute = store.entry(id: commuteID)?.commute {
      editor(for: commute)
    } else {
      ContentUnavailableView("Commute not found", systemImage: "questionmark.circle")
    }
  }

  private func editor(for commute: Commute) -> some View {
    List {
      ForEach(Array(commute.schedules.enumerated()), id: \.offset) { index, rule in
        RuleSection(
          index: index, rule: rule, commute: commute,
          onToggle: { day in update { $0.toggle(day, inRuleAt: index) } },
          onTime: { hour, minute in
            update {
              if $0.schedules.indices.contains(index) {
                $0.schedules[index].setTime(hour: hour, minute: minute)
              }
            }
          },
          onDelete: { pendingDelete = index })
      }

      Section {
        Button("Add Rule", systemImage: "plus") {
          update { $0.addScheduleRule() }
        }
        .disabled(commute.unscheduledWeekdays.isEmpty)
        .accessibilityIdentifier("add-rule")
      } footer: {
        Text(footer(for: commute))
      }
    }
    .overlay {
      if commute.schedules.isEmpty {
        ContentUnavailableView(
          "Not scheduled", systemImage: "calendar",
          description: Text("Add a rule to choose the days and time."))
      }
    }
    .navigationTitle("Schedule")
    .inlineNavigationTitle()
    .alert(
      "Delete this rule?", isPresented: isConfirming, presenting: pendingDelete
    ) { index in
      Button("Delete Rule", role: .destructive) {
        update { if $0.schedules.indices.contains(index) { $0.schedules.remove(at: index) } }
      }
      Button("Cancel", role: .cancel) {}
    } message: { index in
      Text(
        commute.schedules.indices.contains(index)
          ? "\(commute.schedules[index].summary) will no longer be scheduled." : "")
    }
    .alert("Couldn't save", isPresented: hasError) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(errorMessage ?? "")
    }
  }

  private func footer(for commute: Commute) -> String {
    let free = commute.unscheduledWeekdays
    let zone = "Times are in \(store.timezone)."
    return free.isEmpty ? "Every weekday is scheduled. \(zone)" : zone
  }

  private func update(_ mutate: @escaping @MainActor (inout Commute) -> Void) {
    Task { errorMessage = await store.updateCommute(id: commuteID, mutate) }
  }

  private var isConfirming: Binding<Bool> {
    Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
  }

  private var hasError: Binding<Bool> {
    Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
  }
}

private struct RuleSection: View {
  let index: Int
  let rule: ScheduleRule
  let commute: Commute
  let onToggle: (Weekday) -> Void
  let onTime: (Int, Int) -> Void
  let onDelete: () -> Void

  var body: some View {
    Section("Rule \(index + 1)") {
      HStack(spacing: 4) {
        ForEach(Weekday.allCases, id: \.self) { day in chip(day) }
      }
      DatePicker("Time", selection: timeBinding, displayedComponents: .hourAndMinute)
        .accessibilityIdentifier("time-\(index)")
      Button("Delete Rule", role: .destructive, action: onDelete)
    }
  }

  private func chip(_ day: Weekday) -> some View {
    let isOn = rule.weekdays.contains(day)
    let enabled = commute.canToggle(day, inRuleAt: index)
    return Button {
      onToggle(day)
    } label: {
      Text(day.shortName)
        .font(.caption.weight(.medium))
        .frame(maxWidth: .infinity, minHeight: 44)
        .foregroundStyle(isOn ? Color.white : Color.primary)
        .background(isOn ? Color.accentColor : Color.secondary.opacity(0.15), in: Capsule())
        .opacity(enabled || isOn ? 1 : 0.35)
    }
    .buttonStyle(.plain)
    .disabled(!enabled)
    .accessibilityAddTraits(isOn ? .isSelected : [])
    .accessibilityIdentifier("day-\(index)-\(day.shortName)")
  }

  /// `DatePicker` needs a `Date`; only its hour and minute are read back, so
  /// the day and time zone it is anchored to don't matter.
  private var timeBinding: Binding<Date> {
    Binding(
      get: {
        Calendar.current.date(
          from: DateComponents(hour: rule.hour ?? 0, minute: rule.minute ?? 0)) ?? Date()
      },
      set: { date in
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        onTime(parts.hour ?? 0, parts.minute ?? 0)
      })
  }
}
