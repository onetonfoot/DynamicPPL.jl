############################################
# Julia 1.2 temporary fix - Julia PR 33303 #
############################################
if VERSION == v"1.2"
    @eval function namedtuple(::Type{NamedTuple{names, T}}, args::Tuple) where {names, T <: Tuple}
        if length(args) != length(names)
            throw(ArgumentError("Wrong number of arguments to named tuple constructor."))
        end
        # Note T(args) might not return something of type T; e.g.
        # Tuple{Type{Float64}}((Float64,)) returns a Tuple{DataType}
        $(Expr(:splatnew, :(NamedTuple{names,T}), :(T(args))))
    end
else
    function namedtuple(::Type{NamedTuple{names, T}}, args::Tuple) where {names, T <: Tuple}
        return NamedTuple{names, T}(args)
    end
end

#####################################################
# Helper functions for vectorize/reconstruct values #
#####################################################

vectorize(d::UnivariateDistribution, r::Real) = [r]
vectorize(d::MultivariateDistribution, r::AbstractVector{<:Real}) = copy(r)
vectorize(d::MatrixDistribution, r::AbstractMatrix{<:Real}) = copy(vec(r))

# NOTE:
# We cannot use reconstruct{T} because val is always Vector{Real} then T will be Real.
# However here we would like the result to be specifric type, e.g. Array{Dual{4,Float64}, 2},
# otherwise we will have error for MatrixDistribution.
# Note this is not the case for MultivariateDistribution so I guess this might be lack of
# support for some types related to matrices (like PDMat).
reconstruct(d::UnivariateDistribution, val::AbstractVector) = val[1]
reconstruct(d::MultivariateDistribution, val::AbstractVector) = copy(val)
function reconstruct(d::MatrixDistribution, val::AbstractVector)
    return reshape(copy(val), size(d))
end
function reconstruct!(r, d::Distribution, val::AbstractVector)
    return reconstruct!(r, d, val)
end
function reconstruct!(r, d::MultivariateDistribution, val::AbstractVector)
    r .= val
    return r
end
function reconstruct(d::Distribution, val::AbstractVector, n::Int)
    return reconstruct(d, val, n)
end
function reconstruct(d::UnivariateDistribution, val::AbstractVector, n::Int)
    return copy(val)
end
function reconstruct(d::MultivariateDistribution, val::AbstractVector, n::Int)
    return copy(reshape(val, size(d)[1], n))
end
function reconstruct(d::MatrixDistribution, val::AbstractVector, n::Int)
    tmp = reshape(val, size(d)[1], size(d)[2], n)
    orig = [tmp[:, :, i] for i in 1:size(tmp, 3)]
    return orig
end
function reconstruct!(r, d::Distribution, val::AbstractVector, n::Int)
    return reconstruct!(r, d, val, n)
end
function reconstruct!(r, d::MultivariateDistribution, val::AbstractVector, n::Int)
    r .= val
    return r
end


# ROBUST INITIALISATIONS
# Uniform rand with range 2; ref: https://mc-stan.org/docs/2_19/reference-manual/initialization.html
randrealuni() = Real(4rand()-2)
randrealuni(args...) = map(Real, 4rand(args...)-2)

const Transformable = Union{TransformDistribution, SimplexDistribution, PDMatDistribution}


#################################
# Single-sample initialisations #
#################################

init(dist::Transformable) = inittrans(dist)
init(dist::Distribution) = rand(dist)

inittrans(dist::UnivariateDistribution) = invlink(dist, randrealuni())
inittrans(dist::MultivariateDistribution) = invlink(dist, randrealuni(size(dist)[1]))
inittrans(dist::MatrixDistribution) = invlink(dist, randrealuni(size(dist)...))


################################
# Multi-sample initialisations #
################################

init(dist::Transformable, n::Int) = inittrans(dist, n)
init(dist::Distribution, n::Int) = rand(dist, n)

inittrans(dist::UnivariateDistribution, n::Int) = invlink(dist, randrealuni(n))
function inittrans(dist::MultivariateDistribution, n::Int)
    return invlink(dist, randrealuni(size(dist)[1], n))
end
function inittrans(dist::MatrixDistribution, n::Int)
    return invlink(dist, [randrealuni(size(dist)...) for _ in 1:n])
end
