module Junioraufgabe1

    function find_max_baelle(loc::String)
        input = split.(readlines(loc)[2:end])
        numbers = Vector{Vector{Int}}(undef, length(input))
        for (idx, i) in enumerate(input)
            numbers[idx] = [parse(Int, x) for x in i[3:5]]
        end

        days = Dict{String, Vector{Int}}()
        for (idx, data) in enumerate(input)
            if !haskey(days, data[2]) 
                days[data[2]] = zeros(Int, 24)
            end

            for x in (numbers[idx][1] + 1):numbers[idx][2]
                days[data[2]][x] += numbers[idx][3] 
            end
        end

        highest, highestidx = 0, 0
        highestday = ""

        for (day, content) in days
            for (hour, balls) in enumerate(content)
                if balls > highest 
                    highest = balls
                    highestidx = hour - 1
                    highestday = day
                end
            end
        end

        return highestday, highestidx, highest
    end

    function main()
        parent_path = dirname(@__DIR__)
        eingabenloc = joinpath(parent_path, "eingaben")
        ausgabenloc = joinpath(parent_path, "ausgabe.txt")
        eachloc = readdir(eingabenloc)

        touch(ausgabenloc)
        io = open(ausgabenloc, "w")

        for loc in eachloc
            output = Base.print_to_string((loc, find_max_baelle(joinpath(eingabenloc, loc)))) * '\n'
            write(io, output)
            print(output)
        end

        close(io)
    end

    main()

end 
