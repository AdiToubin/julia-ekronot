#עדי טובין ת.ז. 327915484  
#אילה טרכטמן ת.ז. 327869764

# מילים שמורות בשפת Jack
const KEYWORDS = Set([ # השמה/חישוב ערך
    "class", "constructor", "function", "method", "field", "static",  # פעולה
    "var", "int", "char", "boolean", "void", "true", "false",  # פעולה
    "null", "this", "let", "do", "if", "else", "while", "return" # פעולה
]) # פעולה

# תווים מיוחדים (סימנים) מותרים בשפת Jack
const SYMBOLS = Set([ # השמה/חישוב ערך
    '{', '}', '(', ')', '[', ']', '.', ',', ';', '+', '-',  # פעולה
    '*', '/', '&', '|', '<', '>', '=', '~' # השמה/חישוב ערך
]) # פעולה

# מבנה נתונים המייצג רשומה יחידה בטבלת הסימנים (Symbol Table)
struct SymbolEntry # הגדרת מבנה נתונים
    type::String    # סוג המשתנה: int, char, boolean, או שם של מחלקה # פעולה
    kind::String    # מרחב הזיכרון ב-VM: "static", "this", "argument", "local" # פעולה
    index::Int      # אינדקס רץ המתחיל מ-0 לכל סוג בנפרד # פעולה
end # פעולה

# מנהל טבלת הסימנים
mutable struct SymbolTable # הגדרת מבנה נתונים
    class_scope::Dict{String, SymbolEntry}      # משתנים ברמת המחלקה (static / field) # פעולה
    subroutine_scope::Dict{String, SymbolEntry} # משתנים ברמת הפונקציה (local / argument) # פעולה
    counts::Dict{String, Int}                   # מונים לעקוב אחר האינדקס הרץ של כל סוג # פעולה

    function SymbolTable() # הגדרת פונקציה
        counts = Dict("static" => 0, "this" => 0, "argument" => 0, "local" => 0) # השמה/חישוב ערך
        new(Dict{String, SymbolEntry}(), Dict{String, SymbolEntry}(), counts) # פעולה
    end # פעולה
end # פעולה

# מאתחל ומנקה את מרחב תת-השגרה (Subroutine Scope) בכל כניסה לפונקציה/מתודה חדשה
function start_subroutine!(st::SymbolTable) # הגדרת פונקציה
    empty!(st.subroutine_scope) # פעולה
    st.counts["argument"] = 0 # השמה/חישוב ערך
    st.counts["local"] = 0 # השמה/חישוב ערך
end # פעולה

# מגדיר ומוסיף משתנה חדש לטבלת הסימנים
function define!(st::SymbolTable, name::String, type::String, kind::String) # הגדרת פונקציה
    vm_kind = kind # השמה/חישוב ערך
    if kind == "field" # בדיקת תנאי
        vm_kind = "this" # השמה/חישוב ערך
    elseif kind == "var" # בדיקת תנאי
        vm_kind = "local" # השמה/חישוב ערך
    end # פעולה

    index = st.counts[vm_kind] # השמה/חישוב ערך
    st.counts[vm_kind] += 1 # השמה/חישוב ערך
    entry = SymbolEntry(type, vm_kind, index) # השמה/חישוב ערך

    if vm_kind in ["static", "this"] # בדיקת תנאי
        st.class_scope[name] = entry # השמה/חישוב ערך
    else # פעולה
        st.subroutine_scope[name] = entry # השמה/חישוב ערך
    end # פעולה
end # פעולה

# מחפש משתנה לפי שמו (קודם כל במרחב הלוקאלי, ואז במרחב המחלקתי)
function lookup(st::SymbolTable, name::String) # הגדרת פונקציה
    if haskey(st.subroutine_scope, name) # בדיקת תנאי
        return st.subroutine_scope[name] # פעולה
    elseif haskey(st.class_scope, name) # בדיקת תנאי
        return st.class_scope[name] # פעולה
    else # פעולה
        return nothing # פעולה
    end # פעולה
