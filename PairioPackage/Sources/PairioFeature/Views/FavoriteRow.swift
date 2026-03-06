// FavoriteRow.swift
// Row view for displaying a saved device favorite

import SwiftUI

struct FavoriteRow: View {
    let favorite: DeviceFavorite
    let isAvailable: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirmation = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "star.fill")
                .font(.body)
                .foregroundStyle(isAvailable ? .yellow : .secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(favorite.name)
                    .font(.body)
                    .foregroundStyle(isAvailable ? .primary : .secondary)
                    .lineLimit(1)

                Text("\(favorite.deviceUIDs.count) devices")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isAvailable {
                Button("Load") {
                    onSelect()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Text("Unavailable")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                showDeleteConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .confirmationDialog(
                "Delete Favorite?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    onDelete()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete \"\(favorite.name)\"?")
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.yellow.opacity(isAvailable ? 0.1 : 0.05))
        )
    }
}
