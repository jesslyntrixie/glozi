//
//  DictionaryDatabase.swift
//  glozi
//
//  Created by Jesslyn Trixie Edvilie on 08/09/26.
//

import Foundation
import SQLite3

struct DictionaryEntry {
    let simplified: String
    let traditional: String
    let pinyin: String
    let definitions: [String]
}

/// Read-only access to the CC-CEDICT database shipped in the app bundle.
/// Everything C-shaped is confined to this file.
final class DictionaryDatabase {

    private var database: OpaquePointer?
    private var lookup: OpaquePointer?

    /// Fails (returns nil) if the file is missing or unreadable.
    init?(url: URL) {
        guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            return nil
        }

        // Compiled once, reused for every lookup.
        let sql = """
            SELECT simplified, traditional, pinyin, definitions
            FROM entries
            WHERE simplified = ? OR traditional = ?
            """

        guard sqlite3_prepare_v2(database, sql, -1, &lookup, nil) == SQLITE_OK else {
            return nil
        }
    }

    deinit {
        sqlite3_finalize(lookup)
        sqlite3_close(database)
    }

    /// Every entry filed under this exact headword. Empty if there is none.
    /// A headword can have several entries: 的 is both `de` and `dī`.
    func entries(for headword: String) -> [DictionaryEntry] {
        guard let lookup else { return [] }

        // Wind the compiled statement back to the start before reusing it.
        sqlite3_reset(lookup)
        sqlite3_clear_bindings(lookup)

        var results: [DictionaryEntry] = []

        headword.withCString { cString in
            // nil here is SQLite's SQLITE_STATIC: "this text will still be alive
            // when you read it, no need to copy it". True because all the
            // stepping happens inside this closure, where cString is guaranteed
            // to exist. That is why the awkward SQLITE_TRANSIENT constant is gone.
            sqlite3_bind_text(lookup, 1, cString, -1, nil)
            sqlite3_bind_text(lookup, 2, cString, -1, nil)

            // step() returns SQLITE_ROW once per matching row, then SQLITE_DONE.
            while sqlite3_step(lookup) == SQLITE_ROW {
                results.append(DictionaryEntry(
                    simplified:  text(at: 0),
                    traditional: text(at: 1),
                    pinyin:      text(at: 2),
                    definitions: text(at: 3).components(separatedBy: "\n")
                ))
            }
        }

        return results
    }

    private func text(at column: Int32) -> String {
        guard let cString = sqlite3_column_text(lookup, column) else { return "" }
        return String(cString: cString)
    }
}
