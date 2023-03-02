FROM julia:1.8

WORKDIR /sim-service
# Install requirements
COPY Manifest.toml  /sim-service/
COPY Project.toml /sim-service/
RUN julia -e 'using Pkg; Pkg.activate("."); Pkg.instantiate();'

# Install local package
COPY src/ /sim-service/src/
RUN julia -e 'using Pkg; Pkg.activate("."); Pkg.resolve();'
RUN julia -e 'using Pkg; Pkg.activate("."); Pkg.precompile();'
RUN julia -e 'using Pkg; Pkg.activate("."); using SimulationService;'

EXPOSE 8080
CMD [ "julia", "-e", "using Pkg; Pkg.activate(\".\"); using SimulationService; SimulationService.run!();" ]
