module Junioraufgabe2

# 
#   Lars Silbentrennung:
#

vokale = ['a','e','i','o','u', 'ö', 'ä', 'ü', 'A', 'E', 'I', 'O', 'U', 'Ö', 'Ä', 'Ü']
punctuation = ['.',',','?','!']

function lr_1(word, pos::Int)
    if !(word[pos] in vokale) && !(word[pos+1] in vokale)
        return 1
    else
        return 2
    end
end

function lr_2(word, pos::Int)
    if pos == 1 return 0 end
    if pos == (length(word)-1) return 0 end
    return 2
end

function lr_3(word, pos::Int)
    if pos < 2 return 2 end
    if !(word[pos - 1] in vokale) && !(word[pos] in vokale) && !(word[pos + 1] in vokale)
        return 0
    else
        return 2
    end
end

function lr_4(word, pos::Int)
    if pos + 2 > length(word) && (word[pos] in vokale) return 1 end
    if word[pos] in vokale && (word[pos+1] in vokale || word[pos+2] in vokale)
        return 1
    else
        return 2
    end
end

function lars_silbentrennung(loc::String)
    input = collect.(split(read(loc,String)))
    output = ""
    for word in input

        punct_present = false
        if word[end] in punctuation
            punct = word[end]
            word = word[1:end-1]
            punct_present = true
        end

        for idx in 1:(length(word)-1)

            output *= word[idx]

            rule_decisions = [lr_4(word,idx), lr_3(word,idx), lr_2(word,idx), lr_1(word,idx)]
            for decision in rule_decisions
                if decision == 1
                    output *= '-'
                    break
                elseif decision == 0
                    break
                end
            end

        end

        output *= word[end]
        if punct_present
            output *= punct
        end
        output *= ' '

    end
    return output
end

#
#   Eigene Silbentrennung:
#

silbenkerne = ['a', 'e', 'o', 'u', 'i', 'ä', 'ö', 'ü', 'A', 'E', 'I', 'O', 'U', 'Ö', 'Ä', 'Ü']
doppelte_silbenkerne = ["äu", "aa", "ee", "oo", "ei", "eu", "au", "ie", "ai", "Äu", "Ei", "Ai", "Eu", "Au", "Ie", "Aa", "Oo", "Ee"]
klebrige_konsonanten = [['c', 'k'], ['s','c', 'h'], ['c','h'], ['k', 'r'], ['p','l'], ['k','n'], ['t', 'r'], ['t','h'], ['p', 'h'], ['s','t'],['b','r'], ['g','l']]

function eigene_silbentrennung(loc::String)
    input = collect.(split(read(loc,String)))
    output = ""
    for word in input

        is_doppel_kerne(k, idx) = begin d_k = [x[1] for x in filter(x -> x[2] ,k)]; idx in d_k || (idx - 1) in d_k end
        get_idx_kerne(k) = [x[1] for x in k]

        kerne = Vector{Tuple{Int, Bool, Vector{Char}}}()
        used_indices = Vector{Int}()

        for idx in 1:(length(word)-1)
            if (word[idx] * word[idx+1]) in doppelte_silbenkerne 
                push!(kerne, (idx, true, [word[idx]]))
                push!(used_indices, idx)
            end
        end
        for (idx, char) in enumerate(word)
            if char in silbenkerne && !is_doppel_kerne(kerne, idx)
                push!(kerne, (idx, false, [word[idx]]))
                push!(used_indices, idx)
            end
        end

        for kern in kerne
            if kern[1] < 2 continue end
            if (kern[1] - 1) in get_idx_kerne(kerne) continue end
            if is_doppel_kerne(kerne, kern[1] - 1) continue end

            stop = false
            for kon in klebrige_konsonanten
                if kern[1] <= length(kon) continue end
                if word[(kern[1]-length(kon)):(kern[1]-1)] == kon
                    prepend!(kern[3], kon)
                    append!(used_indices, (kern[1]-length(kon)):(kern[1]-1))
                    stop = true
                    break
                end
            end
            stop && continue
            pushfirst!(kern[3], word[kern[1] - 1])
            push!(used_indices, kern[1] - 1)
        end

        sort!(kerne, lt=(x,y) -> isless(x[1], y[1]), rev=true)

        add_to_beginning = Vector{Char}()
        for idx in eachindex(word)
            if idx in used_indices continue end
            i = findfirst(x -> x[1] < idx, kerne)
            if isnothing(i)
                push!(add_to_beginning, word[idx])
            else
                push!(kerne[i][3], word[idx])
            end
        end
        prepend!(kerne[end][3], add_to_beginning)

        for (idx, kern) in enumerate(reverse(kerne))
            output *= String(kern[3])
            if idx != length(kerne)
                output *= '-'
            end
        end
        output *= ' '
    end
    return output
end

function main()
    parent_path = dirname(@__DIR__)
    eingabenloc = joinpath(parent_path, "eingaben")
    ausgabenloc = joinpath(parent_path, "ausgabe.txt")
    eachloc = readdir(eingabenloc)

    touch(ausgabenloc)
    io = open(ausgabenloc, "w")

    for loc in eachloc
        lars = lars_silbentrennung(joinpath(eingabenloc, loc))
        eigene = eigene_silbentrennung(joinpath(eingabenloc, loc))
        out = Base.print_to_string((loc, ("Lars Silbentrennung: " * lars, "Eigene Silbentrennung: " * eigene))) * '\n'
        write(io, out)
        print(out)
    end

    close(io)
end

main()

end # module Junioraufgabe2
