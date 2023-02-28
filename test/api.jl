using SimulationService, Oxygen
@info "usings"

register!()
serve()


"""

below this is for messing around with content-type serialization

"""
@get "/" function (req::HTTP.Request)
    plot(1:10, rand(10))
end

function svg_response(sol;kws...)
    # io = IOBuffer()
    # plot(io, sol)
    # show(io, MIME"image/svg+xml"(), plot(sol;kws...))
    HTTP.Response(200, []; body=display(MIME"image/svg+xml"(), plot(sol)))
end

@get "/" function (req::HTTP.Request)
    qps = Oxygen.queryparams(req)
    @info qps
    size = eval(Meta.parse(qps["size"]))
    # show(MIME"image/svg+xml"(), plot(sol))
    # HTTP.Response(200, ["Content-Type" => "image/svg+xml"]; body=display(MIME"image/svg+xml"(), plot(sol)))
    io = IOBuffer()
    show(io, MIME"image/svg+xml"(), plot(sol;size))
    HTTP.Response(200, ["Content-Type"=>MIME"image/svg+xml"()]; body=take!(io))
end

# serve()
