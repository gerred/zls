const std = @import("std");
const string = []const u8;

// LSP types
// https://microsoft.github.io/language-server-protocol/specifications/specification-3-16/

pub const Position = struct {
    line: i64,
    character: i64,
};

pub const Range = struct {
    start: Position,
    end: Position,
};

pub const Location = struct {
    uri: string,
    range: Range,
};

/// Id of a request
pub const RequestId = union(enum) {
    String: string,
    Integer: i64,
    Float: f64,
};

/// Hover response
pub const Hover = struct {
    contents: MarkupContent,
};

/// Params of a response (result)
pub const ResponseParams = union(enum) {
    SignatureHelp: SignatureHelp,
    CompletionList: CompletionList,
    Location: Location,
    Hover: Hover,
    DocumentSymbols: []DocumentSymbol,
    SemanticTokensFull: struct { data: []const u32 },
    TextEdits: []TextEdit,
    Locations: []Location,
    WorkspaceEdit: WorkspaceEdit,
    InitializeResult: InitializeResult,
    ConfigurationParams: ConfigurationParams,
};

/// JSONRPC notifications
pub const Notification = struct {
    pub const Params = union(enum) {
        LogMessage: struct {
            type: MessageType,
            message: string,
        },
        PublishDiagnostics: struct {
            uri: string,
            diagnostics: []Diagnostic,
        },
        ShowMessage: struct {
            type: MessageType,
            message: string,
        },
    };

    jsonrpc: string = "2.0",
    method: string,
    params: Params,
};

/// JSONRPC response
pub const Response = struct {
    jsonrpc: string = "2.0",
    id: RequestId,
    result: ResponseParams,
};

pub const Request = struct {
    jsonrpc: string = "2.0",
    method: []const u8,
    params: ?ResponseParams,
};

/// Type of a debug message
pub const MessageType = enum(i64) {
    Error = 1,
    Warning = 2,
    Info = 3,
    Log = 4,

    pub fn jsonStringify(value: MessageType, options: std.json.StringifyOptions, out_stream: anytype) !void {
        try std.json.stringify(@enumToInt(value), options, out_stream);
    }
};

pub const DiagnosticSeverity = enum(i64) {
    Error = 1,
    Warning = 2,
    Information = 3,
    Hint = 4,

    pub fn jsonStringify(value: DiagnosticSeverity, options: std.json.StringifyOptions, out_stream: anytype) !void {
        try std.json.stringify(@enumToInt(value), options, out_stream);
    }
};

pub const Diagnostic = struct {
    range: Range,
    severity: DiagnosticSeverity,
    code: string,
    source: string,
    message: string,
};

pub const TextDocument = struct {
    uri: string,
    // This is a substring of mem starting at 0
    text: [:0]const u8,
    // This holds the memory that we have actually allocated.
    mem: []u8,

    const Held = struct {
        document: *const TextDocument,
        popped: u8,
        start_index: usize,
        end_index: usize,

        pub fn data(self: @This()) [:0]const u8 {
            return self.document.mem[self.start_index..self.end_index :0];
        }

        pub fn release(self: *@This()) void {
            self.document.mem[self.end_index] = self.popped;
        }
    };

    pub fn borrowNullTerminatedSlice(self: *const @This(), start_idx: usize, end_idx: usize) Held {
        std.debug.assert(end_idx >= start_idx);
        const popped_char = self.mem[end_idx];
        self.mem[end_idx] = 0;
        return .{
            .document = self,
            .popped = popped_char,
            .start_index = start_idx,
            .end_index = end_idx,
        };
    }
};

pub const WorkspaceEdit = struct {
    changes: ?std.StringHashMap([]TextEdit),

    pub fn jsonStringify(self: WorkspaceEdit, options: std.json.StringifyOptions, writer: anytype) @TypeOf(writer).Error!void {
        try writer.writeByte('{');
        if (self.changes) |changes| {
            try writer.writeAll("\"changes\": {");
            var it = changes.iterator();
            var idx: usize = 0;
            while (it.next()) |entry| : (idx += 1) {
                if (idx != 0) try writer.writeAll(", ");

                try writer.writeByte('"');
                try writer.writeAll(entry.key_ptr.*);
                try writer.writeAll("\":");
                try std.json.stringify(entry.value_ptr.*, options, writer);
            }
            try writer.writeByte('}');
        }
        try writer.writeByte('}');
    }
};

pub const TextEdit = struct {
    range: Range,
    newText: string,
};

pub const MarkupContent = struct {
    pub const Kind = enum(u1) {
        PlainText = 0,
        Markdown = 1,

        pub fn jsonStringify(value: Kind, options: std.json.StringifyOptions, out_stream: anytype) !void {
            const str = switch (value) {
                .PlainText => "plaintext",
                .Markdown => "markdown",
            };
            try std.json.stringify(str, options, out_stream);
        }
    };

    kind: Kind = .Markdown,
    value: string,
};

