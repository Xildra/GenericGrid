//
//  GridConfigGeneratorView.swift
//  GenericGrid Module
//
//  Copyright © 2026 GenericGrid. All rights reserved.
//
//  Standalone config generator view that lets users visually
//  build a GridCanvasConfig and export it as JSON.
//  Zones can be moved and resized directly on the grid preview.
//

import SwiftUI
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

// MARK: - Main view

@available(iOS 17.0, macOS 14.0, *)
public struct GridConfigGeneratorView: View {

    @State private var config: GridCanvasConfig
    @State private var editingZone: GridZoneDefinition?
    @State private var showZoneSheet = false
    @State private var showImporter = false
    @State private var importError: String?
    @State private var saveSuccess = false

    /// URL the config was loaded from (used as default save destination).
    @State private var sourceURL: URL?

    /// Callback after a successful save — receives the URL of the written file.
    public var onExport: ((URL) -> Void)?

    // MARK: - Init

    /// Creates the generator with an empty default config.
    public init(onExport: ((URL) -> Void)? = nil) {
        config = .default
        sourceURL = nil
        self.onExport = onExport
    }

    /// Creates the generator by loading a JSON file at the given URL.
    /// If the URL is nil, falls back to a default config.
    /// On export the file is written back to the same URL.
    public init(url: URL?, onExport: ((URL) -> Void)? = nil) {
        let loaded = url.flatMap { GridCanvasConfig.load(url: $0) } ?? .default
        config = loaded
        sourceURL = url
        self.onExport = onExport
    }

