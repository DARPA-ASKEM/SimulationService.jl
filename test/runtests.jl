using SimulationService
using AlgebraicPetri, Catlab, JSON, JSON3, JSONTables, CSV, DataFrames, Oxygen, HTTP
using Catlab.CategoricalAlgebra
using Test
using Catlab.CategoricalAlgebra.FinSets
using Bijections
using ModelingToolkit, OrdinaryDiffEq, DifferentialEquations
using OrderedCollections, NamedTupleTools
@info "usings"
logdir = joinpath(@__DIR__, "logs")
mkpath(logdir)

register!() 

m = _seird = AlgebraicPetri.LabelledPetriNet(
    [:S, :E, :I, :R, :D],
    :exp => ([:S, :I] => [:E, :I]),
    :conv => (:E => :I),
    :rec => (:I => :R),
    :death => (:I => :D)
)

# here we switch the order of T4 and T5, but the model is structually identical to above
m2 = _seird2 = AlgebraicPetri.LabelledPetriNet(
    [:S, :E, :I, :R, :D],
    :exp => ([:S, :I] => [:E, :I]),
    :conv => (:E => :I),
    :death => (:I => :D),
    :rec => (:I => :R),
)

m3 = _seird3 = AlgebraicPetri.LabelledPetriNet(
    [:S, :E, :I, :R, :D_],
    :exp => ([:S, :I] => [:E, :I]),
    :conv => (:E => :I),
    :death => (:I => :D_),
    :rec => (:I => :R),
)

j = mj = JSON.json(generate_json_acset(m))
j2 = mj2 = JSON.json(generate_json_acset(m2))

@info """add models to "database" """
bij_id!(b, m)
bij_id!(b, m2)
bij_id!(b, m3)

@info """test that we can access the id of the petrinet"""
req = HTTP.Request("POST", "/petri_id", [], j)
@test parse(Int, String(internalrequest(req).body)) == 1

req = HTTP.Request("POST", "/petri_id", [], JSON.json(generate_json_acset(m2)))
@test parse(Int, String(internalrequest(req).body)) == 2

@info """add ODESystems to "database" """
bij_id!(b2, ODESystem(m))
bij_id!(b2, ODESystem(m2))
bij_id!(b2, ODESystem(m3))

req = HTTP.Request("POST", "/sys_id", [], JSON.json(generate_json_acset(m)))
@test parse(Int, String(internalrequest(req).body)) == 1

@info "solve via POST"
sys = ODESystem(m)
sts = states(sys)
ps = parameters(sys)

u0 = rand(length(sts))
tspan = (0, 100)
p = rand(length(ps))

prob = ODEProblem(sys, u0, tspan, p)
bij_id!(b3, prob)

_args = (; u0, tspan, p)
kws = (; saveat=0.1, abstol=1e-7, reltol=1e-7)
post_body_dict = Dict("args" => OrderedDict(pairs(_args)), "kws" => Dict(pairs(kws)))
post_body = JSON3.write(post_body_dict)

as, ks = parse_args_kws(post_body)
"this is the pattern that i'd like to use to generate endpoints, by simply taking f(args;kws) but parsing the post body back into orderdict and nt"
prob = ODEProblem(sys, values(as)...; ks...)
mnt = merge(as, ks)
rprob = remake(prob; mnt...)

sol = solve(rprob, Tsit5())
@test sol.retcode == ReturnCode.Success
# julia> JSON3.write(sol)
# ERROR: StackOverflowError:

post_sol = oxygen_solve(prob, post_body)
@test post_sol.retcode == ReturnCode.Success
df = DataFrame(post_sol)

req = HTTP.Request("POST", "/solve/1", [], post_body)
resp = internalrequest(req)
jresp = JSON3.read(resp.body)
df2 = DataFrame(jsontable(jresp))
mat1 = Array(df)
mat2 = Array(df2)
@test isapprox(mat1, mat2; rtol=1e-5)

@info "CSV content-type"
req = HTTP.Request("POST", "/solve/1/CSV", [], post_body)
csv_resp = internalrequest(req)
@test csv_resp.status == 200
@test CSV.read(csv_resp.body, DataFrame) == df

fn = joinpath(logdir, "solve_1_post_body.json")
JSON3.write(fn, post_body_dict)
@test isfile(fn)
