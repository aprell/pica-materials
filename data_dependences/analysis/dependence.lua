package.path = "../../utils/?.lua;" .. package.path

local Set = require "set"
local fun = require "fun"

local unpack = unpack or table.unpack

local Dependence = {}

function Dependence.analyze(a, b)
    assert(#a.subscripts == #b.subscripts)

    local subscripts = fun.map2(fun.pair, a.subscripts, b.subscripts)

    local variables = fun.map(function (pair)
        return Set(pair[1]:variables()) + Set(pair[2]:variables())
    end, subscripts)

    result = {}

    for dim = 1, #subscripts do
        local class
        if #variables[dim] == 0 then class = "ZIV"
        elseif #variables[dim] == 1 then class = "SIV"
        else class = "MIV" end

        local coupled = false
        for other_dim = 1, #subscripts do
            if other_dim ~= dim then
                if #(variables[other_dim] * variables[dim]) > 0 then
                    coupled = true
                    break
                end
            end
        end

        result[#result+1] = {
            subscript = {a.subscripts[dim], b.subscripts[dim]},
            variables = variables[dim],
            class = class,
            coupled = coupled
        }
    end

    return result
end

local function is_int(n)
    return n == math.floor(n)
end


local function ZIV_test(a, b)
    return a[1] - b[1] == 0
end

local function SIV_test(a, b)

    --[[

    +----------------------------------------------------+
    | Distinguish between strong and weak SIV subscripts |
    +----------------------------------------------------+

    A strong SIV subscript has the form

        [a * i + c_1] and [a * i' + c_2],

    that is, the two occurrences of the index variable share the same
    coefficient. There exists a dependence iff a * i + c_1 = a * i' + c_2, or
    i' - i = (c_1 - c_2) / a is an integer and |i' - i| <= U - L, where U and L
    are the upper and lower bounds of the loop.

    A weak SIV subscript has the form

        [a_1 * i + c_1] and [a_2 * i' + c_2],

    where the coefficients have different values. Again, there exists a
    dependence iff a_1 * i + c_1 = a_2 * i' + c_2. It makes sense to consider a
    few special cases:

    If a_1 = 0, the dependence equation reduces to i' = (c_1 - c_2) / a_2.
    Likewise, if a_2 = 0, the dependence equation becomes i = (c_2 - c_1) /
    a_1. What is left to check is whether the resulting value is an integer
    within the loop bounds.

    Another special case is a_1 = -a_2, resulting in the dependence equation i'
    + i = (c_1 - c_2) / a_2. Since i and i' must be integers (within the loop
    bounds), we can prove independence if (c_1 - c_2) / a_2 is not an integer.

    --]]

    local coeffs = fun.map(unpack, {a:coefficients(), b:coefficients()})
    assert(#coeffs == 2)

    local consts = {a:constant(), b:constant()}
    assert(#consts == 2)

    if coeffs[1] == coeffs[2] then
        -- Strong SIV subscript
        -- d is the dependence distance
        local d = (consts[1] - consts[2]) / coeffs[1]
        return is_int(d)
    else -- Weak SIV subscript
        if coeffs[1] == 0 then
            -- Weak-zero SIV subscript
            assert(coeffs[2] ~= 0)
            return is_int((consts[1] - consts[2]) / coeffs[2])
        elseif coeffs[2] == 0 then
            -- Weak-zero SIV subscript
            assert(coeffs[1] ~= 0)
            return is_int((consts[2] - consts[1]) / coeffs[1])
        elseif coeffs[1] == -coeffs[2] then
            -- Weak-crossing SIV subscript
            return is_int((consts[1] - consts[2]) / coeffs[2])
        else -- SIV test for handling the general case (unimplemented)
            return true
        end
    end
end

local function gcd(a, b)
    if b == 0 then return a else return gcd(b, a % b) end
end

local function MIV_test(a, b)
    -- Note: fun.map(unpack, {...}) doesn't work here
    local coeffs = {unpack(a:coefficients()), unpack(b:coefficients())}
    local gcd_coeffs = fun.fold(gcd, coeffs[1], fun.map(math.abs, coeffs))
    local const = b:constant() - a:constant()
    return is_int(const / gcd_coeffs)
end

function Dependence.test(analysis)
    for _, v in ipairs(analysis) do
        if v.class == "ZIV" then
            assert(not v.coupled)
            if ZIV_test(unpack(v.subscript)) == false then
                -- No dependence possible
                return false
            end
        elseif v.class == "SIV" then
            if SIV_test(unpack(v.subscript)) == false then
                -- No dependence possible
                return false
            end
        else
            assert(v.class == "MIV")
            if MIV_test(unpack(v.subscript)) == false then
                -- No dependence possible
                return false
            end
        end
    end

    return true
end

return Dependence
