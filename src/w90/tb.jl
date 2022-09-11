export read_w90_tbdat, read_w90_wsvec

"""
    read_w90_tbdat(filename::AbstractString)

Read `seedname_tb.dat`.

# Return
- `lattice`: each column is a lattice vector
- `R`: ``\\bm{R}`` vectors on which operators are defined
- `N`: degeneracies of ``\\bm{R}`` vectors
- `H`: Hamiltonian ``\\bm{H}(\\bm{R})``
- `r`: position operator
"""
function read_w90_tbdat(filename::AbstractString)
    @info "Reading $filename"

    io = open(filename)
    header = strip(readline(io))
    println(header)

    # Å unit
    a1 = parse.(Float64, split(strip(readline(io))))
    a2 = parse.(Float64, split(strip(readline(io))))
    a3 = parse.(Float64, split(strip(readline(io))))
    lattice = Mat3{Float64}(hcat(a1, a2, a3))

    n_wann = parse.(Int, strip(readline(io)))
    n_rvecs = parse.(Int, strip(readline(io)))
    # degeneracies of R vecs
    N = zeros(Int, n_rvecs)
    n_col = 15  # 15 numbers per row
    for i in 0:(n_rvecs ÷ n_col - 1)
        s = i * n_col + 1  # start
        e = (i + 1) * n_col  # end
        N[s:e] = parse.(Int, split(strip(readline(io))))
    end
    if (n_rvecs % n_col) > 0
        s = n_rvecs - n_rvecs % n_col + 1 # start
        e = n_rvecs  # end
        N[s:e] = parse.(Int, split(strip(readline(io))))
    end

    R = zeros(Int, 3, n_rvecs)
    H = Array{ComplexF64}(undef, n_wann, n_wann, n_rvecs)
    for ir in 1:n_rvecs
        readline(io)  # empty line
        R[:, ir] = parse.(Int, split(strip(readline(io))))
        for n in 1:n_wann
            for m in 1:n_wann
                line = split(strip(readline(io)))
                @assert m == parse(Int, line[1]) line
                @assert n == parse(Int, line[2]) line
                H[m, n, ir] = parse(Float64, line[3]) + im * parse(Float64, line[4])
            end
        end
    end

    # WF position operator
    r = Array{ComplexF64}(undef, 3, n_wann, n_wann, n_rvecs)
    for ir in 1:n_rvecs
        readline(io)  # empty line
        @assert R[:, ir] == parse.(Int, split(strip(readline(io))))
        for n in 1:n_wann
            for m in 1:n_wann
                line = split(strip(readline(io)))
                @assert m == parse(Int, line[1])
                @assert n == parse(Int, line[2])
                f = parse.(Float64, line[3:8])
                r[1, m, n, ir] = f[1] + im * f[2]
                r[2, m, n, ir] = f[3] + im * f[4]
                r[3, m, n, ir] = f[5] + im * f[6]
            end
        end
    end
    close(io)

    return (; lattice, R, N, H, r)
end

"""
    read_w90_wsvec(filename::AbstractString)

Read `seedname_wsvec.dat`.
"""
function read_w90_wsvec(filename::AbstractString)
    @info "Reading $filename"

    io = open(filename)
    header = strip(readline(io))
    println(header)
    # check `use_ws_distance`
    mdrs = false
    header = split(header)[end]
    if occursin("use_ws_distance", header)
        header = lowercase(split(header, "=")[2])
        if 't' in header
            mdrs = true
        end
    end

    Rmn = Vector{Vector{Int}}()
    Nᵀ = Vector{Int}()
    T = Vector{Matrix{Int}}()

    while !eof(io)
        line = strip(readline(io))
        if length(line) == 0
            continue
        end
        Rx, Ry, Rz, m, n = parse.(Int, split(line))
        push!(Rmn, [Rx, Ry, Rz, m, n])
        n = parse(Int, strip(readline(io)))
        push!(Nᵀ, n)
        t = zeros(Int, 3, n)
        for it in 1:n
            line = strip(readline(io))
            Tx, Ty, Tz = parse.(Int, split(line))
            t[:, it] = [Tx, Ty, Tz]
        end
        push!(T, t)
    end
    close(io)

    n = [i[end] for i in Rmn]
    n_wann = length(unique(n))
    n_rvecs = Int(length(Rmn)//n_wann^2)

    R = zeros(Int, 3, n_rvecs)
    N = zeros(Int, n_rvecs)
    ir = 1
    for rmn in Rmn
        m, n = rmn[4:5]
        if m == 1 && n == 1
            R[:, ir] = rmn[1:3]
            N[ir] = -1  # degeneracy is stored in tb.dat
            ir += 1
        end
    end

    if !mdrs
        return mdrs, (; R)
    end

    # reorder T, Nᵀ
    T1 = Array{Matrix{Int},3}(undef, n_wann, n_wann, n_rvecs)
    N1 = Array{Int,3}(undef, n_wann, n_wann, n_rvecs)
    ir = 1
    for (i, rmn) in enumerate(Rmn)
        m, n = rmn[(end - 1):end]
        T1[m, n, ir] = T[i]
        N1[m, n, ir] = Nᵀ[i]
        if m == n_wann && n == n_wann
            ir += 1
        end
    end

    return mdrs, (; R, T=T1, Nᵀ=N1)
end
