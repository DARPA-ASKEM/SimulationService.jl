@time_imports using SimulationService, AlgebraicPetri, Catlab, JSON, JSON3, JSONTables, CSV, DataFrames, Oxygen, HTTP, Catlab.CategoricalAlgebra, Test, Catlab.CategoricalAlgebra.FinSets, Bijections, ModelingToolkit, OrdinaryDiffEq, DifferentialEquations, OrderedCollections, NamedTupleTools
using SimulationService
using AlgebraicPetri, Catlab, JSON, JSON3, JSONTables, CSV, DataFrames, Oxygen, HTTP
using Catlab.CategoricalAlgebra
using Test
using Catlab.CategoricalAlgebra.FinSets
using Bijections
using ModelingToolkit, OrdinaryDiffEq, DifferentialEquations
using OrderedCollections, NamedTupleTools
using JSONBase
using EasyModelAnalysis

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
write(joinpath(logdir, "petri.json"), j)
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

defs = ModelingToolkit.defaults(sys)

new_defs = [states(sys) .=> rand(length(states(sys))); parameters(sys) .=> rand(length(parameters(sys)))]
# remake(sys; defaults=new_defs)
prob

prob2 = remake(prob; u0=new_defs, p=new_defs)
prob2 = remake(prob; u0=new_defs, p=new_defs)

# named_solve # example
# options 
"tspan" => [0, 100]
"defaults" # allows for a partial map

# named_post supports tspan, defaults, and kws
named_post = Dict("u0" => Dict(["S" => 1]), "p"=>Dict("exp" => 3), "tspan" => [0, 100], "kws" => Dict(["saveat" => 0.1, "abstol" => 1e-7, "reltol" => 1e-7]))
named_j = JSONBase.json(named_post)
write(joinpath(logdir, "named_post.json"), named_j)

new_u0 = named_json_to_defaults_map(named_post["u0"], states(sys))
new_p = named_json_to_defaults_map(named_post["p"], parameters(sys))
@test eltype(first.(collect(new_u0))) <: Symbolics.Symbolic
prob2 = named_remake(prob, named_post)
# (; S, E, exp) = prob.f.sys
# S = @nonamespace(S)
@variables t S(t) E(t)
@parameters exp

@test prob[S] != new_u0[S]
@test prob2[S] == new_u0[S]

# just a reminder that setindex and getindex on prob works with Symbolics
# although remake seems more effective here
# [prob[k] = v for (k, v) in new_defs]

# register!()

named_sol = solve(prob2)
req = HTTP.Request("POST", "/named_solve/1", [], named_j)
resp = internalrequest(req)
named_resp_df = DataFrame(jsontable(resp.body))
@test DataFrame(named_sol) == named_resp_df


# @parameters S
# @variables t S(t)
# D = Differential(t)
# [D(S) ~ -S*S]

# * solve
# * get_uncertainty_forecast
# * get_sensitivity
# * datafit
# * bayesian_datafit

get_uncertainty_forecast(prob, sym, t, uncertainp, samples)
get_sensitivity(prob, t, x, pbounds; samples = 1000)

""
macro wrap_to_endpoint(f)
    return quote
        function $(f)(args...; kws...)
            return $(f)(args...; kws...)
        end
    end
end

# swaggermarkdown.jl
# add the curl commands
# add a petri-net to the database
# doc the endpoints for swagger
# use split p and u0 instead of defaults for named_solve
# wrap datafit/bayesian datafit to endpoints
register!()
serve()

# run this in another terminal
cmd = `
curl --location --request POST 'localhost:8080/petri_id/' \
--header 'Content-Type: application/json' \
--data-binary '@data/petri_post.json'
`

cmd = `
curl --location --request POST 'localhost:8080/solve/1' \
--header 'Content-Type: application/json' \
--data-binary '@data/solve_1_post_body.json'
`

cmd = `
curl --location --request POST 'localhost:8080/named_solve/1' \
--header 'Content-Type: application/json' \
--data-binary '@data/named_solve.json'
`

cmd = `
curl --location --request POST 'localhost:8080/model/' \
--header 'Content-Type: application/json' \
--data-binary '@data/petri_post.json'
`



s = read(cmd, String)