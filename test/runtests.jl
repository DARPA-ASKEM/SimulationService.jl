using SimulationService
using Oxygen, HTTP, AlgebraicPetri, ModelingToolkit, DifferentialEquations, Catlab, JSON, JSON3, JSONTables, CSV, DataFrames
using Catlab.CategoricalAlgebra
using Test
# 180 dependencies successfully precompiled in 718 seconds. 54 already precompiled. We love diffeq dont we

@info "usings"

@get "/hi" SimulationService.hi
@post "/petri" SimulationService.petri
# @post "/seird" SimulationService.seird

_seird = AlgebraicPetri.LabelledPetriNet(
    [:S, :E, :I, :R, :D],
    :exp => ([:S, :I] => [:E, :I]),
    :conv => (:E => :I),
    :rec => (:I => :R),
    :death => (:I => :D)
)

m = _seird
sys = ODESystem(m)
u0 = [0.99, 0.01, 0.0, 0.0, 0.0]
tspan = (0.0, 100.0)
p = [0.1, 0.1, 0.1, 0.1]
# solve_kws = (;saveat=1, abstol=1e-6, reltol=1e-6)
prob = ODEProblem(sys, u0, tspan, p;saveat=1)
sol = solve(prob)
df = DataFrame(sol)
@info "sol"

j = JSON3.read(JSON3.write(generate_json_acset(m)))
m = parse_json_acset(LabelledPetriNet, j)
@test String(internalrequest(HTTP.Request("GET", "/hi")).body) == "hello"

sim = Dict("u0" => u0, "tspan" => tspan, "p" => p)
# post_j = JSON3.write(sim)
# req = HTTP.Request("POST", "/seird", ["Content-Type" => "application/json"], post_j)

petrij = JSON3.write(Dict(["sim"=>sim, "petri"=>j]))
req = HTTP.Request("POST", "/petri", ["Content-Type" => "application/json"], petrij)
r = internalrequest(req)
resp_df = DataFrame(jsontable(JSON3.read(r.body)))
@test df == resp_df
