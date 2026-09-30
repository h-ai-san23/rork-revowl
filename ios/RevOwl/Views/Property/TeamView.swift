import SwiftUI

struct TeamView: View {
    @Environment(AppModel.self) private var app
    @State private var members: [TeamMember] = []
    @State private var limit = 1
    @State private var invite: InviteResponse?
    @State private var role = "manager"
    @State private var errorText: String?
    @State private var isWorking = false

    var body: some View {
        List {
            Section {
                ForEach(members) { m in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(m.name ?? m.email ?? "Team member").foregroundStyle(m.active ? Palette.ink : Palette.inkTertiary)
                            Text(m.role.capitalized + (m.active ? "" : " · Paused on plan")).font(.caption).foregroundStyle(Palette.inkTertiary)
                        }
                        Spacer()
                        if app.isOwner && m.role != "owner" {
                            Button("Remove", role: .destructive) { Task { await remove(m) } }
                                .buttonStyle(.borderless)
                        }
                    }
                }
            } header: {
                Text("\(members.filter(\.active).count) of \(limit) seats")
            } footer: {
                Text("Managers can edit data and settings. Viewers can read briefings and ask Orev.")
            }
            if app.isOwner {
                Section("Invite someone") {
                    Picker("Role", selection: $role) {
                        Text("Manager").tag("manager")
                        Text("Viewer").tag("viewer")
                    }
                    .pickerStyle(.segmented)
                    Button("Create invite code") { Task { await createInvite() } }
                        .disabled(isWorking)
                    if let invite {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(invite.code).font(.system(.title, design: .monospaced, weight: .bold)).foregroundStyle(Palette.ink)
                                .textSelection(.enabled)
                            Text("Share this code. It works once and expires in \(invite.expiresInDays) days. They'll choose “I have an invite code” when setting up.")
                                .font(.footnote).foregroundStyle(Palette.inkSecondary)
                            ShareLink(item: "Join my property on revOWL with invite code \(invite.code)") {
                                Label("Share code", systemImage: "square.and.arrow.up")
                            }
                        }
                    }
                }
            }
            if let errorText {
                Section {
                    Text(errorText).foregroundStyle(Palette.coral)
                    if errorText.contains("plan") || errorText.contains("Upgrade") {
                        Button("See plans") { app.showPaywall = true }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppBackground())
        .navigationTitle("Team")
        .task { await load() }
    }

    private func load() async {
        do {
            let res: TeamResponse = try await app.api.get(app.path("/team"))
            members = res.members
            limit = res.limit
        } catch {
            errorText = error.userMessage
        }
    }

    private func createInvite() async {
        isWorking = true
        errorText = nil
        defer { isWorking = false }
        do {
            invite = try await app.api.post(app.path("/team/invite"), json: ["role": .string(role)])
        } catch {
            errorText = error.userMessage
        }
    }

    private func remove(_ m: TeamMember) async {
        do {
            let _: OKResponse = try await app.api.delete(app.path("/team/\(m.accountId)"))
            await load()
            await app.refreshOverview()
        } catch {
            errorText = error.userMessage
        }
    }
}
