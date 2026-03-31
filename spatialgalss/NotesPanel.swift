import SwiftUI

struct NoteItem: Identifiable {
    let id = UUID()
    var title: String
    var body: String
    var folder: String
    var date: Date
    var pinned: Bool = false

    var preview: String {
        let lines = body.components(separatedBy: "\n").filter { !$0.isEmpty }
        return lines.first ?? ""
    }

    var timeString: String {
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            let f = DateFormatter()
            f.dateFormat = "h:mm a"
            return f.string(from: date)
        } else {
            let f = DateFormatter()
            f.dateFormat = "MM/dd/yy"
            return f.string(from: date)
        }
    }
}

struct NotesPanel: View {
    @State private var notes: [NoteItem] = [
        // Today
        NoteItem(title: "Meeting Notes",
                 body: "Align on Q2 goals, focus on user flows and onboarding",
                 folder: "Notes", date: Date().addingTimeInterval(-3600 * 1), pinned: false),
        NoteItem(title: "App Architecture",
                 body: "MVVM with coordinators, keep views thin, async data layer",
                 folder: "Notes", date: Date().addingTimeInterval(-3600 * 3), pinned: false),
        NoteItem(title: "Species Design Plan",
                 body: "Two species are emerging: carbon and silicon.\n\nHumans design through intuition, emotion, embodied experience. AI designs through pattern recognition across billions of data points. Neither is superior — they see different dimensions of the same problem.\n\nThe play: build interfaces that serve BOTH species. Dashboards an AI agent can parse and act on. Spatial UIs a human can feel through. Same data, dual rendering.\n\nBy 2030 most software will have two users simultaneously — the person and their AI. Design for the conversation between them, not just one side.\n\nWild thought: what if AI develops aesthetic preferences? Not trained ones — emergent taste from exposure to enough human culture. A silicon Bauhaus.\n\nNearer term: ship tools that let humans direct AI creativity. The conductor model. You set intent, AI generates, you curate. Repeat at lightspeed.",
                 folder: "Futures", date: Date().addingTimeInterval(-3600 * 5), pinned: false),
        NoteItem(title: "Quick Journal",
                 body: "The best code disappears into the experience",
                 folder: "Notes", date: Date().addingTimeInterval(-3600 * 7), pinned: false),
        NoteItem(title: "Vision Pro Ideas",
                 body: "Sketch out AR app concepts for portfolio\n\nCamera passthrough with floating glass panels. Gyro parallax.",
                 folder: "Notes", date: Date().addingTimeInterval(-3600 * 9), pinned: false),
        // Pinned
        NoteItem(title: "Workout Log",
                 body: "Mon: 5k run\nWed: Push/pull\nFri: Yoga + mobility",
                 folder: "Health", date: Date().addingTimeInterval(-3600 * 26), pinned: true),
        NoteItem(title: "Weekly Goals",
                 body: "Ship v1, write blog post, review PRs, read 30 pages",
                 folder: "Notes", date: Date().addingTimeInterval(-3600 * 28), pinned: true),
        NoteItem(title: "Design Inspo",
                 body: "Glassmorphism, depth layers, subtle gradients\n\nStudy Dieter Rams. Less but better.",
                 folder: "Ideas", date: Date().addingTimeInterval(-3600 * 30), pinned: true),
        NoteItem(title: "Books to Read",
                 body: "Meditations — Marcus Aurelius\nThe Creative Act — Rick Rubin\nFour Thousand Weeks",
                 folder: "Reading", date: Date().addingTimeInterval(-3600 * 32), pinned: true),
        NoteItem(title: "Stoic Notes",
                 body: "Seneca — It is not that we have a short time to live, but that we waste a great deal of it.\n\nEpictetus — We cannot choose our external circumstances, but we can always choose how we respond.\n\nThe obstacle is the way. Amor fati.",
                 folder: "Philosophy", date: Date().addingTimeInterval(-3600 * 34), pinned: true),
    ]

