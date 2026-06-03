
#עדי טובין ת.ז. 327915484  
#אילה טרכטמן ת.ז. 327869764


# Arithmetic command handlers
function handleAdd()
   return "command: add"
end

function handleSub()
   return "command: sub"
end

function handleNeg()
   return "command: neg"
end

# Logical command handlers
function handleEq()
   return "command: eq"
end

function handleGt()
   return "command: gt"
end

function handleLt()
   return "command: lt"
end

# Memory access handlers
function handlePush(segment::String, index::Int)
   return "command: push segment $segment index $index"
end

function handlePop(segment::String, index::Int)
   return "command: pop segment $segment index $index"
end

# Ask user for the input directory path
println("enter a path:")
input_path = readline()

# Extract the last folder name from the path
last_folder = basename(input_path)
global folder_name = last_folder

# Get all files in the directory
all_files = readdir(input_path)

# Filter only .vm files
vm_files = filter(f -> endswith(f, ".vm"), all_files)

# Output file name will be the folder name with .asm extension
filename = last_folder * ".asm"

# Open the output file for writing
open(filename, "w") do file
    # Iterate over each VM file
    for vmfile in vm_files

        # Counter for logical commands in the current file
        counter = 0

        # Save current file name without extension
        global current_file = splitext(vmfile)[1]

        # Build full path to the VM file
        full_path = joinpath(input_path, vmfile)
        
        # Open the VM file for reading
        open(full_path, "r") do f
            # Read the file line by line
            for line in eachline(f)

                # Remove leading/trailing whitespace
                line = strip(line)

                # Skip empty lines and comments
                if isempty(line) || startswith(line, "//")
                    continue
                end

                # Split the line into words
                words = split(line)    
                first_word = words[1]

                # Determine command type and call the appropriate handler
                if first_word == "add"
                    println(file, handleAdd())

                elseif first_word == "sub"
                    println(file, handleSub())

                elseif first_word == "neg"
                    println(file, handleNeg())

                elseif first_word == "eq"
                     counter += 1
                    println(file, handleEq())
                    println(file, "counter: $counter")

                elseif first_word == "gt"
                    counter += 1
                    println(file, handleGt())
                    println(file, "counter: $counter")          

                elseif first_word == "lt"
                    counter += 1
                    println(file, handleLt())
                    println(file, "counter: $counter")

                # Handle push command
                elseif first_word == "push"
                    segment = String(words[2])
                    index = parse(Int, words[3])
                    println(file, handlePush(segment, index))

                # Handle pop command
                elseif first_word == "pop"
                    segment = String(words[2])
                    index = parse(Int, words[3])
                    println(file, handlePop(segment, index))

                # Handle unknown commands
                else
                    println(file, "Unknown command: $line")
                end
            end
        end

        # Print message after finishing each input file
        println("End of input file: $current_file.vm")
    end

    # Print message after finishing all files
    println("Output file is ready: $filename")
end