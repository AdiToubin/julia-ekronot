#Adi Toubin , id: 327915484  
#Aylala Trachtman , id: 327869764
# Arithmetic & Logical Handlers
# Handles 'add' command: pop two values, add them, and push the result
function handleAdd()
    return """
    // add
    @SP
    AM=M-1
    D=M
    A=A-1
    M=D+M
    """
end

# Handles 'sub' command: pop two values, subtract (y from x), and push the result
function handleSub()
    return """
    // sub
    @SP
    AM=M-1
    D=M
    A=A-1
    M=M-D
    """
end

# Handles 'neg' command: negate the value at the top of the stack
function handleNeg()
    return """
    // neg
    @SP
    A=M-1
    M=-M
    """
end

# Handles 'and' command: bitwise AND of the two top stack values
function handleAnd()
    return """
    // and
    @SP
    AM=M-1
    D=M
    A=A-1
    M=D&M
    """
end

# Handles 'or' command: bitwise OR of the two top stack values
function handleOr()
    return """
    // or
    @SP
    AM=M-1
    D=M
    A=A-1
    M=D|M
    """
end

# Handles 'not' command: bitwise NOT of the value at the top of the stack
function handleNot()
    return """
    // not
    @SP
    A=M-1
    M=!M
    """
end

# Comparison Handlers (with Labels) 

# Handles 'eq' command: checks if two top values are equal
function handleEq(counter)
    label = "EQ_$(counter)"
    return """
    // eq
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

# Handles 'gt' command: checks if x > y
function handleGt(counter)
    label = "GT_$(counter)"
    return """
    // gt
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

# Handles 'lt' command: checks if x < y
function handleLt(counter)
    label = "LT_$(counter)"
    return """
    // lt
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

# Memory Access Handlers

# Handles 'push' commands for various memory segments
function handlePush(segment::String, index::Int, filename::String)
    header = "// push $segment $index"
    body = ""
    if segment == "constant"
        body = """
        @$index
        D=A
        @SP
        A=M
        M=D
        @SP
        M=M+1
        """
    elseif segment in ["local", "argument", "this", "that"]
        seg_map = Dict("local"=>"LCL", "argument"=>"ARG", "this"=>"THIS", "that"=>"THAT")
        label = seg_map[segment]
        body = """
        @$index
        D=A
        @$label
        A=M+D
        D=M
        @SP
        A=M
        M=D
        @SP
        M=M+1
        """
    elseif segment == "temp"
        body = """
        @$(5 + index)
        D=M
        @SP
        A=M
        M=D
        @SP
        M=M+1
        """
    elseif segment == "pointer"
        ptr_label = index == 0 ? "THIS" : "THAT"
        body = """
        @$ptr_label
        D=M
        @SP
        A=M
        M=D
        @SP
        M=M+1
        """
    elseif segment == "static"
        body = """
        @$filename.$index
        D=M
        @SP
        A=M
        M=D
        @SP
        M=M+1
        """
    end
    return header * "\n" * body
end

# Handles 'pop' commands for various memory segments
function handlePop(segment::String, index::Int, filename::String)
    header = "// pop $segment $index"
    body = ""
    if segment in ["local", "argument", "this", "that"]
        seg_map = Dict("local"=>"LCL", "argument"=>"ARG", "this"=>"THIS", "that"=>"THAT")
        label = seg_map[segment]
        body = """
        @$index
        D=A
        @$label
        D=M+D
        @R13
        M=D
        @SP
        AM=M-1
        D=M
        @R13
        A=M
        M=D
        """
    elseif segment == "temp"
        body = """
        @SP
        AM=M-1
        D=M
        @$(5 + index)
        M=D
        """
    elseif segment == "pointer"
        ptr_label = index == 0 ? "THIS" : "THAT"
        body = """
        @SP
        AM=M-1
        D=M
        @$ptr_label
        M=D
        """
    elseif segment == "static"
        body = """
        @SP
        AM=M-1
        D=M
        @$filename.$index
        M=D
        """
    end
    return header * "\n" * body
end

# Main Logic

println("enter a path:")
input_path = readline()
# Clean input path from quotes and trailing slashes
clean_path = strip(input_path, ['/', '\\', '\"', '\''])
last_folder = basename(clean_path)

# List all files and filter for .vm files
all_files = readdir(clean_path)
vm_files = filter(f -> endswith(f, ".vm"), all_files)

# Define output .asm file path named after the directory
output_path = joinpath(clean_path, last_folder * ".asm")

open(output_path, "w") do outfile
    label_counter = 0

    for vmfile in vm_files
        current_file_base = splitext(vmfile)[1]
        full_path = joinpath(clean_path, vmfile)
        
        # Add a comment to differentiate between source files in the output
        println(outfile, "// Translating file: $vmfile")
        
        open(full_path, "r") do f
            for line in eachline(f)
                line = strip(line)
                # Skip empty lines and comments
                if isempty(line) || startswith(line, "//")
                    continue
                end

                # Clean inline comments from the line
                clean_line = split(line, "//")[1] |> strip
                words = split(clean_line)
                cmd = words[1]

                # Arithmetic and Logical commands
                if cmd == "add"
                    println(outfile, handleAdd())
                elseif cmd == "sub"
                    println(outfile, handleSub())
                elseif cmd == "neg"
                    println(outfile, handleNeg())
                elseif cmd == "and"
                    println(outfile, handleAnd())
                elseif cmd == "or"
                    println(outfile, handleOr())
                elseif cmd == "not"
                    println(outfile, handleNot())
                
                # Comparison commands (require unique labels)
                elseif cmd == "eq"
                    label_counter += 1
                    println(outfile, handleEq(label_counter))
                elseif cmd == "gt"
                    label_counter += 1
                    println(outfile, handleGt(label_counter))
                elseif cmd == "lt"
                    label_counter += 1
                    println(outfile, handleLt(label_counter))
                
                # Memory Access commands (push/pop)
                elseif cmd == "push"
                    segment = String(words[2])
                    index = parse(Int, words[3])
                    println(outfile, handlePush(segment, index, current_file_base))
                elseif cmd == "pop"
                    segment = String(words[2])
                    index = parse(Int, words[3])
                    println(outfile, handlePop(segment, index, current_file_base))
                end
            end
        end
        println("Processed: $vmfile")
    end
end

println("\n--- DONE ---")
println("The Assembly file was created at: $output_path")