import SwiftUI

/// Écran Listes (⌘4) : la colonne des listes à gauche, la liste choisie à droite.
struct ListsView: View {
    @Binding var list: TaskList

    var body: some View {
        HStack(spacing: 0) {
            ListsColumn(list: $list)
            TaskListView(list: list) { list = $0 }
                .id(list)
                .padding(.top, 26)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// Colonne des listes, à gauche de l'écran Listes : l'Inbox, puis les projets (avec leurs sous-projets)
/// et les étiquettes, en sections repliables. 240 de large sur bgSunken. Glisser une tâche sur une liste
/// l'y range ; un clic droit renomme, range ou supprime.
private struct ListsColumn: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var list: TaskList

    @State private var dropTarget: String?
    @State private var naming: Naming?
    @State private var nameDraft = ""
    @State private var deletingProject: Project?

    @State private var removingTag: String?

    @AppStorage(SettingsKey.sidebarProjectsCollapsed) private var projectsCollapsed = false
    @AppStorage(SettingsKey.sidebarTagsCollapsed) private var tagsCollapsed = false
    /// Projets dont les sous-projets sont repliés, séparés par des virgules.
    @AppStorage(SettingsKey.sidebarFoldedProjects) private var foldedProjects = ""

    private enum Naming: Identifiable {
        case new
        case newSub(Project)
        case rename(Project)
        case renameTag(String)

        var id: String {
            switch self {
            case .new: "new"
            case .newSub(let parent): "sub:" + parent.id
            case .rename(let project): project.id
            case .renameTag(let tag): "tag:" + tag
            }
        }

        var title: String {
            switch self {
            case .new: "Nouveau projet"
            case .newSub(let parent): "Nouveau sous-projet dans « \(parent.name) »"
            case .rename: "Renommer le projet"
            case .renameTag: "Renommer l'étiquette"
            }
        }

        var action: String {
            switch self {
            case .new, .newSub: "Créer"
            case .rename, .renameTag: "Renommer"
            }
        }

        var placeholder: String {
            switch self {
            case .new, .rename: "Nom du projet"
            case .newSub: "Nom du sous-projet"
            case .renameTag: "Nom de l'étiquette"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DoneSpace.s2) {
            Text("Listes")
                .doneText(.displayM)
                .foregroundStyle(DoneColor.textPrimary)
                .padding(.horizontal, DoneSpace.s12)
                .padding(.bottom, DoneSpace.s12)
            listItem(.inbox, name: "Inbox", symbol: "tray")

            ScrollView {
                VStack(alignment: .leading, spacing: DoneSpace.s2) {
                    sectionHeader("Projets", collapsed: $projectsCollapsed)
                    if !projectsCollapsed {
                        ForEach(model.topLevelProjects) { project in
                            let subprojects = model.subprojects(of: project.id)
                            let folded = isFolded(project.id)
                            listItem(
                                .project(project.id),
                                name: project.name,
                                symbol: "folder",
                                isExpanded: subprojects.isEmpty ? nil : !folded
                            ) {
                                toggleFold(project.id)
                            }
                            .contextMenu { projectMenu(project) }
                            if !folded {
                                ForEach(subprojects) { subproject in
                                    listItem(.project(subproject.id), name: subproject.name, symbol: "folder")
                                        .padding(.leading, DoneSpace.s16)
                                        .contextMenu { projectMenu(subproject) }
                                }
                            }
                        }
                        Button {
                            nameDraft = ""
                            naming = .new
                        } label: {
                            Label("Nouveau projet", systemImage: "plus")
                        }
                        .buttonStyle(DoneButtonStyle(kind: .plain, compact: true))
                        .padding(.top, DoneSpace.s4)
                    }
                    if !model.tags.isEmpty {
                        sectionHeader("Étiquettes", collapsed: $tagsCollapsed)
                        if !tagsCollapsed {
                            ForEach(model.tags, id: \.self) { tag in
                                listItem(.tag(tag), name: tag, symbol: "tag")
                                    .contextMenu { tagMenu(tag) }
                            }
                        }
                    }
                }
            }
            .scrollIndicators(.never)
            .padding(.top, DoneSpace.s8)
        }
        .padding(.horizontal, DoneSpace.s12)
        .padding(.top, 30)
        .padding(.bottom, DoneSpace.s12)
        .frame(width: 240)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(DoneColor.bgSunken)
        .overlay(alignment: .trailing) {
            Rectangle().fill(DoneColor.borderSubtle).frame(width: 1)
        }
        .alert(naming?.title ?? "", isPresented: Binding(get: { naming != nil }, set: { if !$0 { naming = nil } })) {
            TextField(naming?.placeholder ?? "Nom", text: $nameDraft)
            Button("Annuler", role: .cancel) { naming = nil }
            Button(naming?.action ?? "OK") { commitNaming() }
        }
        .confirmationDialog(
            "Supprimer le projet « \(deletingProject?.name ?? "") » ?",
            isPresented: Binding(get: { deletingProject != nil }, set: { if !$0 { deletingProject = nil } }),
            presenting: deletingProject
        ) { project in
            Button("Supprimer le projet", role: .destructive) {
                if list == .project(project.id) { list = .inbox }
                model.deleteProject(project.id)
                deletingProject = nil
            }
        } message: { project in
            let count = model.index.all.filter { $0.parentID == nil && $0.projectID == project.id }.count
            let tasks = count == 0 ? "Il ne contient aucune tâche ouverte." : "Ses \(count) tâche\(count > 1 ? "s" : "") passe\(count > 1 ? "nt" : "") dans l'Inbox."
            Text(model.subprojects(of: project.id).isEmpty ? tasks : tasks + " Ses sous-projets deviennent des projets.")
        }
        .confirmationDialog(
            "Retirer l'étiquette « \(removingTag ?? "") » ?",
            isPresented: Binding(get: { removingTag != nil }, set: { if !$0 { removingTag = nil } }),
            presenting: removingTag
        ) { tag in
            Button("Retirer l'étiquette", role: .destructive) {
                if list == .tag(tag) { list = .inbox }
                model.removeTag(tag)
                removingTag = nil
            }
        } message: { tag in
            let count = model.openCount(in: .tag(tag))
            Text("Elle disparaît de \(count == 1 ? "sa tâche" : "ses \(count) tâches") ; les tâches restent dans leur projet, ou dans l'Inbox.")
        }
    }

    /// Titre de section repliable : « Projets », « Étiquettes ». Done se souvient de l'état.
    private func sectionHeader(_ title: String, collapsed: Binding<Bool>) -> some View {
        Button {
            withAnimation(DoneMotion.motion(DoneMotion.move, reduced: reduceMotion)) { collapsed.wrappedValue.toggle() }
        } label: {
            HStack(spacing: DoneSpace.s6) {
                Eyebrow(text: title)
                Spacer()
                Image(systemName: collapsed.wrappedValue ? "chevron.right" : "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(DoneColor.textSecondary)
            }
            .padding(.horizontal, DoneSpace.s8)
            .padding(.top, DoneSpace.s16)
            .padding(.bottom, DoneSpace.s6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(collapsed.wrappedValue ? "Afficher \(title.lowercased())" : "Masquer \(title.lowercased())")
    }

    private func isFolded(_ id: String) -> Bool {
        foldedProjects.split(separator: ",").contains { $0 == id }
    }

    private func toggleFold(_ id: String) {
        var ids = foldedProjects.split(separator: ",").map(String.init)
        if ids.contains(id) { ids.removeAll { $0 == id } } else { ids.append(id) }
        withAnimation(DoneMotion.motion(DoneMotion.move, reduced: reduceMotion)) { foldedProjects = ids.joined(separator: ",") }
    }

    private func listItem(_ item: TaskList, name: String, symbol: String, isExpanded: Bool? = nil, onToggle: @escaping () -> Void = {}) -> some View {
        let key = switch item {
        case .inbox: "inbox"
        case .project(let id): "project:" + id
        case .tag(let tag): "tag:" + tag
        }
        let count = model.openCount(in: item)
        return NavItem(
            title: name,
            icon: Image(systemName: symbol),
            counter: count > 0 ? "\(count)" : nil,
            isSelected: list == item,
            isDropTarget: dropTarget == key,
            isExpanded: isExpanded,
            onToggle: onToggle
        ) {
            list = item
        }
        // Glisser une tâche sur une liste l'y range : projet, étiquette en plus, ou retour à l'Inbox.
        .dropDestination(for: String.self) { ids, _ in
            ids.forEach { model.file($0, into: item) }
            return true
        } isTargeted: { targeted in
            if targeted {
                dropTarget = key
            } else if dropTarget == key {
                dropTarget = nil
            }
        }
    }

    @ViewBuilder
    private func projectMenu(_ project: Project) -> some View {
        let siblings = project.parentID.map { model.subprojects(of: $0) } ?? model.topLevelProjects
        let hasSubprojects = !model.subprojects(of: project.id).isEmpty
        Button("Renommer…") {
            nameDraft = project.name
            naming = .rename(project)
        }
        if project.parentID == nil {
            Button("Nouveau sous-projet…") {
                nameDraft = ""
                naming = .newSub(project)
            }
        }
        Button("Monter") { model.shiftProject(project.id, by: -1) }
            .disabled(project.id == siblings.first?.id)
        Button("Descendre") { model.shiftProject(project.id, by: 1) }
            .disabled(project.id == siblings.last?.id)
        // Un projet qui a des sous-projets reste au premier niveau.
        if !hasSubprojects {
            Menu("Ranger dans") {
                ForEach(model.topLevelProjects.filter { $0.id != project.id && $0.id != project.parentID }) { parent in
                    Button(parent.name) { model.moveProject(project.id, under: parent.id) }
                }
            }
        }
        if project.parentID != nil {
            Button("Sortir du projet") { model.moveProject(project.id, under: nil) }
        }
        Divider()
        Button("Supprimer le projet…", role: .destructive) { deletingProject = project }
    }

    @ViewBuilder
    private func tagMenu(_ tag: String) -> some View {
        Button("Renommer…") {
            nameDraft = tag
            naming = .renameTag(tag)
        }
        Divider()
        Button("Retirer l'étiquette…", role: .destructive) { removingTag = tag }
    }

    private func commitNaming() {
        switch naming {
        case .new:
            if let project = model.addProject(named: nameDraft) { list = .project(project.id) }
        case .newSub(let parent):
            if let project = model.addProject(named: nameDraft, parentID: parent.id) {
                if isFolded(parent.id) { toggleFold(parent.id) }
                list = .project(project.id)
            }
        case .rename(let project):
            model.renameProject(project.id, to: nameDraft)
        case .renameTag(let old):
            model.renameTag(old, to: nameDraft)
            // Reste sur la vue de l'étiquette, sous son nouveau nom (ou celui de l'étiquette où elle s'est fondue).
            if list == .tag(old) {
                let name = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                if let renamed = model.tags.first(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
                    list = .tag(renamed)
                }
            }
        case nil:
            break
        }
        naming = nil
    }
}