    public var body: some View {
        NavigationSplitView {
            Form {
                generalSection
                labelsSection
                zonesListSection
            }
            .navigationTitle("Config")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showImporter = true
                    } label: {
                        Label("Import", systemImage: "square.and.arrow.down")
                    }
                }
                #if os(iOS)
                ToolbarItem(placement: .bottomBar) {
                    saveButton
                }
                #else
                ToolbarItem(placement: .secondaryAction) {
                    saveButton
                }
                #endif
            }
        } detail: {
            gridPreview
                .navigationTitle(config.title ?? "Preview")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
        }
        .sheet(isPresented: $showZoneSheet) {
            ZoneEditorSheet(
                zone: editingZone,
                maxRows: config.rows,
                maxCols: config.cols
            ) { saved in
                if let idx = config.zones.firstIndex(where: { $0.id == saved.id }) {
                    config.zones[idx] = saved
                } else {
                    config.zones.append(saved)
                }
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .alert("Import Error", isPresented: Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("OK") { importError = nil }
        } message: {
            Text(importError ?? "")
        }
    }

    // MARK: - Save button

    private var saveButton: some View {
        Button {
            saveAndExport()
        } label: {
            Label(
                saveSuccess ? "Saved" : "Save",
                systemImage: saveSuccess ? "checkmark.circle.fill" : "square.and.arrow.up"
            )
        }
    }

    // MARK: - Grid Preview

    private var gridPreview: some View {
        GeometryReader { geo in
            let cs = cellSize(in: geo.size)
            let W  = CGFloat(config.cols) * cs
            let H  = CGFloat(config.rows) * cs

            ScrollView([.horizontal, .vertical], showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    // Background grid lines
                    GridBackgroundLayer(rows: config.rows, cols: config.cols, cellSize: cs)

                    // Draggable zone overlays
                    ForEach(Array(config.zones.enumerated()), id: \.element.id) { idx, zone in
                        DraggableZoneView(
                            zone: zone,
                            cellSize: cs,
                            maxRows: config.rows,
                            maxCols: config.cols,
                            onUpdate: { updated in
                                config.zones[idx] = updated
                            },
                            onTap: {
                                editingZone = zone
                                showZoneSheet = true
                            }
                        )
                    }
                }
                .frame(width: W, height: H)
                .padding(16)
            }
        }
        .background(.background.secondary)
    }

    private func cellSize(in size: CGSize) -> CGFloat {
        let byCol = (size.width  - 32) / CGFloat(config.cols)
        let byRow = (size.height - 32) / CGFloat(config.rows)
        return min(60, max(20, min(byCol, byRow)))
    }

    // MARK: - General

    private var generalSection: some View {
        Section("General") {
            TextField("Title", text: Binding(
                get: { config.title ?? "" },
                set: { config.title = $0.isEmpty ? nil : $0 }
            ))
            Stepper("Rows: \(config.rows)", value: $config.rows, in: 1...100)
            Stepper("Columns: \(config.cols)", value: $config.cols, in: 1...100)
        }
    }

    // MARK: - Labels

    private var labelsSection: some View {
        Section("Labels") {
            Toggle("Custom row labels", isOn: Binding(
                get: { config.rowLabels != nil },
                set: { on in
                    config.rowLabels = on
                        ? (0..<config.rows).map { "\($0 + 1)" }
                        : nil
                }
            ))
            if let labels = config.rowLabels {
                LabelsEditor(kind: "Row", count: config.rows, labels: labels) {
                    config.rowLabels = $0
                }
            }

            Toggle("Custom column labels", isOn: Binding(
                get: { config.colLabels != nil },
                set: { on in
                    config.colLabels = on
                        ? (0..<config.cols).map { config.colLabel(at: $0) }
                        : nil
                }
            ))
            if let labels = config.colLabels {
                LabelsEditor(kind: "Col", count: config.cols, labels: labels) {
                    config.colLabels = $0
                }
            }
        }
    }

    // MARK: - Zones list

    private var zonesListSection: some View {
        Section {
            ForEach(config.zones) { zone in
                zoneRow(zone)
            }
            .onDelete { idx in config.zones.remove(atOffsets: idx) }

            Button {
                editingZone = nil
                showZoneSheet = true
            } label: {
                Label("Add zone", systemImage: "plus.circle")
            }
        } header: {
            Text("Zones (\(config.zones.count))")
        } footer: {
            if !config.zones.isEmpty {
                Text("Drag zones directly on the preview to move them. Tap to edit. Use the handles at edges to resize.")
                    .font(.caption2)
            }
        }
    }

    private func zoneRow(_ zone: GridZoneDefinition) -> some View {
        Button {
            editingZone = zone
            showZoneSheet = true
        } label: {
            HStack {
                if let hex = zone.colorHex {
                    Circle().fill(Color(hex: hex)).frame(width: 12, height: 12)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(zone.label).font(.headline)
                    Text("\(zone.rule.rawValue) — [\(zone.rowStart)..<\(zone.rowEnd), \(zone.colStart)..<\(zone.colEnd)]")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
        }
        .tint(.primary)
    }

    // MARK: - Save

    /// Returns `<Application Support>/<AppName>/Configurations/`, creating it if needed.
    /// e.g. for an app named "YourApplication" → `…/YourApplication/Configurations/`
    private static var configurationsDirectory: URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? Bundle.main.bundleIdentifier ?? "GenericGrid"
        let dir = appSupport
            .appendingPathComponent(appName, isDirectory: true)
            .appendingPathComponent("Configurations", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// Writes the current config to disk and calls `onExport` with the URL.
    /// If a `sourceURL` was provided the file is overwritten in-place,
    /// otherwise a new file is created in `<AppName>/Configurations/`.
    private func saveAndExport() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(config) else { return }

        let destination: URL
        if let sourceURL {
            destination = sourceURL
        } else {
            guard let dir = Self.configurationsDirectory else {
                importError = "Unable to access Documents directory."
                return
            }
            let name = (config.title ?? "grid_config")
                .replacingOccurrences(of: " ", with: "_")
                .lowercased()
            destination = dir.appendingPathComponent("\(name).json")
        }

        do {
            try data.write(to: destination, options: .atomic)
            // Update sourceURL so subsequent saves overwrite the same file
            sourceURL = destination
            withAnimation { saveSuccess = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation { saveSuccess = false }
            }
            onExport?(destination)
        } catch {
            importError = "Save failed: \(error.localizedDescription)"
        }
    }

    // MARK: - JSON helpers

    private var jsonString: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(config),
              let str = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return str
    }

    // MARK: - Import handler

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            if let loaded = GridCanvasConfig.load(url: url) {
                withAnimation {
                    config = loaded
                    sourceURL = url
                }
            } else {
                importError = "Unable to decode the selected JSON file as a valid GridCanvasConfig."
            }
        case .failure(let error):
            importError = error.localizedDescription
        }
    }
}

