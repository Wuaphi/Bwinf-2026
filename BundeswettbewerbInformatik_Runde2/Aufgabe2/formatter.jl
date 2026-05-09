function parse_route(s::String)
    # r"\[(\d+),\s*(\d+)\]" looks for these thingies: "[]" containing two numbers separated by a comma
    pairs = [ (parse(Int, m[1]), parse(Int, m[2])) for m in eachmatch(r"\[(\d+),\s*(\d+)\]", s) ]
    
    # r"size:\s*([\d.]+)" looks for "size:", optional spaces, and captures the decimal number
    size_match = match(r"size:\s*([\d.]+)", s)
    route_size = isnothing(size_match) ? NaN : parse(Float64, size_match[1])
    
    return pairs, route_size
end


function translate(inp :: Vector{String}, old :: Vector{String})
	out = ""

	min_pos = findfirst(
		x -> occursin("So hat der beste Algorithmus ein Minimum von", x),
		old
	)
	num = filter(isdigit, old[min_pos])
	out *= num
	out *= "\n"

	out *= inp[1]
	out *= "\n"

	m = Dict{Tuple{Int, Int}, String}()
	for i in inp[3:end]
		s = split(i)
		t = (parse(Int, s[2]), parse(Int, s[3]))
		m[t] = s[1]
	end

	for (idx, i) in enumerate(old[min_pos+2:end])
		
		if !occursin("Route", i)
			continue
		end

		p, s = parse_route(i)
		
		out *= string(ceil(Int, s)) * "\n"
		out *= "$(p[1][1]) $(p[1][2])\n"

        ids = [get(m, node, "ERROR") for node in p[1:end-1]]
        
        
        out *= join(ids, " ")
   
        if idx < length(old) - min_pos - 1
            out *= "\n"
        end
    end

	return out
end

function main() 
	a = "eingaben"
	b = "ausgaben"
	c = "ausgaben_formatted"

	files = readdir(a)

	for f in files 
		inp = readlines(joinpath(a, f))
		old = readlines(joinpath(b, f))
		out = translate(inp, old)
		write(joinpath(c, f), out)
	end

end

main()