    private var safeAreaTop: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.top ?? 59
    }

    @State private var selectedNote: NoteItem? = nil
    @State private var showingNew = false
    @State private var newTitle = ""
    @State private var newNoteBody = ""
    @State private var dragOffset: CGFloat = 0
    @FocusState private var newTitleFocused: Bool

    var pinnedNotes: [NoteItem] { notes.filter { $0.pinned } }
    var todayNotes: [NoteItem] {
        notes.filter { !$0.pinned && Calendar.current.isDateInToday($0.date) }
    }
    var olderNotes: [NoteItem] {
        notes.filter { !$0.pinned && !Calendar.current.isDateInToday($0.date) }
    }

    var body: some View {
        ZStack {
            if let note = selectedNote {
                NoteDetailView(note: note, onBack: { selectedNote = nil }, onSave: { updated in
                    if let idx = notes.firstIndex(where: { $0.id == updated.id }) {
                        notes[idx] = updated
                    }
                    selectedNote = updated
                })
                .offset(x: max(0, dragOffset))
                .highPriorityGesture(
                    DragGesture(minimumDistance: 20, coordinateSpace: .global)
                        .onChanged { value in
                            guard value.startLocation.x < 44 else { return }
                            if value.translation.width > 0 {
                                dragOffset = value.translation.width
                            }
                        }
                        .onEnded { value in
                            guard value.startLocation.x < 44 else {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                    dragOffset = 0
                                }
                                return
                            }
                            if value.translation.width > 80 {
                                withAnimation(.spring(response: 0.38, dampingFraction: 0.88)) {
                                    selectedNote = nil
                                    dragOffset = 0
                                }
                            } else {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                    dragOffset = 0
                                }
                            }
                        }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .trailing)
                ))
            } else if showingNew {
                newNoteView
                    .offset(x: dragOffset)
                    .gesture(
                        DragGesture(minimumDistance: 20, coordinateSpace: .local)
                            .onChanged { value in
                                if value.translation.width > 0 { dragOffset = value.translation.width }
                            }
                            .onEnded { value in
                                if value.translation.width > 100 {
                                    showingNew = false
                                    newTitle = ""
                                    newNoteBody = ""
                                }
                                dragOffset = 0
                            }
                    )
                    .transition(.move(edge: .trailing))
            } else {
                listView
                    .transition(.move(edge: .leading))
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.88), value: selectedNote?.id)
        .animation(.spring(response: 0.38, dampingFraction: 0.88), value: showingNew)
    }

    // MARK: - List view

    var listView: some View {
        VStack(spacing: 0) {

            // TOP BAR — outside the panel, above it
            HStack(spacing: 10) {
                Button(action: {}) {
                    cutoutCircle(icon: "chevron.left")
                }
                ZStack {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                    Text("All Notes")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                        .blendMode(.destinationOut)
                }
                .frame(maxWidth: .infinity, maxHeight: 44)
                .compositingGroup()
                Button(action: { showingNew = true }) {
                    cutoutCircle(icon: "ellipsis")
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 12)

            // MAIN PANEL — only the scrollable content has the material bg
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    if !pinnedNotes.isEmpty || !todayNotes.isEmpty {
                        combinedSectionContainer
                    }
                    if !olderNotes.isEmpty {
                        sectionContainer(title: "Previous 7 Days", notes: olderNotes)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 12)
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
            .padding(.horizontal, 12)

            // BOTTOM BAR — outside the panel, below it
            ZStack {
                HStack {
                    Spacer()
                    Button(action: { showingNew = true }) {
                        cutoutCircle(icon: "square.and.pencil")
                    }
                }
                ZStack {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                    Text("\(notes.count) notes")
                        .font(.system(size: 13))
                        .foregroundColor(.black)
                        .blendMode(.destinationOut)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                }
                .fixedSize()
                .compositingGroup()
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Combined pinned + today container

    var combinedSectionContainer: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !pinnedNotes.isEmpty {
                Text("Pinned")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .padding(.top, 8)

                VStack(spacing: 0) {
                    ForEach(Array(pinnedNotes.enumerated()), id: \.element.id) { index, note in
                        if index > 0 { Divider().padding(.horizontal, 16) }
                        noteCard(note)
                    }
                }
                .background(Color.white.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            if !todayNotes.isEmpty {
                Text("Today")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .padding(.top, 12)

                VStack(spacing: 0) {
                    ForEach(Array(todayNotes.enumerated()), id: \.element.id) { index, note in
                        if index > 0 { Divider().padding(.horizontal, 16) }
                        noteCard(note)
                    }
                }
                .background(Color.white.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    // MARK: - Section container

    func sectionContainer(title: String, notes: [NoteItem]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.bottom, 6)

            VStack(spacing: 0) {
                ForEach(Array(notes.enumerated()), id: \.element.id) { index, note in
                    if index > 0 { Divider().padding(.horizontal, 16) }
                    noteCard(note)
                }
            }
            .background(Color.white.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    // MARK: - Cutout circle

    func cutoutCircle(icon: String, tint: Color = .black) -> some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 44, height: 44)
                .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(tint)
                .blendMode(.destinationOut)
        }
        .frame(width: 44, height: 44)
        .compositingGroup()
    }

    // MARK: - Note card

    @ViewBuilder
    func noteCard(_ note: NoteItem) -> some View {
        Button(action: { selectedNote = note }) {
            VStack(alignment: .leading, spacing: 3) {
                Text(note.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.black)
                    .blendMode(.destinationOut)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 6) {
                    Text(note.timeString)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Text(note.preview)
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    Text(note.folder)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - New note

    var newNoteView: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5))
                HStack {
                    Button("Cancel") {
                        showingNew = false
                        newTitle = ""
                        newNoteBody = ""
                    }
                    .foregroundStyle(.secondary)
                    Spacer()
                    Text("New Note").font(.system(size: 17, weight: .semibold))
                    Spacer()
                    Button("Done") {
                        let note = NoteItem(
                            title: newTitle.isEmpty ? "New Note" : newTitle,
                            body: newNoteBody,
                            folder: "Notes",
                            date: Date()
                        )
                        notes.insert(note, at: 0)
                        showingNew = false
                        newTitle = ""
                        newNoteBody = ""
                    }
                    .fontWeight(.semibold)
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 52)
            .padding(.bottom, 8)
            .padding(.top, safeAreaTop)

            VStack(alignment: .leading, spacing: 8) {
                TextField("Title", text: $newTitle)
                    .font(.system(size: 22, weight: .bold))
                    .focused($newTitleFocused)
                Divider()
                TextEditor(text: $newNoteBody)
                    .font(.system(size: 15))
                    .scrollContentBackground(.hidden)
                    .background(.clear)
                    .frame(minHeight: 300)
            }
            .padding(16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.5))
        }
        .onAppear { newTitleFocused = true }
    }
}

// MARK: - Note detail

struct NoteDetailView: View {
    @State var note: NoteItem
    var onBack: () -> Void
    var onSave: (NoteItem) -> Void
    @State private var isEditing = false

    private var safeAreaTop: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.top ?? 59
    }

    var body: some View {
        VStack(spacing: 0) {
            // TOP BAR — outside the panel
            HStack(spacing: 10) {
                Button(action: onBack) {
                    cutoutCircle(icon: "chevron.left")
                }

                Spacer()

                ZStack {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                    HStack(spacing: 0) {
                        Button(action: {}) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(width: 44, height: 44)
                        }
                        Button(action: {}) {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(width: 44, height: 44)
                        }
                    }
                    .foregroundColor(.black)
                    .blendMode(.destinationOut)
                }
                .fixedSize()
                .frame(height: 44)
                .compositingGroup()
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 12)

            // MAIN PANEL — extends below the screen
            ZStack(alignment: .bottom) {
                ZStack(alignment: .top) {
                    // material as a sibling, not a modifier
                    UnevenRoundedRectangle(topLeadingRadius: 40, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 40, style: .continuous)
                        .fill(.ultraThinMaterial)

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 8) {
                            if isEditing {
                                TextField("Title", text: $note.title)
                                    .font(.system(size: 22, weight: .bold))
                                TextEditor(text: $note.body)
                                    .font(.system(size: 15))
                                    .scrollContentBackground(.hidden)
                                    .background(.clear)
                                    .frame(minHeight: 300)
                            } else {
                                // title knockout
                                Text(note.title)
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(.black)
                                    .blendMode(.destinationOut)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Text(note.body)
                                    .font(.system(size: 15))
                                    .foregroundStyle(.primary)
                                    .lineSpacing(4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(16)
                        .padding(.top, 8)
                        .padding(.bottom, 80)
                    }
                }
                .compositingGroup()
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 40, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 40, style: .continuous))

                // BOTTOM BAR — floating over the panel
                HStack {
                    ZStack {
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                        HStack(spacing: 0) {
                            Button(action: {}) {
                                Image(systemName: "list.bullet")
                                    .font(.system(size: 16, weight: .semibold))
                                    .frame(width: 44, height: 44)
                            }
                            Button(action: {}) {
                                Image(systemName: "paperclip")
                                    .font(.system(size: 16, weight: .semibold))
                                    .frame(width: 44, height: 44)
                            }
                            Button(action: {}) {
                                Image(systemName: "pencil.tip.crop.circle")
                                    .font(.system(size: 16, weight: .semibold))
                                    .frame(width: 44, height: 44)
                            }
                        }
                        .foregroundColor(.black)
                        .blendMode(.destinationOut)
                    }
                    .fixedSize()
                    .frame(height: 44)
                    .compositingGroup()

                    Spacer()

                    Button(action: {}) {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 44, height: 44)
                                .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                                .blendMode(.destinationOut)
                        }
                        .frame(width: 44, height: 44)
                        .compositingGroup()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .padding(.horizontal, 12)
            .ignoresSafeArea(edges: .bottom)
        }
    }

    func cutoutCircle(icon: String, tint: Color = .black) -> some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 44, height: 44)
                .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(tint)
                .blendMode(.destinationOut)
        }
        .frame(width: 44, height: 44)
        .compositingGroup()
    }
}

#Preview("Notes List") {
    NotesPanel()
}
#Preview("Note Detail") {
    NoteDetailView(
        note: NoteItem(
            title: "Species Design Plan",
            body: "Two species are emerging: carbon and silicon.\n\nHumans design through intuition, emotion, embodied experience. AI designs through pattern recognition across billions of data points. Neither is superior — they see different dimensions of the same problem.\n\nThe play: build interfaces that serve BOTH species. Dashboards an AI agent can parse and act on. Spatial UIs a human can feel through. Same data, dual rendering.\n\nBy 2030 most software will have two users simultaneously — the person and their AI. Design for the conversation between them, not just one side.",
            folder: "Futures",
            date: Date()
        ),
        onBack: {},
        onSave: { _ in }
    )
}