end # פעולה

# מחזיר את כמות המשתנים שהוגדרו מסוג מסוים במרחב הנוכחי
function var_count(st::SymbolTable, kind::String) # הגדרת פונקציה
    vm_kind = kind == "field" ? "this" : (kind == "var" ? "local" : kind) # השמה/חישוב ערך
    return st.counts[vm_kind] # פעולה
end # פעולה


# ==============================================================================
# TOKENIZER - שלב הניתוח המילולי
# ==============================================================================
function tokenize_file(input_file::String) # הגדרת פונקציה
    content = read(input_file, String) # השמה/חישוב ערך
    i, n = 1, length(content) # השמה/חישוב ערך
    tokens = [] # השמה/חישוב ערך

    while i <= n # לולאה
        c = content[i] # השמה/חישוב ערך
        
        if isspace(c) # בדיקת תנאי
            i = nextind(content, i); continue # השמה/חישוב ערך
        end # פעולה
        
        # טיפול בכל סוגי ההערות (// או /* ... */)
        if c == '/' && i < n # בדיקת תנאי
            next_c = content[nextind(content, i)] # השמה/חישוב ערך
            if next_c == '/' # בדיקת תנאי
                while i <= n && content[i] != '\n'; i = nextind(content, i); end # לולאה
                continue # פעולה
            elseif next_c == '*' # בדיקת תנאי
                i = nextind(content, nextind(content, i)) # השמה/חישוב ערך
                while i < n && !(content[i] == '*' && content[nextind(content, i)] == '/') # לולאה
                    i = nextind(content, i) # השמה/חישוב ערך
                end # פעולה
                if i < n; i = nextind(content, nextind(content, i)); end # בדיקת תנאי
                continue # פעולה
            end # פעולה
        end # פעולה

        # זיהוי סימנים (Symbols)
        if c in SYMBOLS # בדיקת תנאי
            push!(tokens, ("symbol", string(c))) # פעולה
            i = nextind(content, i) # השמה/חישוב ערך
        
        # זיהוי קבועים מספריים
        elseif isdigit(c) # בדיקת תנאי
            start = i # השמה/חישוב ערך
            while i <= n && isdigit(content[i]); i = nextind(content, i); end # לולאה
            push!(tokens, ("integerConstant", content[start:prevind(content, i)])) # פעולה
        
        # זיהוי מחרוזות טקסט
        elseif c == '"' # בדיקת תנאי
            i = nextind(content, i) # השמה/חישוב ערך
            start = i # השמה/חישוב ערך
            while i <= n && content[i] != '"'; i = nextind(content, i); end # לולאה
            push!(tokens, ("stringConstant", content[start:prevind(content, i)])) # פעולה
            if i <= n; i = nextind(content, i); end # בדיקת תנאי
        
        # זיהוי מילים שמורות או מזהים
        elseif isletter(c) || c == '_' # בדיקת תנאי
            start = i # השמה/חישוב ערך
            while i <= n && (isletter(content[i]) || isdigit(content[i]) || content[i] == '_') # לולאה
                i = nextind(content, i) # השמה/חישוב ערך
            end # פעולה
            word = content[start:prevind(content, i)] # השמה/חישוב ערך
            type = word in KEYWORDS ? "keyword" : "identifier" # השמה/חישוב ערך
            push!(tokens, (type, word)) # פעולה
        else # פעולה
            i = nextind(content, i) # השמה/חישוב ערך
        end # פעולה
    end # פעולה
    return tokens # פעולה
end # פעולה


# ==============================================================================
# PARSER & CODE GENERATOR - ניתוח תחבירי וייצור קוד
# ==============================================================================

mutable struct SubroutineInfo # הגדרת מבנה נתונים
    kind::String # "method", "function", "constructor" # פעולה
