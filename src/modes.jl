# using NPZ
F = Float32
# base = F.(npzread("" * "modes" * ".npy"))

using PyCall
np = pyimport("numpy")
shapely = pyimport("shapely")
shapely.affinity = pyimport("shapely.affinity")
clip_by_rect = pyimport("shapely.ops").clip_by_rect
OrderedDict = pyimport("collections").OrderedDict
mesh_from_OrderedDict = pyimport("femwell.mesh").mesh_from_OrderedDict

wg_width = 0.5
wg_thickness = 0.22
slab_width = 3
slab_thickness = 0.11
core = shapely.geometry.box(-wg_width / 2, 0, wg_width / 2, wg_thickness)
slab = shapely.geometry.box(slab_width / 2, 0, slab_width / 2, slab_thickness)
env = shapely.affinity.scale(core.buffer(3, resolution=8), xfact=0.5)

polygons = OrderedDict(
    core=core,
    slab=slab,
    box=clip_by_rect(env, -np.inf, -np.inf, np.inf, 0),
    clad=clip_by_rect(env, -np.inf, 0, np.inf, np.inf),
)

resolutions = Dict(
    "core" => Dict("resolution" => 0.03, "distance" => 0.5),
    "slab" => Dict("resolution" => 0.03, "distance" => 0.5),
)

mesh = mesh_from_OrderedDict(
    polygons,
    resolutions,
    default_resolution_max=1,
    filename="mesh.msh",
)

using Gridap
using Gridap.Geometry
using Gridap.Visualization
using Gridap.ReferenceFEs
using GridapGmsh
using GridapMakie, CairoMakie

using Femwell.Maxwell.Waveguide

CairoMakie.inline!(true)

model = GmshDiscreteModel("mesh.msh")
Ω = Triangulation(model)
#fig = plot(Ω)
#fig.axis.aspect=DataAspect()
#wireframe!(Ω, color=:black, linewidth=1)
#display(fig)

labels = get_face_labeling(model)

epsilons = ["core" => 3.5^2, "slab" => 1.44^2, "box" => 1.444^2, "clad" => 1.44^2]
ε(tag) = Dict(get_tag_from_name(labels, u) => v for (u, v) in epsilons)[tag]


#dΩ = Measure(Ω, 1)
τ = CellField(get_face_tag(labels, num_cell_dims(model)), Ω)

modes = calculate_modes(model, ε ∘ τ, λ=1.55, num=1, order=1)
println(n_eff(modes[1]))
# write_mode_to_vtk("mode", modes[2])

plot_mode(modes[1])
#plot_mode(modes[2])

# using Femwell.Maxwell.Waveguide:field
using Gridap
using Gridap.Geometry
using Gridap.TensorValues
using Arpack
fields = [
    ("E_x", VectorValue(1, 0, 0)),
    ("E_y", VectorValue(0, 1, 0)),
    ("E_z", VectorValue(0, 0, 1im)),
]
Ω = get_triangulation(modes[1].E)
p = get_cell_points(Measure(Ω, 1))
Ex, Ey, Ez = [getindex.(collect((E(modes[1]) ⋅ vector)(p)), 1) for (i, (title, vector)) in enumerate(fields)]
p = collect.(getproperty.(getindex.(p.cell_phys_point, 1), :data))
# grid_and_data = to_grid(get_triangulation(Ex), Ex[1])

using NearestNeighbors

kdtree = KDTree(hcat(p...))
lm = 0.1
dx = 0.02
bounds = [[-wg_width / 2 - lm, wg_width / 2 + lm], [-lm, wg_thickness + lm]]
i = [nn(kdtree, [x, y],)[1][1] for x = -wg_width/2-lm:dx:wg_width/2+lm, y = -lm:dx:wg_thickness+lm]
# heatmap(getindex.((Ex,),i))
Ex = getindex.((Ex,), i)
Ey = getindex.((Ey,), i)
Ez = getindex.((Ez,), i)
mode = (; Ex, Ey, Ez, dx, bounds)
dir = ""
using BSON: @save, @load
@save "mode.bson" mode
