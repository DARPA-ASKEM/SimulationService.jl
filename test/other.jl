
"""
my ramblings (to delete)


we also want to store the ODESystems, but they don't have a json serialization. there is `write(fn, sys)`
we can do this and load them on demand, however, parsing the ODESystems is slow, so we want to cache them or just keep them in memory


for the epi models i don't think that keeping the models in memory is so bad, but for something like a discretized PDE, the expressions can be super big, 
but the compilation time is also preventative, so I don't know what we should do in this case

for now, i'm going to have another id->sys bijection. which is a bit clunky for sure 
the general question is what part of model lowering (to a simulatable type) should be stored (should they all be stored ie, Petri, Sys, and Prob)
    
"""

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