end # פעולה

mutable struct ParserState # הגדרת מבנה נתונים
    tokens::Vector{Tuple{String, String}}  # פעולה
    pos::Int                                # פעולה
    vm_out::IOStream                       # פעולה
    symbol_table::SymbolTable              # פעולה
    class_name::String                     # פעולה
    label_index::Int                       # פעולה
    subroutines_map::Dict{String, SubroutineInfo}  # פעולה
end # פעולה

function peek(p::ParserState) # הגדרת פונקציה
    return p.pos <= length(p.tokens) ? p.tokens[p.pos] : ("", "") # השמה/חישוב ערך
end # פעולה

function advance!(p::ParserState) # הגדרת פונקציה
    token = peek(p) # השמה/חישוב ערך
    p.pos += 1 # השמה/חישוב ערך
    return token # פעולה
end # פעולה

function emit(p::ParserState, cmd::String) # הגדרת פונקציה
    println(p.vm_out, cmd) # פעולה
end # פעולה

# --- פונקציות הניתוח והתרגום اللוגי ---

# קומפילציה של מחלקה שלמה (Class)
function compile_class(p::ParserState) # הגדרת פונקציה
    advance!(p) # 'class' # קידום הטוקן הבא
    p.class_name = advance!(p)[2]  # קידום הטוקן הבא
    advance!(p) # '{' # קידום הטוקן הבא
    
    # שלב מקדים: מיפוי כל ה-subroutines במחלקה כדי לאפשר הבחנה בין מתודה לפונקציה
    saved_pos = p.pos # השמה/חישוב ערך
    while p.pos <= length(p.tokens) # לולאה
        tok_type, tok_val = p.tokens[p.pos] # השמה/חישוב ערך
        if tok_val in ["constructor", "function", "method"] # בדיקת תנאי
            kind = tok_val # השמה/חישוב ערך
            p.pos += 2  # השמה/חישוב ערך
            if p.pos <= length(p.tokens) # בדיקת תנאי
                sub_name = p.tokens[p.pos][2] # השמה/חישוב ערך
                p.subroutines_map[sub_name] = SubroutineInfo(kind) # השמה/חישוב ערך
            end # פעולה
        end # פעולה
        p.pos += 1 # השמה/חישוב ערך
    end # פעולה
    p.pos = saved_pos  # השמה/חישוב ערך

    # עיבוד הגדרות המשתנים של המחלקה
    while peek(p)[2] in ["static", "field"] # לולאה
        compile_class_var_dec(p) # פעולה
    end # פעולה
    
    # עיבוד הפונקציות, המתודות והבנאים
    while peek(p)[2] in ["constructor", "function", "method"] # לולאה
        compile_subroutine(p) # פעולה
    end # פעולה
    
    advance!(p) # '}' # קידום הטוקן הבא
end # פעולה

# קומפילציה של הצהרת משתני מחלקה (field/static)
function compile_class_var_dec(p::ParserState) # הגדרת פונקציה
    kind = advance!(p)[2]   # קידום הטוקן הבא
    type = advance!(p)[2]   # קידום הטוקן הבא
    name = advance!(p)[2]   # קידום הטוקן הבא
    
    define!(p.symbol_table, name, type, kind) # פעולה
    
    while peek(p)[2] == "," # לולאה
        advance!(p)  # קידום הטוקן הבא
        name = advance!(p)[2] # קידום הטוקן הבא
        define!(p.symbol_table, name, type, kind) # פעולה
    end # פעולה
    advance!(p) # ';' # קידום הטוקן הבא
end # פעולה

