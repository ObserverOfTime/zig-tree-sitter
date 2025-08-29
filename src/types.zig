const Writer = @import("std").Io.Writer;

/// A struct that specifies how to read input text.
pub const Input = extern struct {
    /// An arbitrary pointer that will be passed
    /// to each invocation of the `read` method.
    payload: ?*anyopaque,
    /// A function to retrieve a chunk of text at a given byte offset
    /// and (row, column) position. The function should return a pointer
    /// to the text and write its length to the `bytes_read` pointer.
    /// The parser does not take ownership of this buffer, it just borrows
    /// it until it has finished reading it. The function should write a `0`
    /// value to the `bytes_read` pointer to indicate the end of the document.
    read: *const fn (
        payload: ?*anyopaque,
        byte_index: u32,
        position: Point,
        bytes_read: *u32,
    ) callconv(.c) [*c]const u8,
    /// An indication of how the text is encoded.
    encoding: InputEncoding = .utf8,
    /// This function reads one code point from the given string, returning
    /// the number of bytes consumed. It should write the code point to
    /// the `code_point` pointer, or write `-1` if the input is invalid.
    decode: ?*const fn (
        string: [*c]const u8,
        length: u32,
        code_point: *i32,
    ) callconv(.c) u32 = null,
};

/// An edit to a text document.
pub const InputEdit = extern struct {
    start_byte: u32,
    old_end_byte: u32,
    new_end_byte: u32,
    start_point: Point,
    old_end_point: Point,
    new_end_point: Point,
};

/// A wrapper around a function that logs parsing results.
pub const Logger = extern struct {
    /// The payload of the function.
    payload: ?*anyopaque = null,
    /// The callback function.
    log: ?*const fn (
        payload: ?*anyopaque,
        log_type: LogType,
        buffer: [*:0]const u8,
    ) callconv(.c) void = null,

    /// The type of a log message.
    pub const LogType = enum(c_uint) {
        parse,
        lex,
    };
};

/// A position in a text document in terms of rows and columns.
pub const Point = extern struct {
    /// The zero-based row of the document.
    row: u32,
    /// The zero-based column of the document.
    column: u32,

    /// Compare two points.
    ///
    /// ```
    /// self == other => 0
    /// self > other => 1
    /// self < other => -1
    /// ```
    pub fn cmp(self: *const Point, other: Point) i8 {
        const row_diff = self.row - other.row;
        if (row_diff > 0) return 1;
        if (row_diff < 0) return -1;

        const col_diff = self.column - other.column;
        if (col_diff == 0) return 0;
        return if (col_diff > 0) 1 else -1;
    }

    /// Format the point as a string.
    pub fn format(self: Point, writer: *Writer) !void {
        try writer.print("({d}, {d})", .{ self.row, self.column });
    }
};

/// A range of positions in a text document,
/// both in terms of bytes and of row-column points.
pub const Range = extern struct {
    start_point: Point = .{ .row = 0, .column = 0 },
    end_point: Point = .{ .row = 0xFFFFFFFF, .column = 0xFFFFFFFF },
    start_byte: u32 = 0,
    end_byte: u32 = 0xFFFFFFFF,

    /// Format the range as a string.
    pub fn format(self: Range, writer: *Writer) !void {
        try writer.print(
            "Range(start_point={f}, end_point={f}, start_byte={d}, end_byte={d})",
            .{ self.start_point, self.end_point, self.start_byte, self.end_byte },
        );
    }
};

/// The encoding of source code.
pub const InputEncoding = enum(c_uint) {
    utf8,
    utf16le,
    utf16be,
    custom,
};
