max_comment_line_length = 121

globals = {
    "box",
    "checkers",
    "package",
}

ignore = {
    -- Accessing an undefined field of a global variable <debug>.
    "143/debug",
    -- Accessing an undefined field of a global variable <os>.
    "143/os",
    -- Accessing an undefined field of a global variable <string>.
    "143/string",
    -- Accessing an undefined field of a global variable <table>.
    "143/table",
    -- Unused argument <self>.
    "212/self",
    -- Unused variable with `_` prefix.
    "212/_.*",
}

include_files = {
    '.luacheckrc',
    '**/*.lua',
}

exclude_files = {
    '.rocks',
}