# קומפילציה של פונקציות, מתודות או בנאים (Subroutines)
function compile_subroutine(p::ParserState) # הגדרת פונקציה
    subroutine_kind = advance!(p)[2]  # קידום הטוקן הבא
    return_type = advance!(p)[2]      # קידום הטוקן הבא
    subroutine_name = advance!(p)[2]  # קידום הטוקן הבא
    
    start_subroutine!(p.symbol_table) # פעולה
    
    # במתודות, איבר 0 בארגומנטים מוקצה תמיד ל-this
    if subroutine_kind == "method" # בדיקת תנאי
        define!(p.symbol_table, "this", p.class_name, "argument") # פעולה
    end # פעולה
    
    advance!(p) # '(' # קידום הטוקן הבא
    compile_parameter_list(p) # פעולה
    advance!(p) # ')' # קידום הטוקן הבא
    
    advance!(p) # '{' # קידום הטוקן הבא
    while peek(p)[2] == "var" # לולאה
        compile_var_dec(p) # פעולה
    end # פעולה
    
    # הדפסת הצהרת הפונקציה ב-VM
    n_locals = var_count(p.symbol_table, "var") # השמה/חישוב ערך
    emit(p, "function $(p.class_name).$subroutine_name $n_locals") # הגדרת פונקציה
    
    # ניהול מנגנון המצביעים (pointer 0) בהתאם לסוג השגרה
    if subroutine_kind == "constructor" # בדיקת תנאי
        n_fields = var_count(p.symbol_table, "field") # השמה/חישוב ערך
        emit(p, "push constant $n_fields") # יצירת פקודת VM
        emit(p, "call Memory.alloc 1") # יצירת פקודת VM
        emit(p, "pop pointer 0")  # יצירת פקודת VM
    elseif subroutine_kind == "method" # בדיקת תנאי
        emit(p, "push argument 0") # יצירת פקודת VM
        emit(p, "pop pointer 0") # יצירת פקודת VM
    end # פעולה
    
    compile_statements(p) # פעולה
    advance!(p) # '}' # קידום הטוקן הבא
end # פעולה

# קומפילציה של רשימת הפרמטרים
function compile_parameter_list(p::ParserState) # הגדרת פונקציה
    if peek(p)[2] != ")" # בדיקת תנאי
        type = advance!(p)[2] # קידום הטוקן הבא
        name = advance!(p)[2] # קידום הטוקן הבא
        define!(p.symbol_table, name, type, "argument") # פעולה
        
        while peek(p)[2] == "," # לולאה
            advance!(p)  # קידום הטוקן הבא
            type = advance!(p)[2] # קידום הטוקן הבא
            name = advance!(p)[2] # קידום הטוקן הבא
            define!(p.symbol_table, name, type, "argument") # פעולה
        end # פעולה
    end # פעולה
end # פעולה

# קומפילציה של הצהרת משתנים מקומיים (var)
function compile_var_dec(p::ParserState) # הגדרת פונקציה
    advance!(p) # 'var' # קידום הטוקן הבא
    type = advance!(p)[2] # קידום הטוקן הבא
    name = advance!(p)[2] # קידום הטוקן הבא
    define!(p.symbol_table, name, type, "var") # פעולה
    
    while peek(p)[2] == "," # לולאה
        advance!(p)  # קידום הטוקן הבא
        name = advance!(p)[2] # קידום הטוקן הבא
        define!(p.symbol_table, name, type, "var") # פעולה
    end # פעולה
    advance!(p) # ';' # קידום הטוקן הבא
end # פעולה

# מעבר וקומפילציה של פקודות (Statements)
function compile_statements(p::ParserState) # הגדרת פונקציה
    while true # לולאה
        cmd = peek(p)[2] # השמה/חישוב ערך
        if cmd == "let"; compile_let(p) # בדיקת תנאי
        elseif cmd == "if"; compile_if(p) # בדיקת תנאי
        elseif cmd == "while"; compile_while(p) # בדיקת תנאי
        elseif cmd == "do"; compile_do(p) # בדיקת תנאי
        elseif cmd == "return"; compile_return(p) # בדיקת תנאי
        else break end # פעולה
    end # פעולה
