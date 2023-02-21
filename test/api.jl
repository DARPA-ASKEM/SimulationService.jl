using SimulationService, Oxygen
@info "usings"

@get "/hi" SimulationService.hi
@post "/petri" SimulationService.petri

serve()
