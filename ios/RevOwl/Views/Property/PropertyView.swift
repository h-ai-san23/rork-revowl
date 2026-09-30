import SwiftUI

enum PropertyRoute: Hashable {
    case profile, competitors, data, team, plan, locale
}

struct PropertyView: View {
    @Environment(AppModel.self) private var app
    @State private var showSignOut = false
    @State private var showDelete = false
    @State private var showAddProperty = false
    @State private var errorText: String?

    var body: some View {
        List {
            if let o = app.overview {
                Section {
                    HStack(spacing: 14) {
                        OrevView(state: .idle, size: 56, isAnimated: false)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(o.profile.name).font(.display(.title3)).foregroundStyle(Palette.ink)
                            Text([o.profile.city, o.profile.country].compactMap { $0 }.joined(separator: ", "))
                                .font(.subheadline).foregroundStyle(Palette.inkSecondary)
                            Text("You're \(o.role == "owner" ? "the owner" : "a \(o.role)")")
                                .font(.caption).foregroundStyle(Palette.inkTertiary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section("Property") {
                    NavigationLink(value: PropertyRoute.profile) {
                        row("building.2", "Details", o.profile.roomCount.map { "\($0) rooms" } ?? "Add room count")
                    }
                    NavigationLink(value: PropertyRoute.locale) {
                        row("globe", "Currency & time zone", "\(o.profile.currency) · \(o.profile.timeZone.replacingOccurrences(of: "_", with: " "))")
                    }
                    NavigationLink(value: PropertyRoute.competitors) {
                        row("binoculars", "Competitors", "\(o.counts.activeCompetitors) of \(o.plan.limits.competitors) tracked", warn: o.needsAttention.competitorsOverLimit)
                    }
                    NavigationLink(value: PropertyRoute.data) {
                        row("chart.bar.doc.horizontal", "Performance data", o.counts.performanceDays > 0 ? "\(o.counts.performanceDays) days" : (o.counts.sampleDays > 0 ? "Sample data only" : "None yet"))
                    }
                    NavigationLink(value: PropertyRoute.team) {
                        row("person.2", "Team", "\(o.counts.members) of \(o.plan.limits.teamMembers)", warn: o.needsAttention.membersOverLimit)
                    }
                }
                Section("Plan") {
                    NavigationLink(value: PropertyRoute.plan) {
                        row("sparkles", app.planName(o.plan.isPaid ? o.plan.id : o.plan.purchasedPlan), planSubtitle(o.plan))
                    }
                }
                if (app.me?.properties.count ?? 0) > 1 || app.isOwner {
                    Section("Properties") {
                        ForEach(app.me?.properties ?? []) { p in
                            Button {
                                Task {
                                    do { try await app.selectProperty(p.propertyId) } catch { errorText = error.userMessage }
                                }
                            } label: {
                                HStack {
                                    Text(p.name).foregroundStyle(Palette.ink)
                                    Spacer()
                                    if p.propertyId == app.propertyId { Image(systemName: "checkmark").foregroundStyle(Palette.teal) }
                                }
                            }
                        }
                        Button("Add another property", systemImage: "plus") { showAddProperty = true }
                    }
                }
            }
            Section("Account") {
                if let me = app.me {
                    LabeledContent("Signed in as", value: me.email ?? me.name ?? "This device")
                }
                Button("Sign out") { showSignOut = true }
                Button("Delete account", role: .destructive) { showDelete = true }
            }
            if let errorText {
                Section { Text(errorText).foregroundStyle(Palette.coral) }
            }
            Section {
                Text("revOWL calculates metrics only from data you provide. Public rates come from third-party sources and may be incomplete. Orev's suggestions are for your review and don't change anything in your systems.")
                    .font(.caption).foregroundStyle(Palette.inkTertiary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppBackground())
        .navigationTitle("Property")
        .navigationDestination(for: PropertyRoute.self) { route in
            switch route {
            case .profile: ProfileEditView()
            case .locale: LocaleEditView()
            case .competitors: CompetitorManagerView()
            case .data: DataManagerView()
            case .team: TeamView()
            case .plan: PlanManageView()
            }
        }
        .refreshable { await app.refreshOverview() }
        .confirmationDialog("Sign out of revOWL?", isPresented: $showSignOut, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) { Task { await app.signOut() } }
        }
        .alert("Delete your account?", isPresented: $showDelete) {
            Button("Delete", role: .destructive) {
                Task {
                    do { try await app.deleteAccount() } catch { errorText = error.userMessage }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Properties you own and all their data will be permanently deleted. Active App Store subscriptions must be cancelled separately in Settings.")
        }
        .alert("Add a property", isPresented: $showAddProperty) {
            Button("Continue") {
                app.overview = nil
                app.route = .onboarding
                app.onboardingStep = .property
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Each property has its own data, team and plan.")
        }
    }

    private func planSubtitle(_ plan: PlanInfo) -> String {
        switch plan.state {
        case "trial": return "Free trial until \(Fmt.shortDate(ms: plan.expiresAt))"
        case "active": return plan.willRenew ? "Renews \(Fmt.shortDate(ms: plan.expiresAt))" : "Ends \(Fmt.shortDate(ms: plan.expiresAt))"
        case "grace": return "Payment issue — update billing"
        case "expired": return "Ended — choose a plan"
        default: return "Start a 7-day free trial"
        }
    }

    private func row(_ icon: String, _ title: String, _ subtitle: String, warn: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(Palette.teal).frame(width: 28).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).foregroundStyle(Palette.ink)
                Text(subtitle).font(.footnote).foregroundStyle(warn ? Palette.coral : Palette.inkSecondary)
            }
            if warn {
                Spacer()
                Image(systemName: "exclamationmark.circle.fill").foregroundStyle(Palette.coral).accessibilityLabel("Needs attention")
            }
        }
    }
}