end # פעולה

# קומפילציה של פקודת השמה (let) - סנכרון מדויק לסדר המחסנית של מערכים
function compile_let(p::ParserState) # הגדרת פונקציה
    advance!(p) # 'let' # קידום הטוקן הבא
    var_name = advance!(p)[2] # קידום הטוקן הבא
    sym = lookup(p.symbol_table, var_name) # השמה/חישוב ערך
    
    is_array = false # השמה/חישוב ערך
    if peek(p)[2] == "[" # בדיקת תנאי
        is_array = true # השמה/חישוב ערך
        advance!(p) # '[' # קידום הטוקן הבא
        compile_expression(p) # חישוב האינדקס נדחף ראשון! (כמו בקובץ ה-VM שלך) # פעולה
        advance!(p) # ']' # קידום הטוקן הבא
        emit(p, "push $(sym.kind) $(sym.index)") # דחיפת כתובת בסיס המערך # יצירת פקודת VM
        emit(p, "add") # חישוב הכתובת הסופית בזיכרון # יצירת פקודת VM
    end # פעולה
    
    advance!(p) # '=' # קידום הטוקן הבא
    compile_expression(p) # חישוב הביטוי בצד ימין # פעולה
    advance!(p) # ';' # קידום הטוקן הבא
    
    if is_array # בדיקת תנאי
        emit(p, "pop temp 0") # יצירת פקודת VM
        emit(p, "pop pointer 1") # יצירת פקודת VM
        emit(p, "push temp 0") # יצירת פקודת VM
        emit(p, "pop that 0") # יצירת פקודת VM
    else # פעולה
        emit(p, "pop $(sym.kind) $(sym.index)") # יצירת פקודת VM
    end # פעולה
end # פעולה

# קומפילציה של פקודת קריאה לפונקציה/שגרה (do)
function compile_do(p::ParserState) # הגדרת פונקציה
    advance!(p) # 'do' # קידום הטוקן הבא
    
    first_name = advance!(p)[2] # קידום הטוקן הבא
    n_args = 0 # השמה/חישוב ערך
    sub_name = "" # השמה/חישוב ערך
    
    if peek(p)[2] == "." # בדיקת תנאי
        advance!(p) # '.' # קידום הטוקן הבא
        sub_name = advance!(p)[2] # קידום הטוקן הבא
        sym = lookup(p.symbol_table, first_name) # השמה/חישוב ערך
        
        if sym !== nothing # בדיקת תנאי
            emit(p, "push $(sym.kind) $(sym.index)") # יצירת פקודת VM
            n_args = 1 # השמה/חישוב ערך
            call_target = "$(sym.type).$sub_name" # השמה/חישוב ערך
        else # פעולה
            call_target = "$first_name.$sub_name" # השמה/חישוב ערך
        end # פעולה
    else # פעולה
        is_method = true # השמה/חישוב ערך
        if haskey(p.subroutines_map, first_name) # בדיקת תנאי
            if p.subroutines_map[first_name].kind == "function" # בדיקת תנאי
                is_method = false # השמה/חישוב ערך
            end # פעולה
        end # פעולה
        
        if is_method # בדיקת תנאי
            emit(p, "push pointer 0")  # יצירת פקודת VM
            n_args = 1 # השמה/חישוב ערך
        end # פעולה
        call_target = "$(p.class_name).$first_name" # השמה/חישוב ערך
    end # פעולה
    
    advance!(p) # '(' # קידום הטוקן הבא
    n_args += compile_expression_list(p) # השמה/חישוב ערך
    advance!(p) # ')' # קידום הטוקן הבא
    advance!(p) # ';' # קידום הטוקן הבא
    
    emit(p, "call $call_target $n_args") # יצירת פקודת VM
    emit(p, "pop temp 0")  # יצירת פקודת VM
end # פעולה

