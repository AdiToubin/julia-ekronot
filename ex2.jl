# Adi Toubin, id: 327915484
# Aylala Trachtman, id: 327869764

# --- Arithmetic & Logical Handlers ---


function handleAdd()
    return """// add
@SP
AM=M-1    // Dec SP, point A to top element
D=M       // Store top element in D
A=A-1     // Point to second element
M=D+M     // Add D to second element and store in-place
"""
end

function handleSub()
    return """// sub
@SP
AM=M-1    // Dec SP
D=M       // Store top element in D
A=A-1     // Point to second element
M=M-D     // Subtract D from second element (M = M - D)
"""
end

function handleNeg()
    return """// neg
@SP
A=M-1     // Point to top element
M=-M      // Negate value in-place
"""
end

function handleAnd()
    return """// and
@SP
AM=M-1    // Dec SP
D=M
A=A-1
M=D&M     // Bitwise AND
"""
end

function handleOr()
    return """// or
@SP
AM=M-1    // Dec SP
D=M
A=A-1
M=D|M     // Bitwise OR
"""
end

function handleNot()
    return """// not
@SP
A=M-1
M=!M      // Bitwise NOT
"""
end

# Comparison operations (Eq, Gt, Lt) use branching labels and the counter 
# to ensure unique labels for every comparison instance.

function handleEq(counter)
    label = "EQ_$(counter)"
    return """// eq
@SP
AM=M-1
D=M
A=A-1
D=M-D     // Calculate difference
@$label.TRUE
D;JEQ     // Jump if D == 0 (values are equal)
@SP
A=M-1
M=0       // False (0)
@$label.END
0;JMP
($label.TRUE)
@SP
A=M-1
M=-1      // True (-1)
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
D;JGT     // Jump if first element > second element
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
D;JLT     // Jump if first element < second element
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
# Handles pushing data from segments to Stack and popping from Stack to segments.

function handlePush(segment::String, index::Int, filename::String)
    header = "// push $segment $index"
    body = ""
    if segment == "constant"
        # Constant: just push the value
        body = "@$index\nD=A\n@SP\nA=M\nM=D\n@SP\nM=M+1\n"
    elseif segment in ["local", "argument", "this", "that"]
        # Standard segments: Base pointer + index
        seg_map = Dict("local"=>"LCL", "argument"=>"ARG", "this"=>"THIS", "that"=>"THAT")
        label = seg_map[segment]
        body = "@$index\nD=A\n@$label\nA=M+D\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1\n"
    elseif segment == "temp"
        # Temp segment starts at RAM[5]
        body = "@$(5 + index)\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1\n"
    elseif segment == "pointer"
        # Pointer 0 -> THIS, Pointer 1 -> THAT
        ptr_label = index == 0 ? "THIS" : "THAT"
        body = "@$ptr_label\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1\n"
    elseif segment == "static"
        # Static uses filename.index for assembly labels
        body = "@$filename.$index\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1\n"
    end
    return header * "\n" * body
end

function handlePop(segment::String, index::Int, filename::String)
    header = "// pop $segment $index"
    body = ""
    if segment in ["local", "argument", "this", "that"]
        # Store target address in R13 temporarily, then pop D to that address
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
# Handles branching and labels. Labels are namespaced by the function name.

function handleLabel(label_name, current_function)
    # Scope label to function to avoid global collisions
    return "($current_function\$$label_name)\n"
end

function handleGoto(label_name, current_function)
    # Unconditional jump to function-scoped label
    return "@$current_function\$$label_name\n0;JMP\n"
end

function handleIfGoto(label_name, current_function)
    # Conditional jump: pop stack, jump if value != 0
    return """@SP
