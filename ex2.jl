# Adi Toubin, id: 327915484
# Aylala Trachtman, id: 327869764

# --- Arithmetic & Logical Handlers ---

function handleAdd()
    return """// add
@SP
AM=M-1
D=M
A=A-1
M=D+M
"""
end

function handleSub()
    return """// sub
@SP
AM=M-1
D=M
A=A-1
M=M-D
"""
end

function handleNeg()
    return """// neg
@SP
A=M-1
M=-M
"""
end

function handleAnd()
    return """// and
@SP
AM=M-1
D=M
A=A-1
M=D&M
"""
end

function handleOr()
    return """// or
@SP
AM=M-1
D=M
A=A-1
M=D|M
"""
end

function handleNot()
    return """// not
@SP
A=M-1
M=!M
"""
end

function handleEq(counter)
    label = "EQ_$(counter)"
    return """// eq
@SP
AM=M-1
D=M
A=A-1
D=M-D
@$label.TRUE
D;JEQ
@SP
A=M-1
M=0
@$label.END
0;JMP
($label.TRUE)
@SP
A=M-1
M=-1
($label.END)
"""
end

function handleGt(counter)
    label = "GT_$(counter)"
    return """// gt
@SP
AM=M-1
D=M
A=A-1
D=M-D
@$label.TRUE
D;JGT
@SP
A=M-1
M=0
@$label.END
0;JMP
($label.TRUE)
@SP
A=M-1
M=-1
($label.END)
"""
end

function handleLt(counter)
    label = "LT_$(counter)"
    return """// lt
@SP
AM=M-1
D=M
A=A-1
D=M-D
@$label.TRUE
D;JLT
@SP
A=M-1
M=0
@$label.END
0;JMP
($label.TRUE)
@SP
A=M-1
M=-1
($label.END)
"""
end

# --- Memory Access Handlers ---

function handlePush(segment::String, index::Int, filename::String)
    header = "// push $segment $index"
    body = ""
    if segment == "constant"
        body = "@$index\nD=A\n@SP\nA=M\nM=D\n@SP\nM=M+1\n"
    elseif segment in ["local", "argument", "this", "that"]
        seg_map = Dict("local"=>"LCL", "argument"=>"ARG", "this"=>"THIS", "that"=>"THAT")
        label = seg_map[segment]
        body = "@$index\nD=A\n@$label\nA=M+D\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1\n"
    elseif segment == "temp"
        body = "@$(5 + index)\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1\n"
    elseif segment == "pointer"
        ptr_label = index == 0 ? "THIS" : "THAT"
        body = "@$ptr_label\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1\n"
    elseif segment == "static"
        body = "@$filename.$index\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1\n"
    end
    return header * "\n" * body
end

function handlePop(segment::String, index::Int, filename::String)
    header = "// pop $segment $index"
    body = ""
    if segment in ["local", "argument", "this", "that"]
        seg_map = Dict("local"=>"LCL", "argument"=>"ARG", "this"=>"THIS", "that"=>"THAT")
        label = seg_map[segment]
        body = "@$index\nD=A\n@$label\nD=M+D\n@R13\nM=D\n@SP\nAM=M-1\nD=M\n@R13\nA=M\nM=D\n"
    elseif segment == "temp"
        body = "@SP\nAM=M-1\nD=M\n@$(5 + index)\nM=D\n"
    elseif segment == "pointer"
        ptr_label = index == 0 ? "THIS" : "THAT"
        body = "@SP\nAM=M-1\nD=M\n@$ptr_label\nM=D\n"
    elseif segment == "static"
        body = "@SP\nAM=M-1\nD=M\n@$filename.$index\nM=D\n"
    end
    return header * "\n" * body
end

# --- Program Flow Handlers (Project 08) ---

function handleLabel(label_name, current_function)
    # Labels are scoped to the function
    return "($current_function\$$label_name)\n"
end

function handleGoto(label_name, current_function)
    return "@$current_function\$$label_name\n0;JMP\n"
end

function handleIfGoto(label_name, current_function)
    return """@SP
AM=M-1
D=M
@$current_function\$$label_name
D;JNE
"""
end

# --- Function Calling Handlers (Project 08) ---

function handleFunction(func_name, num_locals)
    asm = "($func_name)\n"
    for i in 1:num_locals
        asm *= handlePush("constant", 0, "")
    end
    return asm
end