# קומפילציה של פקודת תנאי (if) - מניעת באג תוויות ברקורסיה
function compile_if(p::ParserState) # הגדרת פונקציה
    local_label_idx = p.label_index # השמה/חישוב ערך
    p.label_index += 1 # השמה/חישוב ערך
    
    advance!(p) # 'if' # קידום הטוקן הבא
    advance!(p) # '(' # קידום הטוקן הבא
    compile_expression(p)  # פעולה
    advance!(p) # ')' # קידום הטוקן הבא
    
    emit(p, "if-goto IF_TRUE$(local_label_idx)") # יצירת פקודת VM
    emit(p, "goto IF_FALSE$(local_label_idx)") # יצירת פקודת VM
    emit(p, "label IF_TRUE$(local_label_idx)") # יצירת פקודת VM
    
    advance!(p) # '{' # קידום הטוקן הבא
    compile_statements(p) # פעולה
    advance!(p) # '}' # קידום הטוקן הבא
    
    if peek(p)[2] == "else" # בדיקת תנאי
        emit(p, "goto IF_END$(local_label_idx)") # יצירת פקודת VM
        emit(p, "label IF_FALSE$(local_label_idx)") # יצירת פקודת VM
        advance!(p) # 'else' # קידום הטוקן הבא
        advance!(p) # '{' # קידום הטוקן הבא
        compile_statements(p) # פעולה
        advance!(p) # '}' # קידום הטוקן הבא
        emit(p, "label IF_END$(local_label_idx)") # יצירת פקודת VM
    else # פעולה
        emit(p, "label IF_FALSE$(local_label_idx)") # יצירת פקודת VM
    end # פעולה
end # פעולה

# קומפילציה של לולאות (while)
function compile_while(p::ParserState) # הגדרת פונקציה
    local_label_idx = p.label_index # השמה/חישוב ערך
    p.label_index += 1 # השמה/חישוב ערך
    
    emit(p, "label WHILE_EXP$(local_label_idx)") # יצירת פקודת VM
    advance!(p) # 'while' # קידום הטוקן הבא
    advance!(p) # '(' # קידום הטוקן הבא
    compile_expression(p)  # פעולה
    advance!(p) # ')' # קידום הטוקן הבא
    
    emit(p, "not")  # יצירת פקודת VM
    emit(p, "if-goto WHILE_END$(local_label_idx)") # יצירת פקודת VM
    
    advance!(p) # '{' # קידום הטוקן הבא
    compile_statements(p) # פעולה
    advance!(p) # '}' # קידום הטוקן הבא
    
    emit(p, "goto WHILE_EXP$(local_label_idx)")  # יצירת פקודת VM
    emit(p, "label WHILE_END$(local_label_idx)") # יצירת פקודת VM
end # פעולה

# קומפילציה של פקודת החזרה (return)
function compile_return(p::ParserState) # הגדרת פונקציה
    advance!(p) # 'return' # קידום הטוקן הבא
    if peek(p)[2] != ";" # בדיקת תנאי
        compile_expression(p)  # פעולה
    else # פעולה
        emit(p, "push constant 0")  # יצירת פקודת VM
    end # פעולה
    advance!(p) # ';' # קידום הטוקן הבא
    emit(p, "return") # יצירת פקודת VM
end # פעולה

# קומפילציה של ביטויים (Expressions)
function compile_expression(p::ParserState) # הגדרת פונקציה
    compile_term(p)  # פעולה
    
    op_map = Dict( # השמה/חישוב ערך
        "+" => "add", "-" => "sub", "&" => "and", "|" => "or", # השמה/חישוב ערך
        "<" => "lt", ">" => "gt", "=" => "eq" # השמה/חישוב ערך
    ) # פעולה
    
    while peek(p)[2] in ["+", "-", "*", "/", "&", "|", "<", ">", "="] # לולאה
        op = advance!(p)[2] # קידום הטוקן הבא
        compile_term(p)  # פעולה
        
        if haskey(op_map, op) # בדיקת תנאי
            emit(p, op_map[op]) # יצירת פקודת VM
        elseif op == "*" # בדיקת תנאי
            emit(p, "call Math.multiply 2") # יצירת פקודת VM
        elseif op == "/" # בדיקת תנאי
            emit(p, "call Math.divide 2") # יצירת פקודת VM
        end # פעולה
    end # פעולה
