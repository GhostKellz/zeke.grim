// Zeke core - High-performance hot paths implemented in Zig
// These functions are called from Ghostlang for performance-critical operations

const std = @import("std");

/// Approximate token count from text
/// Uses simplified estimation: ~1 token per 4 characters
pub fn tokenCount(text: []const u8) usize {
    return (text.len + 3) / 4; // Round up
}

/// Pack multiple file contents into a single buffer efficiently
/// Returns allocated buffer that caller must free
pub fn packContext(allocator: std.mem.Allocator, files: []const []const u8) ![]const u8 {
    // Calculate total size needed
    var total_size: usize = 0;
    for (files) |file_content| {
        total_size += file_content.len;
    }

    // Allocate buffer (zero-copy concat)
    const buffer = try allocator.alloc(u8, total_size);
    errdefer allocator.free(buffer);

    // Copy files into buffer
    var offset: usize = 0;
    for (files) |file_content| {
        @memcpy(buffer[offset .. offset + file_content.len], file_content);
        offset += file_content.len;
    }

    return buffer;
}

/// Apply unified diff patch to original text
/// Returns allocated buffer with patched content
pub fn applyPatch(allocator: std.mem.Allocator, original: []const u8, patch: []const u8) ![]const u8 {
    // Parse patch and apply hunks
    // This is a simplified implementation - full patch parsing is complex

    var result = std.ArrayList(u8).init(allocator);
    errdefer result.deinit();

    // For now, just use system patch command via temp files
    // TODO: Implement full patch parsing in Zig for better performance

    // Split original into lines
    var original_lines = std.ArrayList([]const u8).init(allocator);
    defer original_lines.deinit();

    var line_iter = std.mem.splitScalar(u8, original, '\n');
    while (line_iter.next()) |line| {
        try original_lines.append(line);
    }

    // Parse patch hunks
    var patch_iter = std.mem.splitScalar(u8, patch, '\n');
    var current_line: usize = 0;

    while (patch_iter.next()) |line| {
        if (line.len == 0) continue;

        // Check for hunk header: @@ -start,count +start,count @@
        if (std.mem.startsWith(u8, line, "@@")) {
            // Parse hunk header
            // Format: @@ -old_start,old_count +new_start,new_count @@
            // For simplicity, skip detailed parsing in this version
            continue;
        }

        // Apply patch line
        const first_char = line[0];
        const content = if (line.len > 1) line[1..] else "";

        switch (first_char) {
            ' ' => {
                // Context line - keep as is
                try result.appendSlice(content);
                try result.append('\n');
                current_line += 1;
            },
            '-' => {
                // Deletion - skip line
                current_line += 1;
            },
            '+' => {
                // Addition - add line
                try result.appendSlice(content);
                try result.append('\n');
            },
            else => {
                // Skip unknown lines
            },
        }
    }

    return try result.toOwnedSlice();
}

/// Fast string search with multiple patterns (Boyer-Moore-ish)
pub fn multiSearch(text: []const u8, patterns: []const []const u8) ![]const usize {
    const allocator = std.heap.page_allocator;
    var matches = std.ArrayList(usize).init(allocator);

    for (patterns) |pattern| {
        var offset: usize = 0;
        while (offset < text.len) {
            const pos = std.mem.indexOf(u8, text[offset..], pattern);
            if (pos) |p| {
                try matches.append(offset + p);
                offset += p + pattern.len;
            } else {
                break;
            }
        }
    }

    return try matches.toOwnedSlice();
}

/// Calculate edit distance between two strings (Levenshtein distance)
pub fn editDistance(allocator: std.mem.Allocator, str1: []const u8, str2: []const u8) !usize {
    const len1 = str1.len;
    const len2 = str2.len;

    // Create distance matrix
    const matrix = try allocator.alloc(usize, (len1 + 1) * (len2 + 1));
    defer allocator.free(matrix);

    // Initialize first row and column
    var i: usize = 0;
    while (i <= len1) : (i += 1) {
        matrix[i * (len2 + 1)] = i;
    }

    var j: usize = 0;
    while (j <= len2) : (j += 1) {
        matrix[j] = j;
    }

    // Fill matrix
    i = 1;
    while (i <= len1) : (i += 1) {
        j = 1;
        while (j <= len2) : (j += 1) {
            const cost: usize = if (str1[i - 1] == str2[j - 1]) 0 else 1;

            const deletion = matrix[(i - 1) * (len2 + 1) + j] + 1;
            const insertion = matrix[i * (len2 + 1) + (j - 1)] + 1;
            const substitution = matrix[(i - 1) * (len2 + 1) + (j - 1)] + cost;

            matrix[i * (len2 + 1) + j] = @min(deletion, @min(insertion, substitution));
        }
    }

    return matrix[len1 * (len2 + 1) + len2];
}