// MARK: - Draggable zone overlay

@available(iOS 17.0, macOS 14.0, *)
private struct DraggableZoneView: View {

    let zone: GridZoneDefinition
    let cellSize: CGFloat
    let maxRows: Int
    let maxCols: Int
    let onUpdate: (GridZoneDefinition) -> Void
    let onTap: () -> Void

    // Drag‐to‐move
    @State private var moveOffset: CGSize = .zero
    // Resize handles: accumulated delta in cells
    @State private var resizeDelta: ResizeDelta = .zero

    private struct ResizeDelta {
        var top: Int = 0
        var bottom: Int = 0
        var leading: Int = 0
        var trailing: Int = 0
        static let zero = ResizeDelta()
    }

    // Effective bounds during gesture
    private var eRowStart: Int { clamp(zone.rowStart + resizeDelta.top, min: 0, max: eRowEnd - 1) }
    private var eRowEnd:   Int { clamp(zone.rowEnd   + resizeDelta.bottom, min: zone.rowStart + resizeDelta.top + 1, max: maxRows) }
    private var eColStart: Int { clamp(zone.colStart + resizeDelta.leading, min: 0, max: eColEnd - 1) }
    private var eColEnd:   Int { clamp(zone.colEnd   + resizeDelta.trailing, min: zone.colStart + resizeDelta.leading + 1, max: maxCols) }

    private var x: CGFloat { CGFloat(eColStart) * cellSize }
    private var y: CGFloat { CGFloat(eRowStart) * cellSize }
    private var w: CGFloat { CGFloat(eColEnd - eColStart) * cellSize }
    private var h: CGFloat { CGFloat(eRowEnd - eRowStart) * cellSize }

    private let handleSize: CGFloat = 14

    var body: some View {
        ZStack {
            // Zone body — same look as GridZoneOverlayLayer
            RoundedRectangle(cornerRadius: 4)
                .fill((zone.color ?? .gray).opacity(0.15))
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(strokeColor, style: strokeStyle)

            VStack(spacing: 2) {
                Text(zone.label)
                    .font(.system(size: min(w / 8, 11), weight: .medium))
                    .foregroundStyle(.secondary)
                ruleIcon
            }

            // Resize handles
            resizeHandle(edge: .top)
            resizeHandle(edge: .bottom)
            resizeHandle(edge: .leading)
            resizeHandle(edge: .trailing)
        }
        .frame(width: w, height: h)
        .offset(x: x + moveOffset.width, y: y + moveOffset.height)
        // Move gesture on the body
        .gesture(moveGesture)
        .onTapGesture { onTap() }
    }

