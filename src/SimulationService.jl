module SimulationService

using Oxygen, HTTP, AlgebraicPetri, ModelingToolkit, DifferentialEquations, Catlab, JSON, JSON3, JSONTables, CSV, DataFrames
using Catlab.CategoricalAlgebra

# _seird = AlgebraicPetri.LabelledPetriNet(
#     [:S, :E, :I, :R, :D],
#     :exp => ([:S, :I] => [:E, :I]),
#     :conv => (:E => :I),
#     :rec => (:I => :R),
#     :death => (:I => :D)
# )

# _seirhd = AlgebraicPetri.LabelledPetriNet(
#     [:S, :E, :I, :R, :H, :D],
#     :exp => ([:S, :I] => [:E, :I]),
#     :conv => (:E => :I),
#     :rec => (:I => :R),
#     :hosp => (:I => :H),
#     :death => (:H => :D)
# )

# _sirhd = AlgebraicPetri.LabelledPetriNet(
#     [:S, :I, :R, :H, :D],
#     :exp => ([:S, :I] => [:I, :I]),
#     :rec => (:I => :R),
#     :hosp => (:I => :H),
#     :death => (:H => :D)
# )

# MODELS = Dict(
#     "seird" => _seird,
#     "seirhd" => _seirhd,
#     "sirhd" => _sirhd
# )

# @get "/hi" 
function hi(req::HTTP.Request)
    "hello"
end

# @post "/petri" 
function petri(req::HTTP.Request)
    j = Oxygen.json(req)
    jpn = j["petri"]
    sim = j["sim"]
    m = parse_json_acset(LabelledPetriNet, jpn)
    sys = ODESystem(m)
    prob = ODEProblem(sys, collect(sim["u0"]), collect(sim["tspan"]), collect(sim["p"]); saveat=1) # TODO: fix saveat
    sol = solve(prob)
    df = DataFrame(sol)
    JSON3.write(JSONTables.arraytable(df))
end

# @post "/seird" 
# function seird(req::HTTP.Request)
#     @info "hi"
#     j = Oxygen.json(req)
#     @info j
#     m = MODELS["seird"]
#     sys = ODESystem(m)
#     # solve_kws = j["solve_kws"] # todo get this into a namedtuple that can be passed to solve/odeprob, ignoring for now
#     # @info solve_kws
#     prob = ODEProblem(sys, collect(j["u0"]), collect(j["tspan"]), collect(j["p"]); saveat=1)
#     sol = solve(prob)
#     df = DataFrame(sol)
#     JSON3.write(JSONTables.arraytable(df))
# end


end # module SimulationService
