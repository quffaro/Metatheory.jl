using TermInterface

#### Pattern matching
### Matching procedures
# A matcher is a function which takes 3 arguments
# 1. Expression
# 2. Dictionary
# 3. Callback: takes arguments Dictionary × Number of elements matched
#
function matcher(val::Any)
    function literal_matcher(next, data, bindings)
        islist(data) && isequal(car(data), val) ? next(bindings, 1) : nothing
    end
end

function matcher(slot::PatVar)
    function slot_matcher(next, data, bindings)
        !islist(data) && return
        val = get(bindings, slot.name, nothing)
        if val !== nothing
            if isequal(val, car(data))
                return next(bindings, 1)
            end
        else
            if slot.predicate(car(data))
                next(assoc(bindings, slot.name, car(data)), 1)
            end
        end
    end
end

# returns n == offset, 0 if failed
function trymatchexpr(data, value, n)
    if !islist(value)
        return n
    elseif islist(value) && islist(data)
        if !islist(data)
            # didn't fully match
            return nothing
        end

        while isequal(car(value), car(data))
            n += 1
            value = cdr(value)
            data = cdr(data)

            if !islist(value)
                return n
            elseif !islist(data)
                return nothing
            end
        end

        return !islist(value) ? n : nothing
    elseif isequal(value, data)
        return n + 1
    end
end

function matcher(segment::PatSegment)
    function segment_matcher(success, data, bindings)
        val = get(bindings, segment.name, nothing)

        if val !== nothing
            n = trymatchexpr(data, val, 0)
            if n !== nothing
                success(bindings, n)
            end
        else
            res = nothing

            for i = length(data):-1:0
                subexpr = take_n(data, i)

                if segment.predicate(subexpr)
                    res = success(assoc(bindings, segment.name, subexpr), i)
                    if res !== nothing 
                        break
                end
            end
            end

            return res
        end
    end
end

function matcher(term::PatTerm)
    matchers = (matcher(operation(term)), map(matcher, arguments(term))...,)
    function term_matcher(success, data, bindings)

        !islist(data) && return nothing
        !istree(car(data)) && return nothing

        function loop(term, bindings′, matchers′) # Get it to compile faster
            if !islist(matchers′)
                if !islist(term)
                    return success(bindings′, 1)
                end
                return nothing
            end
            car(matchers′)(term, bindings′) do b, n
                loop(drop_n(term, n), b, cdr(matchers′))
            end
        end

        loop(car(data), bindings, matchers) # Try to eat exactly one term
    end
end


function (r::RewriteRule)(x)
    mem = Vector(undef, length(r.patvars))
    if match(r.left, x, mem)
        return instantiate(x, r.right, mem)
    end
    return nothing
end

function (r::EqualityRule)(x)
    mem = Vector(undef, length(r.patvars))
    if match(r.left, x, mem)
        return instantiate(x, r.right, mem)
    end
    return nothing
end

function (r::DynamicRule)(x)
    # print("matching ")
    # display(r)
    # println(" against $x")
    mem = Vector(undef, length(r.patvars))
    if match(r.left, x, mem)
        # println("matched")
        return r.rhs_fun(x, mem, nothing, collect(mem)...)
    end
    # println("failed")
    return nothing
end

# TODO revise
function instantiate(left, pat::PatTerm, mem)
    ar = arguments(pat)
    similarterm(typeof(left), operation(pat), 
        [instantiate(left, ar[i], mem) for i in 1:length(ar)]; exprhead=exprhead(pat))
end

instantiate(left, pat::Any, mem) = pat.val

instantiate(left, pat::Pattern, mem) = error("Unsupported pattern ", pat)

function instantiate(left, pat::PatVar, mem)
    # println(left)
    # println(pat)
    # println(mem)
    mem[pat.idx]
end

