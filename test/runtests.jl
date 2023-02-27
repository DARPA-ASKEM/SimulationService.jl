using SimulationService
using AlgebraicPetri, Catlab, JSON, JSON3, JSONTables, CSV, DataFrames, Oxygen, HTTP
using Catlab.CategoricalAlgebra
using Test
using Catlab.CategoricalAlgebra.FinSets
using Bijections
using ModelingToolkit, OrdinaryDiffEq, DifferentialEquations
using OrderedCollections, NamedTupleTools
@info "usings"

_seird = AlgebraicPetri.LabelledPetriNet(
    [:S, :E, :I, :R, :D],
    :exp => ([:S, :I] => [:E, :I]),
    :conv => (:E => :I),
    :rec => (:I => :R),
    :death => (:I => :D)
)
# here we switch the order of T4 and T5, but the model is structually identical to above
_seird2 = AlgebraicPetri.LabelledPetriNet(
    [:S, :E, :I, :R, :D],
    :exp => ([:S, :I] => [:E, :I]),
    :conv => (:E => :I),
    :death => (:I => :D),
    :rec => (:I => :R),
)

_seird3 = AlgebraicPetri.LabelledPetriNet(
    [:S, :E, :I, :R, :D_],
    :exp => ([:S, :I] => [:E, :I]),
    :conv => (:E => :I),
    :death => (:I => :D_),
    :rec => (:I => :R),
)

m = _seird
m2 = _seird2
m3 = _seird3
# mj = JSON3.write(generate_json_acset(m))
mj = JSON.json(generate_json_acset(m))
mj2 = JSON.json(generate_json_acset(m2))
@test hash(mj) != hash(mj2)
# petri net isomorphism? 
# what is a constant-time way to getindex model_dict[petri_net] but up to isomorphism 
# maybe we should just ignore this for now and just use the hash of the JSON string, since 
# if we canonicalized, we could store petri nets and labels separately

@test CategoricalAlgebra.is_isomorphic(m, m2)
@test !CategoricalAlgebra.is_isomorphic(m, m3) # nice so isomorphism needs to preserve labels


p = PetriNet(m)
p2 = PetriNet(m2)
@test hash(p) != hash(p2)
isos = isomorphisms(m, m2)
iso = only(isos)

b[1] = m
b(m)

bij_id!(b, m)
bij_id!(b, m2)
bij_id!(b, m3)
j = JSON.json(generate_json_acset(m))
register!()
req = HTTP.Request("POST", "/petri_id", [], j)
@test parse(Int, String(internalrequest(req).body)) == 1

req = HTTP.Request("POST", "/petri_id", [], JSON.json(generate_json_acset(m2)))
@test parse(Int, String(internalrequest(req).body)) == 2

"""
we also want to store the ODESystems, but they don't have a json serialization. there is `write(fn, sys)`
we can do this and load them on demand, however, parsing the ODESystems is slow, so we want to cache them or just keep them in memory


for the epi models i don't think that keeping the models in memory is so bad, but for something like a discretized PDE, the expressions can be super big, 
but the compilation time is also preventative, so I don't know what we should do in this case

for now, i'm going to have another id->sys bijection. which is a bit clunky for sure 
the general question is what part of model lowering (to a simulatable type) should be stored (should they all be stored ie, Petri, Sys, and Prob)
    
"""
b2[1] = ODESystem(m)


# @benchmark ODESystem(m) # 724.500 μs (4416 allocations: 221.62 KiB)
bij_id!(b2, ODESystem(m))
bij_id!(b2, ODESystem(m2))
bij_id!(b2, ODESystem(m3))


req = HTTP.Request("POST", "/sys_id", [], JSON.json(generate_json_acset(m)))
@test parse(Int, String(internalrequest(req).body)) == 1
"""
it would be annoying to try and post ODESystem so for now the only model entry point is the LabelledPetriNet

    ideally we store the problems too so that we can just remake instead of problem instantiation
"""
sys = ODESystem(m)
sts = states(sys)
p = rand(length(parameters(sys)))
tspan = (0, 100)
u0 = rand(length(sts))
_args = (; u0, tspan, p)
kws = (; saveat=1, abstol=1e-7, reltol=1e-7)

jargs = JSON3.read(JSON3.write(_args))
jargsreal = keys(jargs) .=> collect.(values(jargs))
jkws = JSON3.read(JSON.json(kws))

@test namedtuple(JSON3.read(JSON3.write(kws))) == kws

j = post_body = JSON3.write(Dict("args" => jargs, "kws" => jkws))

as, ks = parse_args_kws(post_body)
"this is the pattern that i'd like to use to generate endpoints, by simply taking f(args;kws) but parsing the post body back into orderdict and nt"
prob = ODEProblem(sys, values(as)...; ks...)
b3[1] = prob
mnt = merge(as, ks)
rprob = remake(prob; mnt...)

"""
# what do we do about solve_kws and alg specifically
it feels like it is a bit unreasonable to expect all the flexibility of DiffEq in the rest api. 
its the same as the serialization problem. how should we serialize alg types? 
we could stringify and parse, but a naive test shows

julia> Tsit5()
Tsit5(stage_limiter! = trivial_limiter!, step_limiter! = trivial_limiter!, thread = static(false))

and eval(parse(s)) gives `static not defined`, so I see lots of annoying problems with this approach

for now i am punting on the issue and letting DiffEq choose the solver 
"""
sol = solve(rprob, Tsit5())
@test sol.retcode == ReturnCode.Success

x = oxygen_solve(prob, j)
@test x.retcode == ReturnCode.Success
# julia> JSON3.write(x)
# ERROR: StackOverflowError:

req = HTTP.Request("POST", "/solve/1", [], j)

"these are only "
df = DataFrame(x)
df2 = DataFrame(jsontable(JSON3.read(internalrequest(req).body)))
mat1 = Array(df)
mat2 = Array(df2)
@test isapprox(mat1, mat2; rtol=1e-10)

req = HTTP.Request("POST", "/solve/1/CSV", [], j)
@test internalrequest(req).status == 200