    // MARK: - Move gesture

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { v in
                moveOffset = v.translation
            }
            .onEnded { v in
                let dc = Int((v.translation.width / cellSize).rounded())
                let dr = Int((v.translation.height / cellSize).rounded())
                var z = zone
                let newColStart = clamp(z.colStart + dc, min: 0, max: maxCols - (z.colEnd - z.colStart))
                let newRowStart = clamp(z.rowStart + dr, min: 0, max: maxRows - (z.rowEnd - z.rowStart))
                let colSpan = z.colEnd - z.colStart
                let rowSpan = z.rowEnd - z.rowStart
                z.colStart = newColStart; z.colEnd = newColStart + colSpan
                z.rowStart = newRowStart; z.rowEnd = newRowStart + rowSpan
                moveOffset = .zero
                onUpdate(z)
            }
    }

    // MARK: - Resize handles

    private enum Edge { case top, bottom, leading, trailing }

    @ViewBuilder
    private func resizeHandle(edge: Edge) -> some View {
        let isHorizontal = (edge == .top || edge == .bottom)

        RoundedRectangle(cornerRadius: 2)
            .fill(Color.accentColor.opacity(0.6))
            .frame(
                width:  isHorizontal ? min(w * 0.4, 36) : handleSize * 0.45,
                height: isHorizontal ? handleSize * 0.45 : min(h * 0.4, 36)
            )
            .position(handlePosition(edge: edge))
            .gesture(resizeGesture(edge: edge))
    }

    private func handlePosition(edge: Edge) -> CGPoint {
        switch edge {
        case .top:      return CGPoint(x: w / 2, y: 0)
        case .bottom:   return CGPoint(x: w / 2, y: h)
        case .leading:  return CGPoint(x: 0, y: h / 2)
        case .trailing: return CGPoint(x: w, y: h / 2)
        }
    }

    private func resizeGesture(edge: Edge) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { v in
                var d = resizeDelta
                switch edge {
                case .top:
                    d.top = Int((v.translation.height / cellSize).rounded())
                case .bottom:
                    d.bottom = Int((v.translation.height / cellSize).rounded())
                case .leading:
                    d.leading = Int((v.translation.width / cellSize).rounded())
                case .trailing:
                    d.trailing = Int((v.translation.width / cellSize).rounded())
                }
                resizeDelta = d
            }
            .onEnded { _ in
                var z = zone
                z.rowStart = eRowStart
                z.rowEnd   = eRowEnd
                z.colStart = eColStart
                z.colEnd   = eColEnd
                resizeDelta = .zero
                onUpdate(z)
            }
    }

    // MARK: - Styling (mirrors GridZoneOverlayLayer)

    private var strokeColor: Color {
        switch zone.rule {
        case .locked:     return .orange.opacity(0.5)
        case .forbidden:  return .red.opacity(0.4)
        case .restricted: return .blue.opacity(0.4)
        case .free:       return (zone.color ?? .gray).opacity(0.3)
        }
    }

    private var strokeStyle: StrokeStyle {
        switch zone.rule {
        case .locked, .forbidden:
            return StrokeStyle(lineWidth: 1.5, dash: [6, 3])
        default:
            return StrokeStyle(lineWidth: 1)
        }
    }

    @ViewBuilder
    private var ruleIcon: some View {
        switch zone.rule {
        case .locked:
            Image(systemName: "lock.fill")
                .font(.system(size: 9)).foregroundStyle(.secondary.opacity(0.6))
        case .forbidden:
            Image(systemName: "nosign")
                .font(.system(size: 9)).foregroundStyle(.red.opacity(0.5))
        case .restricted:
            Image(systemName: "person.badge.key")
                .font(.system(size: 9)).foregroundStyle(.blue.opacity(0.5))
        case .free:
            EmptyView()
        }
    }
}

// MARK: - Labels editor

@available(iOS 17.0, macOS 14.0, *)
private struct LabelsEditor: View {
    let kind: String
    let count: Int
    let labels: [String]
    let onChange: ([String]) -> Void

    var body: some View {
        ForEach(0..<min(count, labels.count), id: \.self) { i in
            TextField("\(kind) \(i)", text: Binding(
                get: { i < labels.count ? labels[i] : "" },
                set: { newVal in
                    var copy = labels
                    while copy.count <= i { copy.append("") }
                    copy[i] = newVal
                    onChange(copy)
                }
            ))
            .font(.caption)
        }
    }
}

// MARK: - Zone editor sheet

