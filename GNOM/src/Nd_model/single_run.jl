# You are running a single run
# that will create DNd, εNd, and p.

# This lines sets up the model (and `F`) only once,
# so that you rerunning this file will not repeat the entire model setup
!isdefined(Main, :F) && include("model_setup.jl")

# This should create a new run name every time you run the file
# And add an empty runXXX file to the single_runs folder

allsingleruns_path = joinpath(output_path, "single_runs")
mkpath(output_path)
mkpath(allsingleruns_path)
# Check previous runs and get new run number
run_num = let
    previous_run_nums = [parse(Int, match(r"run(\d+)", f).captures[1]) for f in readdir(allsingleruns_path) if (contains(f, "run") && isdir(joinpath(allsingleruns_path, f)))]
    run_num = 1
    while run_num ∈ previous_run_nums
        run_num += 1
    end
    run_num
end
@info "This is run $run_num"
lastcommit = "single" # misnomer to call this lastcommit but simpler
archive_path = joinpath(allsingleruns_path, "run$run_num")
mkpath(archive_path)
reload = false # prevents loading other runs
use_GLMakie = true # Set to true for interactive mode if plotting with Makie later


# Chose your parameter values here. Optimized parameters
# — as published in Pasquier, Hines, et al. (2021) —
# are shown in comment (leave them there
# if you want to refer back to them)
p = Params(
    α_a = 2.1, # 6.79 "Curvature of Nd release enhancement parabola"
    α_c = -16.33per10000, # -12.7per10000 "Center of Nd release enhancement parabola"
    α_GRL = 4.08, # 1.57 "Greenland Nd release enhancement"
    σ_ε = 0.399per10000, # 0.379per10000 "Per-pixel variance (std) of εNd"
    c_river = 193.57pM, # 376.0pM "River effective [Nd]"
    c_gw = 103.071pM, # 109.0pM "Surface groundwater effective [Nd]"
    σ_hydro = 0.0Mmol/yr, # 0.792Mmol/yr "Hydrothermal source magnitude"
    ε_hydro = 10.0per10000, # 10.9per10000 "Hydrothermal source εNd"
    ϕ_0 = 34.042pmol/cm^2/yr, # 83.7pmol/cm^2/yr "Sedimentary flux at surface"
    ϕ_∞ = 4.15pmol/cm^2/yr, # 1.11pmol/cm^2/yr "Sedimentary flux at infinite depth"
    z_0 = 100.215m, # 170.0m  "Sedimentary flux depth attenuation"
    ε_EAsia_dust = -11.07per10000, # -7.6per10000 "EAsia dust εNd"
    ε_NEAf_dust = -12.75per10000, # -13.7per10000 "NEAf dust εNd"
    ε_NWAf_dust = -11.595per10000, # -12.3per10000 "NWAf dust εNd"
    ε_NAm_dust = -4.20per10000, # -4.25per10000 "NAm dust εNd"
    ε_SAf_dust = -19.0per10000, # -21.6per10000 "SAf dust εNd"
    ε_SAm_dust = -5.733per10000, # -3.15per10000 "SAm dust εNd"
    ε_MECA_dust = -1.95per10000, # 0.119per10000 "MECA dust εNd"
    ε_Aus_dust = -2.15per10000, # -4.03per10000 "Aus dust εNd"
    ε_Sahel_dust = -9.65per10000, # -11.9per10000 "Sahel dust εNd"
    β_EAsia_dust = 3.49per100, # 23.0per100 "EAsia dust Nd solubility"
    β_NEAf_dust = 0.44per100, # 23.3per100 "NEAf dust Nd solubility"
    β_NWAf_dust = 4.43per100, # 3.17per100 "NWAf dust Nd solubility"
    β_NAm_dust = 3.59per100, # 82.8per100 "NAm dust Nd solubility"
    β_SAf_dust = 3.85per100, # 38.5per100 "SAf dust Nd solubility"
    β_SAm_dust = 1.76per100, # 2.52per100 "SAm dust Nd solubility"
    β_MECA_dust = 0.21per100, # 14.7per100 "MECA dust Nd solubility"
    β_Aus_dust = 3.57per100, # 11.6per100 "Aus dust Nd solubility"
    β_Sahel_dust = 0.95per100, # 2.95per100 "Sahel dust Nd solubility"
    ε_volc = 6.94per10000, # 13.1per10000 "Volcanic ash εNd"
    β_volc = 4.42per100, # 76.0per100 "Volcanic ash Nd solubility"
    K_prec = 0.0002/(mol/m^3), # 0.00576/(mol/m^3) "Precipitation reaction constant"
    f_prec = 0.0, # 0.124 "Fraction of non-buried precipitated Nd"
    w₀_prec = 0.7km/yr, # 0.7km/yr "Settling velocity of precipitated Nd"
    K_POC = 3.0/(mol/m^3), # 0.524/(mol/m^3) "POC-scavenging reaction constant"
    f_POC = 0.0, # 0.312 "Fraction of non-buried POC-scavenged Nd"
    w₀_POC = 40.0m/d, # 40.0m/d "Settling velocity of POC-scavenged Nd"
    K_bSi = 10.0/(mol/m^3), # 2.56/(mol/m^3) "bSi-scavenging reaction constant"
    f_bSi = 0.0, # 0.784 "Fraction of non-buried bSi-scavenged Nd"
    w₀_bSi = 714.069m/d, # 714.0m/d "Settling velocity of bSi-scavenged Nd"
    K_dust = 0.001/(g/m^3), # 1.7/(g/m^3) "Dust-scavenging reaction constant"
    f_dust = 0.0, # 0.0861 "Fraction of non-buried dust-scavenged Nd"
    w₀_dust = 1.0km/yr, # 1.0km/yr "Settling velocity of dust-scavenged Nd"
)

tp_opt = AIBECS.table(p)# table of parameters
# "opt" is a misnomer but it is simpler for plotting scripts

# Save model parameters table and headcommit for safekeeping
jldsave(joinpath(archive_path, "model$(headcommit)_single_run$(run_num)_$(circname).jld2"); headcommit, tp_opt)

# Set the problem with the parameters above
prob = SteadyStateProblem(F, x, p)

# solve the system
sol = solve(prob, CTKAlg(), preprint="Nd & εNd solve ", τstop=ustrip(s, 1e3Myr)).u

# unpack nominal isotopes
DNd, DRNd = unpack_tracers(sol, grd)

# compute εNd
εNd = ε.(DRNd ./ DNd)

# For plotting, you can either
# follow the plotting scripts from the GNOM repository and use Makie
# or use Plots.jl (not a dependency of GNOM)
# I would recommend installing Plots.jl in your default environment anyway,
# so that it can be called even from inside the GNOM environment.
# You can then use the Plots.jl recipes exported by AIBECS, e.g.,
#
# julia> plotzonalaverage(εNd .|> per10000, grd, mask=ATL)

# To help manually adjust parameters, below is a little loop
# to check how much Nd each scavenging particle type removes
println("Scavenging removal:")
for t in instances(ScavenginParticle)
    println("- $(string(t)[2:end]): ", ∫dV(T_D(t, p) * 1/s * DNd * mol/m^3, grd) |> Mmol/yr)
end