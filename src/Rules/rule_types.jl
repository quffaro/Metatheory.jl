# TODO place this doc 
# """
# Type assertions are supported in the left hand of rules
# to match and access literal values both when using classic
# rewriting and EGraph based rewriting.
# To use a type assertion pattern, add `::T` after
# a pattern variable in the `left_hand` of a rule.
# """

# TODO HASH CACHING!

using Parameters

import Base.==

abstract type Rule end
# Must override
==(a::Rule, b::Rule) = false


abstract type SymbolicRule <: Rule end

"""
Rules defined as `left_hand => right_hand` are
called *symbolic rewrite* rules. Application of a *rewrite* Rule
is a replacement of the `left_hand` pattern with
the `right_hand` substitution, with the correct instantiation
of pattern variables. Function call symbols are not treated as pattern
variables, all other identifiers are treated as pattern variables.
Literals such as `5, :e, "hello"` are not treated as pattern
variables.


```julia
Rule(:(a * b => b * a))
```
"""
struct RewriteRule <: SymbolicRule 
    left::Pattern
    right::Pattern
    patvars::Vector{Symbol}
    hash::Ref{UInt}
    function RewriteRule(l,r)
        pvars = patvars(l) ∪ patvars(r)
        # sort!(pvars)
        setindex!(l, pvars)
        setindex!(r, pvars)
        new(l,r,pvars, Ref{UInt}(0))
    end
end

function Base.hash(t::RewriteRule, salt::UInt)
    !iszero(salt) && return hash(hash(t, zero(UInt)), salt)
    h = t.hash[]
    !iszero(h) && return h
    h′ = hash(t.left, hash(t.right, hash(t.patvars, salt)))
    t.hash[] = h′
    return h′
end



# =============================================================================


abstract type BidirRule <: SymbolicRule end

"""
This type of *anti*-rules is used for checking contradictions in the EGraph
backend. If two terms, corresponding to the left and right hand side of an
*anti-rule* are found in an [`EGraph`], saturation is halted immediately. 
"""
struct UnequalRule <: BidirRule 
    left::Pattern
    right::Pattern
    patvars::Vector{Symbol}
    hash::Ref{UInt}
    function UnequalRule(l,r)
        pvars = patvars(l) ∪ patvars(r)
        # sort!(pvars)
        setindex!(l, pvars)
        setindex!(r, pvars)
        new(l,r,pvars, Ref{UInt}(0))
    end
end

function Base.hash(t::UnequalRule, salt::UInt)
    !iszero(salt) && return hash(hash(t, zero(UInt)), salt)
    h = t.hash[]
    !iszero(h) && return h
    h′ = hash(t.left, hash(t.right, hash(t.patvars, salt)))
    t.hash[] = h′
    return h′
end


"""
```julia
Rule(:(a * b == b * a))
```
"""
struct EqualityRule <: BidirRule 
    left::Pattern
    right::Pattern
    patvars::Vector{Symbol}
    hash::Ref{UInt}
    function EqualityRule(l,r)
        pvars = patvars(l) ∪ patvars(r)
        # sort!(pvars)
        setindex!(l, pvars)
        setindex!(r, pvars)
        new(l,r,pvars, Ref{UInt}(0))
    end
end

function Base.hash(t::EqualityRule, salt::UInt)
    !iszero(salt) && return hash(hash(t, zero(UInt)), salt)
    h = t.hash[]
    !iszero(h) && return h
    h′ = hash(t.left, hash(t.right, hash(t.patvars, salt)))
    t.hash[] = h′
    return h′
end

"""
Rules defined as `left_hand |> right_hand` are
called `dynamic` rules. Dynamic rules behave like anonymous functions.
Instead of a symbolic substitution, the right hand of
a dynamic `|>` rule is evaluated during rewriting:
matched values are bound to pattern variables as in a
regular function call. This allows for dynamic computation
of right hand sides.

Dynamic rule
```julia
Rule(:(a::Number * b::Number |> a*b))
```
"""
struct DynamicRule <: Rule 
    left::Pattern
    right::Any
    patvars::Vector{Symbol} # useful set of pattern variables
    hash::Ref{UInt}
    function DynamicRule(l, r) 
        pvars = patvars(l)
        # sort!(pvars)
        setindex!(l, pvars)
        new(l, r, pvars, Ref{UInt}(0))
    end
end

function Base.hash(t::DynamicRule, salt::UInt)
    !iszero(salt) && return hash(hash(t, zero(UInt)), salt)
    h = t.hash[]
    !iszero(h) && return h
    h′ = hash(t.left, hash(t.right, hash(t.patvars, salt)))
    t.hash[] = h′
    return h′
end