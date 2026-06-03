
#עדי טובין ת.ז. 327915484  
#אילה טרכטמן ת.ז. 327869764

# Reserved keywords in the Jack language
const KEYWORDS = Set([
    "class", "constructor", "function", "method", "field", "static", 
    "var", "int", "char", "boolean", "void", "true", "false", 
    "null", "this", "let", "do", "if", "else", "while", "return"
])

# Valid symbols allowed in Jack source code
const SYMBOLS = Set([
    '{', '}', '(', ')', '[', ']', '.', ',', ';', '+', '-', 
    '*', '/', '&', '|', '<', '>', '=', '~'
])

# Helper function to handle XML reserved characters to ensure valid XML output
function escape_xml(str::String)
    str = replace(str, "&" => "&amp;")
    str = replace(str, "<" => "&lt;")
    str = replace(str, ">" => "&gt;")
    str = replace(str, "\"" => "&quot;")
    return str
end

# Main Tokenizing function: Reads a .jack file and produces a list of tokens.
# It also saves a T.xml file containing the flat list of tokens.
function tokenize_file(input_file::String, output_file::String)
    content = read(input_file, String)
    i, n = 1, length(content)
    tokens = []

    while i <= n
        c = content[i]
        
        # Skip whitespace characters
        if isspace(c)
            i = nextind(content, i); continue
        end
        
        # COMMENT HANDLING: Check for line comments (//) or block comments (/* */)
        if c == '/' && i < n
            next_c = content[nextind(content, i)]
            if next_c == '/'
                # Single line comment - skip until end of line
                while i <= n && content[i] != '\n'; i = nextind(content, i); end
                continue
            elseif next_c == '*'
                # Multi-line comment - skip until closing */
                i = nextind(content, nextind(content, i))
                while i < n && !(content[i] == '*' && content[nextind(content, i)] == '/')
                    i = nextind(content, i)
                end
                if i < n; i = nextind(content, nextind(content, i)); end
                continue
            end
        end

        # SYMBOL IDENTIFICATION
        if c in SYMBOLS
            push!(tokens, ("symbol", string(c)))
            i = nextind(content, i)
        
        # INTEGER CONSTANTS: Sequence of digits
        elseif isdigit(c)
            start = i
            while i <= n && isdigit(content[i]); i = nextind(content, i); end
            push!(tokens, ("integerConstant", content[start:prevind(content, i)]))
        
        # STRING CONSTANTS: Text enclosed in double quotes
        elseif c == '"'
            i = nextind(content, i)
            start = i
            while i <= n && content[i] != '"'; i = nextind(content, i); end
            push!(tokens, ("stringConstant", content[start:prevind(content, i)]))
            if i <= n; i = nextind(content, i); end
        
        # KEYWORDS AND IDENTIFIERS: Starting with a letter or underscore
        elseif isletter(c) || c == '_'
            start = i
            while i <= n && (isletter(content[i]) || isdigit(content[i]) || content[i] == '_')
                i = nextind(content, i)
            end
            word = content[start:prevind(content, i)]
            # Check if the word is a reserved keyword or a user-defined identifier
            type = word in KEYWORDS ? "keyword" : "identifier"
            push!(tokens, (type, word))
        else
            # Skip unknown characters
            i = nextind(content, i)
        end
    end

    # Generate the T.xml file output
    open(output_file, "w") do f
        println(f, "<tokens>")
        for (type, val) in tokens
            println(f, "<$type> $(escape_xml(val)) </$type>")
        end
        println(f, "</tokens>")
    end
    return tokens
end


# Structure to maintain the current state of the parser
mutable struct ParserState
    tokens::Vector{Tuple{String, String}} # List of tokens from tokenizer
    pos::Int                              # Current index in the token list
    out::IOStream                         # Output stream for the .xml file
end

# Look at the current token without consuming it
function peek(p::ParserState)
    return p.pos <= length(p.tokens) ? p.tokens[p.pos] : ("", "")
end

# Write the current token to output and move to the next one
function advance!(p::ParserState)
    token = peek(p)
    println(p.out, "<$(token[1])> $(escape_xml(token[2])) </$(token[1])>")
    p.pos += 1
    return token
end

# --- Parsing Functions based on Jack Grammar ---

