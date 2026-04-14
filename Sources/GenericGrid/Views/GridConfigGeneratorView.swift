//
//  GridConfigGeneratorView.swift
//  GenericGrid Module
//
//  Standalone config generator view that lets users visually
//  build a GridCanvasConfig and export it as JSON.
//

import SwiftUI

// MARK: - Main view

@available(iOS 17.0, macOS 14.0, *)
public struct GridConfigGeneratorView: View {

    @State private var config = GridCanvasConfig.default
    @State private var editingZone: GridZoneDefinition?
    @State private var showZoneSheet = false
    @State private var showJSON = false
    @State private var copied = false

    /// Optional callback when the user taps "Export" — receives the JSON string.
    public var onExport: ((String) -> Void)?

    public init(onExport: ((String) -> Void)? = nil) {
        self.onExport = onExport
    }

    public var body: some View {
        NavigationStack {
            Form {
                generalSection
                labelsSection
                zonesSection
                jsonSection
            }
            .navigationTitle("Config Generator")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
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
        }
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

    // MARK: - Zones

    private var zonesSection: some View {
        Section {
            ForEach(config.zones) { zone in
                zoneRow(zone)
            }
            .onDelete { idx in config.zones.remove(atOffsets: idx) }

            Button("Add zone") {
                editingZone = nil
                showZoneSheet = true
            }
        } header: {
            Text("Zones (\(config.zones.count))")
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
                    Text("\(zone.rule.rawValue) — rows \(zone.rowStart)..<\(zone.rowEnd), cols \(zone.colStart)..<\(zone.colEnd)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
        }
        .tint(.primary)
    }

    // MARK: - JSON

    private var jsonSection: some View {
        Section("JSON") {
            DisclosureGroup("Preview", isExpanded: $showJSON) {
                ScrollView(.horizontal) {
                    Text(jsonString)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(8)
                }
                .frame(maxHeight: 300)
            }

            Button {
                #if canImport(UIKit)
                UIPasteboard.general.string = jsonString
                #elseif canImport(AppKit)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(jsonString, forType: .string)
                #endif
                withAnimation { copied = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation { copied = false }
                }
            } label: {
                Label(copied ? "Copied!" : "Copy JSON", systemImage: copied ? "checkmark" : "doc.on.doc")
            }

            if let onExport {
                Button {
                    onExport(jsonString)
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
            }
        }
    }

    // MARK: - JSON encoding

    private var jsonString: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(config),
              let str = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return str
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
                    // Pad if needed
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

    @State private var id: String
    @State private var label: String
    @State private var rule: ZoneRule
    @State private var rowStart: Int
    @State private var rowEnd: Int
    @State private var colStart: Int
    @State private var colEnd: Int
    @State private var colorHex: String
    @State private var allowedTypeNames: String // comma-separated

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

        let z = zone ?? GridZoneDefinition(
            id: "zone_\(Int.random(in: 1000...9999))",
            label: "New Zone",
            rule: .free,
            rowStart: 0, rowEnd: min(3, maxRows),
            colStart: 0, colEnd: min(3, maxCols)
        )
        _id       = State(initialValue: z.id)
        _label    = State(initialValue: z.label)
        _rule     = State(initialValue: z.rule)
        _rowStart = State(initialValue: z.rowStart)
        _rowEnd   = State(initialValue: z.rowEnd)
        _colStart = State(initialValue: z.colStart)
        _colEnd   = State(initialValue: z.colEnd)
        _colorHex = State(initialValue: z.colorHex ?? "")
        _allowedTypeNames = State(initialValue: (z.allowedTypeNames ?? []).joined(separator: ", "))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    TextField("ID", text: $id)
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
                    TextField("Color hex (e.g. #FF5733)", text: $colorHex)
                    if !colorHex.isEmpty {
                        HStack {
                            Text("Preview")
                            Spacer()
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(hex: colorHex))
                                .frame(width: 40, height: 24)
                        }
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

                        let zone = GridZoneDefinition(
                            id: id,
                            label: label,
                            rule: rule,
                            rowStart: rowStart,
                            rowEnd: rowEnd,
                            colStart: colStart,
                            colEnd: colEnd,
                            colorHex: colorHex.isEmpty ? nil : colorHex,
                            allowedTypeNames: types.isEmpty ? nil : types
                        )
                        onSave(zone)
                        dismiss()
                    }
                    .disabled(id.isEmpty || label.isEmpty || rowEnd <= rowStart || colEnd <= colStart)
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.large])
        #endif
    }
}