function handleCall(func_name, num_args, call_counter)
    ret_addr = "RET_ADDR_$call_counter"
    asm = "// call $func_name $num_args\n"
    # push returnAddress
    asm *= "@$ret_addr\nD=A\n@SP\nA=M\nM=D\n@SP\nM=M+1\n"
    # push LCL, ARG, THIS, THAT
    for seg in ["LCL", "ARG", "THIS", "THAT"]
        asm *= "@$seg\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1\n"
    end
    # ARG = SP - 5 - num_args
    asm *= "@SP\nD=M\n@5\nD=D-A\n@$num_args\nD=D-A\n@ARG\nM=D\n"
    # LCL = SP
    asm *= "@SP\nD=M\n@LCL\nM=D\n"
    # goto func_name
    asm *= "@$func_name\n0;JMP\n"
    # (returnAddress)
    asm *= "($ret_addr)\n"
    return asm
end

function handleReturn()
    return """// return
@LCL
D=M
@R13
M=D
@5
A=D-A
D=M
@R14
M=D
@SP
AM=M-1
D=M
@ARG
A=M
M=D
@ARG
D=M+1
@SP
M=D
@R13
AM=M-1
D=M
@THAT
M=D
@R13
AM=M-1
D=M
@THIS
M=D
@R13
AM=M-1
D=M
@ARG
M=D
@R13
AM=M-1
D=M
@LCL
M=D
@R14
A=M
0;JMP
"""
end

# --- Main Logic ---

println("enter a path:")
input_path = readline()
clean_path = strip(input_path, ['/', '\\', '\"', '\''])
last_folder = basename(clean_path)

all_files = readdir(clean_path)
vm_files = filter(f -> endswith(f, ".vm"), all_files)
output_path = joinpath(clean_path, last_folder * ".asm")

open(output_path, "w") do outfile
    label_counter = 0
    call_counter = 0
    current_function = "Main.main" # Default context

    # 1. Bootstrapping
    if length(vm_files) > 1 || any(f -> f == "Sys.vm", vm_files)
        println(outfile, "// --- Bootstrapping ---")
        println(outfile, "@256\nD=A\n@SP\nM=D")
        println(outfile, handleCall("Sys.init", 0, "BOOT"))
    end

    for vmfile in vm_files
        current_file_base = splitext(vmfile)[1]
        full_path = joinpath(clean_path, vmfile)
        println(outfile, "// --- Translating file: $vmfile ---")
        
        open(full_path, "r") do f
            for line in eachline(f)
                line = strip(line)
                if isempty(line) || startswith(line, "//") continue end
                
                clean_line = split(line, "//")[1] |> strip
                words = split(clean_line)
                cmd = words[1]

                if cmd == "add" println(outfile, handleAdd())
                elseif cmd == "sub" println(outfile, handleSub())
                elseif cmd == "neg" println(outfile, handleNeg())
                elseif cmd == "and" println(outfile, handleAnd())
                elseif cmd == "or" println(outfile, handleOr())
                elseif cmd == "not" println(outfile, handleNot())
                elseif cmd == "eq" 
                    label_counter += 1
                    println(outfile, handleEq(label_counter))
                elseif cmd == "gt" 
                    label_counter += 1
                    println(outfile, handleGt(label_counter))
                elseif cmd == "lt" 
                    label_counter += 1
                    println(outfile, handleLt(label_counter))
                elseif cmd == "push"
                    println(outfile, handlePush(String(words[2]), parse(Int, words[3]), current_file_base))
                elseif cmd == "pop"
                    println(outfile, handlePop(String(words[2]), parse(Int, words[3]), current_file_base))
                
                # --- Project 08 Commands ---
                elseif cmd == "label"
                    println(outfile, handleLabel(words[2], current_function))
                elseif cmd == "goto"
                    println(outfile, handleGoto(words[2], current_function))
                elseif cmd == "if-goto"
                    println(outfile, handleIfGoto(words[2], current_function))
                elseif cmd == "function"
                    current_function = words[2]
                    println(outfile, handleFunction(words[2], parse(Int, words[3])))
                elseif cmd == "call"
                    call_counter += 1
                    println(outfile, handleCall(words[2], parse(Int, words[3]), call_counter))
                elseif cmd == "return"
                    println(outfile, handleReturn())
                end
            end
        end
        println("Processed: $vmfile")
    end
end

println("\n--- DONE ---")
println("The Assembly file was created at: $output_path")