# Compiles a complete class: 'class' className '{' classVarDec* subroutineDec* '}'
function compile_class(p::ParserState)
    println(p.out, "<class>")
    advance!(p) # keyword: 'class'
    advance!(p) # identifier: className
    advance!(p) # symbol: '{'
    
    # Process static or field declarations
    while peek(p)[2] in ["static", "field"]
        compile_class_var_dec(p)
    end
    # Process constructor, function, or method declarations
    while peek(p)[2] in ["constructor", "function", "method"]
        compile_subroutine(p)
    end
    
    advance!(p) # symbol: '}'
    println(p.out, "</class>")
end

# Compiles static or field declarations: (static|field) type varName (',' varName)* ';'
function compile_class_var_dec(p::ParserState)
    println(p.out, "<classVarDec>")
    advance!(p) # static/field
    advance!(p) # type
    advance!(p) # varName
    # Handle multiple variables in a single line (comma separated)
    while peek(p)[2] == ","
        advance!(p) # ','
        advance!(p) # varName
    end
    advance!(p) # ';'
    println(p.out, "</classVarDec>")
end

# Compiles a subroutine: (constructor|function|method) (void|type) name '(' params ')' body
function compile_subroutine(p::ParserState)
    println(p.out, "<subroutineDec>")
    advance!(p) # constructor/function/method
    advance!(p) # return type
    advance!(p) # subroutineName
    advance!(p) # '('
    compile_parameter_list(p)
    advance!(p) # ')'
    
    # Subroutine Body: '{' varDec* statements '}'
    println(p.out, "<subroutineBody>")
    advance!(p) # '{'
    while peek(p)[2] == "var"
        compile_var_dec(p)
    end
    compile_statements(p)
    advance!(p) # '}'
    println(p.out, "</subroutineBody>")
    
    println(p.out, "</subroutineDec>")
end

# Compiles parameter list: ((type varName) (',' type varName)*)?
function compile_parameter_list(p::ParserState)
    println(p.out, "<parameterList>")
    if peek(p)[2] != ")"
        advance!(p) # type
        advance!(p) # varName
        while peek(p)[2] == ","
            advance!(p) # ','
            advance!(p) # type
            advance!(p) # varName
        end
    end
    println(p.out, "</parameterList>")
end

# Compiles local variable declarations: 'var' type varName (',' varName)* ';'
function compile_var_dec(p::ParserState)
    println(p.out, "<varDec>")
    advance!(p) # 'var'
    advance!(p) # type
    advance!(p) # name
    while peek(p)[2] == ","
        advance!(p) # ','
        advance!(p) # name
    end
    advance!(p) # ';'
    println(p.out, "</varDec>")
end

# Compiles a sequence of statements (let, if, while, do, return)
function compile_statements(p::ParserState)
    println(p.out, "<statements>")
    while true
        cmd = peek(p)[2]
        if cmd == "let"; compile_let(p)
        elseif cmd == "if"; compile_if(p)
        elseif cmd == "while"; compile_while(p)
        elseif cmd == "do"; compile_do(p)
        elseif cmd == "return"; compile_return(p)
        else break end
    end
    println(p.out, "</statements>")
end

# Compiles 'let' statement: 'let' varName ('[' index ']')? '=' expression ';'
function compile_let(p::ParserState)
    println(p.out, "<letStatement>")
    advance!(p) # let
    advance!(p) # varName
    if peek(p)[2] == "["
        advance!(p); compile_expression(p); advance!(p) # Array indexing: [ exp ]
    end
    advance!(p) # =
    compile_expression(p)
    advance!(p) # ;
    println(p.out, "</letStatement>")
end

# Compiles 'do' statement: 'do' subroutineCall ';'
function compile_do(p::ParserState)
    println(p.out, "<doStatement>")
    advance!(p) # do
    # subroutineCall handling (directly as terminals for simplicity)
    advance!(p) # identifier: name or class/var
    if peek(p)[2] == "."
        advance!(p); advance!(p) # . subroutineName
    end
    advance!(p) # '('
    compile_expression_list(p)
    advance!(p) # ')'
    advance!(p) # ';'
    println(p.out, "</doStatement>")
end

