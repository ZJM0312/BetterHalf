import SwiftUI
import PhotosUI

struct TimelineView: View {
    @Environment(SpaceStore.self) private var store
    @State private var text = ""
    @State private var date = Date()
    @State private var mood = Catalog.moods[0]
    @State private var by: Author = .me
    @State private var photo: String?
    @State private var pickerItem: PhotosPickerItem?
    @State private var toDelete: Moment?
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            if let s = store.state {
                ScrollView {
                    VStack(spacing: 14) {
                        onThisDay(s)
                        composer(s)
                        list(s)
                    }
                    .padding(16)
                }
                .screenBackground()
                .scrollDismissesKeyboard(.interactively)
                .navigationTitle("回忆")
                .onChange(of: pickerItem) { _, item in
                    Task {
                        if let data = try? await item?.loadTransferable(type: Data.self) {
                            photo = PhotoCodec.dataURL(from: data)
                        }
                        pickerItem = nil
                    }
                }
                .confirmationDialog("删除这条回忆？", isPresented: Binding(get: { toDelete != nil }, set: { if !$0 { toDelete = nil } }),
                                    titleVisibility: .visible) {
                    Button("删除", role: .destructive) {
                        if let m = toDelete { store.update { $0.moments.removeAll { $0.id == m.id } } }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func onThisDay(_ s: SpaceState) -> some View {
        let today = DateKit.key()
        let hits = s.moments.filter { $0.date.suffix(5) == today.suffix(5) && $0.date != today }
        if !hits.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle(text: "📅 那年今天")
                ForEach(hits) { m in
                    Text("\(Text(m.date.prefix(4)).bold())  \(m.mood) \(m.text)")
                }
            }
            .card(Theme.pinkSoft)
        }
    }

    private func composer(_ s: SpaceState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: "记录一个瞬间")
            TextField("今天一起去吃了那家排队很久的店…", text: $text, axis: .vertical)
                .lineLimit(3...6)
                .focused($focused)
                .padding(12)
                .background(Theme.bg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            if let photo, let img = PhotoCodec.image(from: photo) {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: img).resizable().scaledToFill().frame(width: 110, height: 110).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    Button { self.photo = nil } label: {
                        Image(systemName: "xmark.circle.fill").font(.title3).foregroundStyle(.white, .black.opacity(0.5))
                    }
                    .padding(4)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Catalog.moods, id: \.self) { m in
                        Text(m).font(.title2).padding(4)
                            .background(m == mood ? Theme.pinkSoft : .clear, in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(m == mood ? Theme.pink : .clear, lineWidth: 2))
                            .onTapGesture { mood = m }
                    }
                }
            }
            HStack {
                DatePicker("", selection: $date, in: ...Date(), displayedComponents: .date).labelsHidden()
                Picker("记录人", selection: $by) {
                    Text(s.me).tag(Author.me)
                    Text(s.partner).tag(Author.partner)
                }
                .pickerStyle(.segmented)
            }
            HStack {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label("照片", systemImage: "camera").padding(.vertical, 13).padding(.horizontal, 16)
                        .background(Theme.bg, in: RoundedRectangle(cornerRadius: 14))
                }
                Button("保存", action: save).buttonStyle(PrimaryButtonStyle())
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && photo == nil)
            }
            if let err = store.lastError { Text(err).font(.footnote).foregroundStyle(.red) }
        }
        .card()
    }

    @ViewBuilder
    private func list(_ s: SpaceState) -> some View {
        let sorted = s.moments.sorted { $0.date > $1.date }
        if sorted.isEmpty {
            EmptyHint(text: "还没有回忆，从今天开始记录吧 ✍️")
        } else {
            LazyVStack(alignment: .leading, spacing: 14) {
                ForEach(sorted) { m in
                    HStack(alignment: .top, spacing: 10) {
                        Text(m.mood).font(.title3).frame(width: 34, height: 34)
                            .background(Theme.card, in: Circle()).shadow(color: .black.opacity(0.06), radius: 4)
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(m.date); Text(m.by == .me ? s.me : s.partner)
                                Spacer()
                                Button { toDelete = m } label: { Image(systemName: "ellipsis") }.foregroundStyle(.secondary)
                            }
                            .font(.caption).foregroundStyle(.secondary)
                            if !m.text.isEmpty { Text(m.text) }
                            if let p = m.photo, let img = PhotoCodec.image(from: p) {
                                Image(uiImage: img).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .card()
                    }
                }
            }
        }
    }

    private func save() {
        let t = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500))
        guard !t.isEmpty || photo != nil else { return }
        store.update { $0.moments.insert(Moment(date: DateKit.key(date), text: t, mood: mood, photo: photo, by: by), at: 0) }
        text = ""; photo = nil; focused = false
    }
}