/// Fast syntax-aware line splitting
pub fn splitLines(allocator: std.mem.Allocator, text: []const u8) ![]const []const u8 {
    var lines: std.ArrayList([]const u8) = .empty;
    defer lines.deinit(allocator);

    var start: usize = 0;
    var i: usize = 0;

    while (i < text.len) : (i += 1) {
        if (text[i] == '\n') {
            try lines.append(allocator, text[start..i]);
            start = i + 1;
        }
    }

    // Add last line if not empty
    if (start < text.len) {
        try lines.append(allocator, text[start..]);
    }

    return try lines.toOwnedSlice(allocator);
}

/// Efficient whitespace trimming
pub fn trim(text: []const u8) []const u8 {
    var start: usize = 0;
    var end: usize = text.len;

    // Trim start
    while (start < end and std.ascii.isWhitespace(text[start])) {
        start += 1;
    }

    // Trim end
    while (end > start and std.ascii.isWhitespace(text[end - 1])) {
        end -= 1;
    }

    return text[start..end];
}

/// Count tokens more accurately using simple tokenization
pub fn tokenCountAccurate(_: std.mem.Allocator, text: []const u8) !usize {
    var count: usize = 0;
    var i: usize = 0;

    while (i < text.len) {
        // Skip whitespace
        while (i < text.len and std.ascii.isWhitespace(text[i])) {
            i += 1;
        }

        if (i >= text.len) break;

        // Count alphanumeric sequences
        if (std.ascii.isAlphanumeric(text[i])) {
            count += 1;
            while (i < text.len and std.ascii.isAlphanumeric(text[i])) {
                i += 1;
            }
        }
        // Count punctuation as separate tokens
        else {
            count += 1;
            i += 1;
        }
    }

    return count;
}

// FFI exports for Ghostlang
export fn zeke_token_count(text_ptr: [*]const u8, text_len: usize) usize {
    const text = text_ptr[0..text_len];
    return tokenCount(text);
}

export fn zeke_pack_context(
    allocator_ptr: *anyopaque,
    files_ptr: [*]const [*]const u8,
    file_lens: [*]const usize,
    file_count: usize,
    out_len: *usize,
) ?[*]const u8 {
    // This is complex FFI - simplified for now
    _ = allocator_ptr;
    _ = files_ptr;
    _ = file_lens;
    _ = file_count;
    _ = out_len;
    return null;
}

export fn zeke_apply_patch(
    allocator_ptr: *anyopaque,
    original_ptr: [*]const u8,
    original_len: usize,
    patch_ptr: [*]const u8,
    patch_len: usize,
    out_len: *usize,
) ?[*]const u8 {
    _ = allocator_ptr;
    _ = original_ptr;
    _ = original_len;
    _ = patch_ptr;
    _ = patch_len;
    _ = out_len;
    return null;
}

// Tests
test "token count" {
    const text = "Hello, world! This is a test.";
    const count = tokenCount(text);
    try std.testing.expect(count > 0);
}

test "pack context" {
    const allocator = std.testing.allocator;

    const files = [_][]const u8{
        "file1 content",
        "file2 content",
        "file3 content",
    };

    const result = try packContext(allocator, &files);
    defer allocator.free(result);

    try std.testing.expect(result.len == 39); // Sum of file lengths
}

test "split lines" {
    const allocator = std.testing.allocator;
    const text = "line1\nline2\nline3";

    const lines = try splitLines(allocator, text);
    defer allocator.free(lines);

    try std.testing.expectEqual(@as(usize, 3), lines.len);
    try std.testing.expectEqualStrings("line1", lines[0]);
    try std.testing.expectEqualStrings("line2", lines[1]);
    try std.testing.expectEqualStrings("line3", lines[2]);
}

test "trim whitespace" {
    const text = "  hello world  \n";
    const trimmed = trim(text);
    try std.testing.expectEqualStrings("hello world", trimmed);
}

test "edit distance" {
    const allocator = std.testing.allocator;

    const dist = try editDistance(allocator, "kitten", "sitting");
    try std.testing.expectEqual(@as(usize, 3), dist);
}