# Compiles 'if' statement: 'if' '(' exp ')' '{' stmts '}' ('else' '{' stmts '}')?
function compile_if(p::ParserState)
    println(p.out, "<ifStatement>")
    advance!(p) # if
    advance!(p) # (
    compile_expression(p)
    advance!(p) # )
    advance!(p) # {
    compile_statements(p)
    advance!(p) # }
    if peek(p)[2] == "else"
        advance!(p) # else
        advance!(p) # {
        compile_statements(p)
        advance!(p) # }
    end
    println(p.out, "</ifStatement>")
end

# Compiles 'while' statement: 'while' '(' exp ')' '{' stmts '}'
function compile_while(p::ParserState)
    println(p.out, "<whileStatement>")
    advance!(p); advance!(p) # while (
    compile_expression(p)
    advance!(p); advance!(p) # ) {
    compile_statements(p)
    advance!(p) # }
    println(p.out, "</whileStatement>")
end

# Compiles 'return' statement: 'return' expression? ';'
function compile_return(p::ParserState)
    println(p.out, "<returnStatement>")
    advance!(p) # return
    if peek(p)[2] != ";"
        compile_expression(p)
    end
    advance!(p) # ;
    println(p.out, "</returnStatement>")
end

# Compiles expression: term (op term)*
function compile_expression(p::ParserState)
    println(p.out, "<expression>")
    compile_term(p)
    ops = ["+", "-", "*", "/", "&", "|", "<", ">", "="]
    while peek(p)[2] in ops
        advance!(p) # operator
        compile_term(p)
    end
    println(p.out, "</expression>")
end

# Compiles term: intConst | strConst | keywordConst | varName | varName'['exp']' | subroutineCall | '('exp')' | unaryOp term
function compile_term(p::ParserState)
    println(p.out, "<term>")
    token_type, val = peek(p)
    
    # Simple terminal constants
    if token_type == "integerConstant" || token_type == "stringConstant" || val in ["true", "false", "null", "this"]
        advance!(p)
    # Nested expression: ( expression )
    elseif val == "("
        advance!(p); compile_expression(p); advance!(p)
    # Unary operators: -term or ~term
    elseif val in ["-", "~"]
        advance!(p); compile_term(p)
    # Identifiers: variable, array access, or subroutine call
    elseif token_type == "identifier"
        # Lookahead: determine if it's an array indexing or a subroutine call
        next_val = p.pos + 1 <= length(p.tokens) ? p.tokens[p.pos+1][2] : ""
        if next_val == "["
            advance!(p); advance!(p); compile_expression(p); advance!(p) # Array indexing
        elseif next_val == "(" || next_val == "."
            # SubroutineCall within a term
            advance!(p) # name
            if peek(p)[2] == "."
                advance!(p); advance!(p)
            end
            advance!(p); compile_expression_list(p); advance!(p)
        else
            advance!(p) # Simple variable identifier
        end
    end
    println(p.out, "</term>")
end

# Compiles a list of expressions: (expression (',' expression)*)?
function compile_expression_list(p::ParserState)
    println(p.out, "<expressionList>")
    if peek(p)[2] != ")"
        compile_expression(p)
        while peek(p)[2] == ","
            advance!(p); compile_expression(p)
        end
    end
    println(p.out, "</expressionList>")
end


function main()
    println("Enter the path to the directory:")
    path = strip(readline())
    
    if !isdir(path)
        println("Invalid directory.")
        return
    end

    # Process only .jack files in the directory
    files = filter(f -> endswith(f, ".jack"), readdir(path))
    
    for f in files
        full_input = joinpath(path, f)
        base_name = splitext(f)[1]
        
        # STAGE 1: Generate Tokenizer output (T.xml)
        t_output = joinpath(path, base_name * "T.xml")
        println("Generating $t_output...")
        tokens = tokenize_file(full_input, t_output)
        
        # STAGE 2: Generate Parser output (the structured .xml file)
        xml_output = joinpath(path, base_name * ".xml")
        println("Generating $xml_output...")
        open(xml_output, "w") do out_stream
            state = ParserState(tokens, 1, out_stream)
            # Start compilation from the top-level 'class' rule
            compile_class(state)
        end
    end
    println("\nDone! Created T.xml and .xml files for all Jack files.")
end

# Execute the program
main()