end # פעולה

# קומפילציה של איבר בודד (Term) - סנכרון מלא למערכים ומחרוזות של TryClass
function compile_term(p::ParserState) # הגדרת פונקציה
    token_type, val = peek(p) # השמה/חישוב ערך
    
    if token_type == "integerConstant" # בדיקת תנאי
        advance!(p) # קידום הטוקן הבא
        emit(p, "push constant $val") # יצירת פקודת VM
        
    elseif token_type == "stringConstant" # בדיקת תנאי
        advance!(p) # קידום הטוקן הבא
        str_len = length(val) # השמה/חישוב ערך
        emit(p, "push constant $str_len") # יצירת פקודת VM
        emit(p, "call String.new 1") # יצירת פקודת VM
        for char in val # פעולה
            emit(p, "push constant $(Int(char))") # יצירת פקודת VM
            emit(p, "call String.appendChar 2") # יצירת פקודת VM
        end # פעולה
    
    elseif val in ["true", "false", "null", "this"] # בדיקת תנאי
        advance!(p) # קידום הטוקן הבא
        if val == "true" # בדיקת תנאי
            emit(p, "push constant 0") # יצירת פקודת VM
            emit(p, "not")  # יצירת פקודת VM
        elseif val in ["false", "null"] # בדיקת תנאי
            emit(p, "push constant 0") # יצירת פקודת VM
        elseif val == "this" # בדיקת תנאי
            emit(p, "push pointer 0") # יצירת פקודת VM
        end # פעולה
        
    elseif val == "(" # בדיקת תנאי
        advance!(p) # '(' # קידום הטוקן הבא
        compile_expression(p) # פעולה
        advance!(p) # ')' # קידום הטוקן הבא
        
    elseif val in ["-", "~"] # בדיקת תנאי
        op = advance!(p)[2] # קידום הטוקן הבא
        compile_term(p) # פעולה
        if op == "-" # בדיקת תנאי
            emit(p, "neg") # יצירת פקודת VM
        else # פעולה
            emit(p, "not") # יצירת פקודת VM
        end # פעולה
        
    elseif token_type == "identifier" # בדיקת תנאי
        next_val = p.pos + 1 <= length(p.tokens) ? p.tokens[p.pos+1][2] : "" # השמה/חישוב ערך
        
        if next_val == "[" # בדיקת תנאי
            # גישה למערך בתוך ביטוי: האינדקס מחושב ונדחף ראשון
            var_name = advance!(p)[2] # קידום הטוקן הבא
            sym = lookup(p.symbol_table, var_name) # השמה/חישוב ערך
            advance!(p) # '[' # קידום הטוקן הבא
            compile_expression(p) # פעולה
            advance!(p) # ']' # קידום הטוקן הבא
            
            emit(p, "push $(sym.kind) $(sym.index)") # דחיפת כתובת בסיס המערך # יצירת פקודת VM
            emit(p, "add") # יצירת פקודת VM
            
            emit(p, "pop pointer 1") # יצירת פקודת VM
            emit(p, "push that 0") # יצירת פקודת VM
            
        elseif next_val == "(" || next_val == "." # בדיקת תנאי
            first_name = advance!(p)[2] # קידום הטוקן הבא
            n_args = 0 # השמה/חישוב ערך
            sub_name = "" # השמה/חישוב ערך
            
            if peek(p)[2] == "." # בדיקת תנאי
                advance!(p) # '.' # קידום הטוקן הבא
                sub_name = advance!(p)[2] # קידום הטוקן הבא
                sym = lookup(p.symbol_table, first_name) # השמה/חישוב ערך
                if sym !== nothing # בדיקת תנאי
                    emit(p, "push $(sym.kind) $(sym.index)") # יצירת פקודת VM
                    n_args = 1 # השמה/חישוב ערך
                    call_target = "$(sym.type).$sub_name" # השמה/חישוב ערך
                else # פעולה
                    call_target = "$first_name.$sub_name" # השמה/חישוב ערך
                end # פעולה
            else # פעולה
                is_method = true # השמה/חישוב ערך
                if haskey(p.subroutines_map, first_name) # בדיקת תנאי
                    if p.subroutines_map[first_name].kind == "function" # בדיקת תנאי
                        is_method = false # השמה/חישוב ערך
                    end # פעולה
                end # פעולה
                
                if is_method # בדיקת תנאי
                    emit(p, "push pointer 0") # יצירת פקודת VM
                    n_args = 1 # השמה/חישוב ערך
                end # פעולה
                call_target = "$(p.class_name).$first_name" # השמה/חישוב ערך
            end # פעולה
            
            advance!(p) # '(' # קידום הטוקן הבא
            n_args += compile_expression_list(p) # השמה/חישוב ערך
            advance!(p) # ')' # קידום הטוקן הבא
            emit(p, "call $call_target $n_args") # יצירת פקודת VM
        else # פעולה
            var_name = advance!(p)[2] # קידום הטוקן הבא
            sym = lookup(p.symbol_table, var_name) # השמה/חישוב ערך
            emit(p, "push $(sym.kind) $(sym.index)") # יצירת פקודת VM
        end # פעולה
    end # פעולה