pub const CompletionList = struct {
    isIncomplete: bool,
    items: []const CompletionItem,
};

pub const InsertTextFormat = enum(i64) {
    PlainText = 1,
    Snippet = 2,

    pub fn jsonStringify(value: InsertTextFormat, options: std.json.StringifyOptions, out_stream: anytype) !void {
        try std.json.stringify(@enumToInt(value), options, out_stream);
    }
};

pub const CompletionItem = struct {
    const Kind = enum(i64) {
        Text = 1,
        Method = 2,
        Function = 3,
        Constructor = 4,
        Field = 5,
        Variable = 6,
        Class = 7,
        Interface = 8,
        Module = 9,
        Property = 10,
        Unit = 11,
        Value = 12,
        Enum = 13,
        Keyword = 14,
        Snippet = 15,
        Color = 16,
        File = 17,
        Reference = 18,
        Folder = 19,
        EnumMember = 20,
        Constant = 21,
        Struct = 22,
        Event = 23,
        Operator = 24,
        TypeParameter = 25,

        pub fn jsonStringify(value: Kind, options: std.json.StringifyOptions, out_stream: anytype) !void {
            try std.json.stringify(@enumToInt(value), options, out_stream);
        }
    };

    label: string,
    kind: Kind,
    textEdit: ?TextEdit = null,
    filterText: ?string = null,
    insertText: string = "",
    insertTextFormat: ?InsertTextFormat = .PlainText,
    detail: ?string = null,
    documentation: ?MarkupContent = null,
};

pub const DocumentSymbol = struct {
    const Kind = enum(u32) {
        File = 1,
        Module = 2,
        Namespace = 3,
        Package = 4,
        Class = 5,
        Method = 6,
        Property = 7,
        Field = 8,
        Constructor = 9,
        Enum = 10,
        Interface = 11,
        Function = 12,
        Variable = 13,
        Constant = 14,
        String = 15,
        Number = 16,
        Boolean = 17,
        Array = 18,
        Object = 19,
        Key = 20,
        Null = 21,
        EnumMember = 22,
        Struct = 23,
        Event = 24,
        Operator = 25,
        TypeParameter = 26,

        pub fn jsonStringify(value: Kind, options: std.json.StringifyOptions, out_stream: anytype) !void {
            try std.json.stringify(@enumToInt(value), options, out_stream);
        }
    };

    name: string,
    detail: ?string = null,
    kind: Kind,
    deprecated: bool = false,
    range: Range,
    selectionRange: Range,
    children: []const DocumentSymbol = &[_]DocumentSymbol{},
};

pub const WorkspaceFolder = struct {
    uri: string,
    name: string,
};

pub const SignatureInformation = struct {
    pub const ParameterInformation = struct {
        // TODO Can also send a pair of encoded offsets
        label: string,
        documentation: ?MarkupContent,
    };

    label: string,
    documentation: ?MarkupContent,
    parameters: ?[]const ParameterInformation,
    activeParameter: ?u32,
};

pub const SignatureHelp = struct {
    signatures: ?[]const SignatureInformation,
    activeSignature: ?u32,
    activeParameter: ?u32,
};

// Only includes options we set in our initialize result.
const InitializeResult = struct {
    offsetEncoding: string,
    capabilities: struct {
        signatureHelpProvider: struct {
            triggerCharacters: []const string,
            retriggerCharacters: []const string,
        },
        textDocumentSync: enum(u32) {
            None = 0,
            Full = 1,
            Incremental = 2,

            pub fn jsonStringify(value: @This(), options: std.json.StringifyOptions, out_stream: anytype) !void {
                try std.json.stringify(@enumToInt(value), options, out_stream);
            }
        },
        renameProvider: bool,
        completionProvider: struct {
            resolveProvider: bool,
            triggerCharacters: []const string,
        },
        documentHighlightProvider: bool,
        hoverProvider: bool,
        codeActionProvider: bool,
        declarationProvider: bool,
        definitionProvider: bool,
        typeDefinitionProvider: bool,
        implementationProvider: bool,
        referencesProvider: bool,
        documentSymbolProvider: bool,
        colorProvider: bool,
        documentFormattingProvider: bool,
        documentRangeFormattingProvider: bool,
        foldingRangeProvider: bool,
        selectionRangeProvider: bool,
        workspaceSymbolProvider: bool,
        rangeProvider: bool,
        documentProvider: bool,
        workspace: ?struct {
            workspaceFolders: ?struct {
                supported: bool,
                changeNotifications: bool,
            },
        },
        semanticTokensProvider: struct {
            full: bool,
            range: bool,
            legend: struct {
                tokenTypes: []const string,
                tokenModifiers: []const string,
            },
        },
    },
    serverInfo: struct {
        name: string,
        version: ?string = null,
    },
};

pub const ConfigurationParams = struct {
    items: []const ConfigurationItem,

    pub const ConfigurationItem = struct {
        scopeUri: ?[]const u8,
        section: ?[]const u8,
    };
};
