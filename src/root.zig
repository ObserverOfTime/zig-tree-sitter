// NOTE: remember to update the version numbers

/// The latest ABI version that is supported by the current version of the library.
///
/// The Tree-sitter library is generally backwards-compatible with
/// languages generated using older CLI versions, but is not forwards-compatible.
pub const LANGUAGE_VERSION = 15;

/// The earliest ABI version that is supported by the current version of the library.
pub const MIN_COMPATIBLE_LANGUAGE_VERSION = 13;

const types = @import("types.zig");
pub const Input = types.Input;
pub const InputEdit = types.InputEdit;
pub const InputEncoding = types.InputEncoding;
pub const Logger = types.Logger;
pub const Point = types.Point;
pub const Range = types.Range;

pub const Language = @import("language.zig").Language;
pub const LookaheadIterator = @import("lookahead_iterator.zig").LookaheadIterator;
pub const Node = @import("node.zig").Node;
pub const Parser = @import("parser.zig").Parser;
pub const Query = @import("query.zig").Query;
pub const QueryCursor = @import("query_cursor.zig").QueryCursor;
pub const Tree = @import("tree.zig").Tree;
pub const TreeCursor = @import("tree_cursor.zig").TreeCursor;

const wasm = @import("wasm.zig");
pub const WasmEngine = wasm.WasmEngine;
pub const WasmStore = wasm.WasmStore;

pub const setAllocator = @import("alloc.zig").setAllocator;