end # פעולה

function compile_expression_list(p::ParserState) # הגדרת פונקציה
    count = 0 # השמה/חישוב ערך
    if peek(p)[2] != ")" # בדיקת תנאי
        compile_expression(p) # פעולה
        count += 1 # השמה/חישוב ערך
        while peek(p)[2] == "," # לולאה
            advance!(p)  # קידום הטוקן הבא
            compile_expression(p) # פעולה
            count += 1 # השמה/חישוב ערך
        end # פעולה
    end # פעולה
    return count # פעולה
end # פעולה


# ==============================================================================
# MAIN DRIVER
# ==============================================================================
function main() # הגדרת פונקציה
    println("Enter the path to the directory containing .jack files:") # פעולה
    path = strip(readline()) # השמה/חישוב ערך
    
    if !isdir(path) # בדיקת תנאי
        println("Error: Invalid directory path.") # פעולה
        return # פעולה
    end # פעולה

    files = filter(f -> endswith(f, ".jack"), readdir(path)) # השמה/חישוב ערך
    
    if isempty(files) # בדיקת תנאי
        println("No .jack files found inside the specified directory.") # פעולה
        return # פעולה
    end # פעולה
    
    for f in files # פעולה
        full_input = joinpath(path, f) # השמה/חישוב ערך
        base_name = splitext(f)[1] # השמה/חישוב ערך
        
        tokens = tokenize_file(full_input) # השמה/חישוב ערך
        vm_output = joinpath(path, base_name * ".vm") # השמה/חישוב ערך
        println("Compiling $f -> $(base_name).vm ...") # פעולה
        
        open(vm_output, "w") do vm_stream # פעולה
            st = SymbolTable() # השמה/חישוב ערך
            sub_map = Dict{String, SubroutineInfo}() # השמה/חישוב ערך
            state = ParserState(tokens, 1, vm_stream, st, "", 0, sub_map) # השמה/חישוב ערך
            compile_class(state) # פעולה
        end # פעולה
    end # פעולה
    println("\nCompilation Complete! All VM files generated successfully.") # פעולה
end # פעולה

main() # פעולה