@available(iOS 17.0, macOS 14.0, *)
private struct ZoneEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var id = UUID()
    @State private var label: String
    @State private var rule: ZoneRule
    @State private var rowStart: Int
    @State private var rowEnd: Int
    @State private var colStart: Int
    @State private var colEnd: Int
    @State private var zoneColor: Color
    @State private var hasColor: Bool
    @State private var allowedTypeNames: String

    private let isNew: Bool
    private let maxRows: Int
    private let maxCols: Int
    private let onSave: (GridZoneDefinition) -> Void

    init(zone: GridZoneDefinition?, maxRows: Int, maxCols: Int,
         onSave: @escaping (GridZoneDefinition) -> Void) {
        self.maxRows = maxRows
        self.maxCols = maxCols
        self.onSave = onSave
        self.isNew = zone == nil

        let z = zone ?? GridZoneDefinition(rowEnd: min(3, maxRows), colEnd: min(3, maxCols))
        label = z.label
        rule = z.rule
        rowStart = z.rowStart
        rowEnd   = z.rowEnd
        colStart = z.colStart
        colEnd   = z.colEnd
        hasColor = z.colorHex != nil
        zoneColor = z.color ?? .gray
        allowedTypeNames = (z.allowedTypeNames ?? []).joined(separator: ", ")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    TextField("Label", text: $label)
                }

                Section("Rule") {
                    Picker("Rule", selection: $rule) {
                        Text("Free").tag(ZoneRule.free)
                        Text("Locked").tag(ZoneRule.locked)
                        Text("Forbidden").tag(ZoneRule.forbidden)
                        Text("Restricted").tag(ZoneRule.restricted)
                    }
                    #if os(iOS)
                    .pickerStyle(.segmented)
                    #endif

                    if rule == .restricted {
                        TextField("Allowed types (comma-separated)", text: $allowedTypeNames)
                            .font(.caption)
                    }
                }

                Section("Bounds (0-indexed, end exclusive)") {
                    Stepper("Row start: \(rowStart)", value: $rowStart, in: 0...(maxRows - 1))
                    Stepper("Row end: \(rowEnd)", value: $rowEnd, in: 1...maxRows)
                    Stepper("Col start: \(colStart)", value: $colStart, in: 0...(maxCols - 1))
                    Stepper("Col end: \(colEnd)", value: $colEnd, in: 1...maxCols)
                }

                Section("Appearance") {
                    HStack {
                        Text("Zone color")
                        Spacer()
                        if hasColor {
                            ColorPicker("", selection: $zoneColor, supportsOpacity: false)
                                .labelsHidden()
                                .frame(width: 32, height: 32)
                        }
                        Button {
                            withAnimation {
                                if hasColor {
                                    hasColor = false
                                } else {
                                    hasColor = true
                                    zoneColor = .gray
                                }
                            }
                        } label: {
                            Image(systemName: hasColor ? "circle.slash" : "circle.slash.fill")
                                .font(.title3)
                                .foregroundStyle(hasColor ? Color.secondary : Color.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle(isNew ? "New Zone" : "Edit Zone")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let types = allowedTypeNames
                            .split(separator: ",")
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }

                        let hex: String? = hasColor ? zoneColor.toHex() : nil

                        var zone = GridZoneDefinition(
                            label: label,
                            rule: rule,
                            rowStart: rowStart,
                            rowEnd: rowEnd,
                            colStart: colStart,
                            colEnd: colEnd,
                            colorHex: hex,
                            allowedTypeNames: types.isEmpty ? nil : types
                        )
                        zone.id = id
                        onSave(zone)
                        dismiss()
                    }
                    .disabled(label.isEmpty || rowEnd <= rowStart || colEnd <= colStart)
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.large])
        #endif
    }
}

// MARK: - Utility

private func clamp(_ value: Int, min lo: Int, max hi: Int) -> Int {
    Swift.min(hi, Swift.max(lo, value))
}