AM=M-1
D=M
@$current_function\$$label_name
D;JNE
"""
end

# --- Function Calling Handlers (Project 08) ---
# Complex logic for function entry, calling, and returning.

function handleFunction(func_name, num_locals)
    # Define label and initialize local variables to 0
    asm = "($func_name)\n"
    for i in 1:num_locals
        asm *= handlePush("constant", 0, "")
    end
    return asm
end

function handleCall(func_name, num_args, call_counter)
    ret_addr = "RET_ADDR_$call_counter"
    asm = "// call $func_name $num_args\n"
    # 1. push returnAddress
    asm *= "@$ret_addr\nD=A\n@SP\nA=M\nM=D\n@SP\nM=M+1\n"
    # 2. push LCL, ARG, THIS, THAT (Save caller state)
    for seg in ["LCL", "ARG", "THIS", "THAT"]
        asm *= "@$seg\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1\n"
    end
    # 3. Reposition ARG: ARG = SP - 5 - num_args
    asm *= "@SP\nD=M\n@5\nD=D-A\n@$num_args\nD=D-A\n@ARG\nM=D\n"
    # 4. Reposition LCL: LCL = SP
    asm *= "@SP\nD=M\n@LCL\nM=D\n"
    # 5. Transfer control to the function
    asm *= "@$func_name\n0;JMP\n"
    # 6. Define the return address label
    asm *= "($ret_addr)\n"
    return asm
end

function handleReturn()
    # Restore caller's state using frame and return address
    return """// return
@LCL
D=M
@R13        // R13 = FRAME (LCL)
M=D
@5
A=D-A
D=M
@R14        // R14 = RET_ADDR (FRAME - 5)
M=D
@SP
AM=M-1
D=M
@ARG
A=M
M=D         // *ARG = pop() (Result for caller)
@ARG
D=M+1
@SP
M=D         // SP = ARG + 1
@R13
AM=M-1
D=M
@THAT
M=D         // Restore THAT
@R13
AM=M-1
D=M
@THIS
M=D         // Restore THIS
@R13
AM=M-1
D=M
@ARG
M=D         // Restore ARG
@R13
AM=M-1
D=M
@LCL
M=D         // Restore LCL
@R14
A=M
0;JMP       // Jump back to caller
"""
end

# --- Main Logic ---
# Handles file I/O, directory traversal, and the main translation loop.

println("enter a path:")
input_path = readline()
clean_path = strip(input_path, ['/', '\\', '\"', '\''])
last_folder = basename(clean_path)

# Identify all .vm files in the specified directory
all_files = readdir(clean_path)
vm_files = filter(f -> endswith(f, ".vm"), all_files)
output_path = joinpath(clean_path, last_folder * ".asm")

open(output_path, "w") do outfile
    label_counter = 0
    call_counter = 0
    current_function = "Main.main" # Starting context for global code

    # 1. Bootstrapping: Initialize SP to 256 and call Sys.init
    if length(vm_files) > 1 || any(f -> f == "Sys.vm", vm_files)
        println(outfile, "// --- Bootstrapping ---")
        println(outfile, "@256\nD=A\n@SP\nM=D")
        println(outfile, handleCall("Sys.init", 0, "BOOT"))
    end

    # 2. Iterate through each .vm file
    for vmfile in vm_files
        current_file_base = splitext(vmfile)[1]
        full_path = joinpath(clean_path, vmfile)
        println(outfile, "// --- Translating file: $vmfile ---")
        
        open(full_path, "r") do f
            for line in eachline(f)
                line = strip(line)
                # Ignore empty lines and full comments
                if isempty(line) || startswith(line, "//") continue end
                
                # Remove inline comments
                clean_line = split(line, "//")[1] |> strip
                words = split(clean_line)
                cmd = words[1]

                # Map VM commands to assembly generator functions
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
                
                # --- Project 08 Commands Logic ---
                elseif cmd == "label"
                    println(outfile, handleLabel(words[2], current_function))
                elseif cmd == "goto"
                    println(outfile, handleGoto(words[2], current_function))
                elseif cmd == "if-goto"
                    println(outfile, handleIfGoto(words[2], current_function))
                elseif cmd == "function"
                    current_function = words[2] # Update current function context
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