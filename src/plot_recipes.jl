function plotfield!(g, u::AbstractArray, ;
    field=:Ex,
    geometry=nothing,
    source_instances=[],
    monitor_instances=[],
    umax=maximum(abs, u),
    bipolar=!all(u .>= 0),
    title="",
    elevation=nothing,
    azimuth=nothing,
    t=0,
    # width=600, height=400,
    kw...)
    t = round(t; digits=2)
    title = "$title\n t = $t (figure includes PML layers)"

    # colormap = [(:blue, 1), (:red, 1)]
    # colormap = :seismic
    colormap = bipolar ? :seismic : [(:white, 0), (:orange, 1)]
    colorrange = bipolar ? (-1, 1) .* umax : (0, 1)
    algorithm = bipolar ? :absorption : :mip
    # if bipolar
    #     u = (u .+ 1) ./ 2
    # end
    d = ndims(u)
    if d == 3
        umax /= 3
    end
    "plot field"
    if d == 3
        ax, v = volume(g[1, 1], u; axis=(; kw..., type=Axis3, title,), algorithm, colormap, colorrange,)
        !isnothing(elevation) && (ax.elevation[] = elevation)
        !isnothing(azimuth) && (ax.azimuth[] = azimuth)
    else
        ax, v = heatmap(g[1, 1], u; axis=(; kw..., title,), colormap, colorrange,)
    end
    Colorbar(g[1, 2], v, label="$field")

    if !isnothing(geometry)
        "plot geometry"
        a, b = extrema(geometry)
        geometry = (geometry .- a) / (b - a)
        if d == 3
            volume!(g[1, 1], geometry, colormap=[(:white, 0), (:gray, 0.2)], colorrange=extrema(geometry))
        else
            heatmap!(g[1, 1], geometry, colormap=[(:white, 0), (:gray, 0.2)], colorrange=extrema(geometry))
        end
    end

    "plot monitors"
    if !isempty(monitor_instances)
        a = zeros(size(u))
        for (i, m) = enumerate(monitor_instances)
            # if isa(m,Ortho)
            try

                a[m.fi[field]...] .= 1
                text = isempty(m.label) ? "m$i" : m.label
                text!(g[1, 1], m.c..., ; text, align=(:center, :center))
            catch
            end
        end
        if d == 3
            volume!(g[1, 1], a, colormap=[(:white, 0), (:teal, 0.2)])#, colorrange=(ϵ1, ϵ2))
        else
            heatmap!(g[1, 1], a, colormap=[(:white, 0), (:teal, 0.2)])#, colorrange=(ϵ1, ϵ2))
            # # save("temp/$t.png", f)
        end
    end

    "plot sources"
    for (i, s) = enumerate(source_instances)
        # volume!(g, s._g[field], colormap=[(:white, 0), (:yellow, 0.2)])
        if d == 3
            volume!(g[1, 1], first(values(s._g)) |> real, colormap=[(:white, 0), (:yellow, 0.2)])
        else
            heatmap!(g[1, 1], first(values(s._g)) |> real, colormap=[(:white, 0), (:yellow, 0.2)])
        end
        text = isempty(s.label) ? "s$i" : s.label
        text!(g[1, 1], s.c..., ; text, align=(:center, :center))
    end
    # # save("temp/$t.png", f)
end
# rotate_cam!(ax.scene, (45, 0, 0))

function recordsim(fn, u, y=nothing;
    dt, geometry=nothing,
    field=:Ex,
    source_instances=[],
    monitor_instances=[],
    rel_lims=0.2,
    umax=maximum(abs, u[round(Int, length(u) / 2)]) * rel_lims,
    bipolar=true,
    elevation=nothing,
    azimuth=nothing,
    labels=[],
    axis1=(;),
    axis2=(;),
    playback=1,
    frameat=1 / 12,
    framerate=playback / frameat,)
    axis1 = merge((;
            title="field",), axis1)

    # geometry = pop!(axis1, :geometry)
    # source_instances = pop!(axis1, :source_instances)
    # monitor_instances = pop!(axis1, :monitor_instances)
    # rel_lims = pop!(axis1, :rel_lims)
    # # umax = pop!(axis1,:umax)
    # bipolar = pop!(axis1, :bipolar)
    n = length(u)
    T = dt * (n - 1)
    t = 0:frameat:T
    f = Figure(size=(600, 500))
    g1 = f[1, 1]
    g2 = f[2, 1]
    colsize!(f.layout, 1, Auto(2.5))

    r = GLMakie.record(f, fn, t; framerate) do t
        i = round(Int, t / dt + 1)
        empty!(f)
        # ax = Axis(f[1, 1];)

        plotfield!(g1, u[i];
            field, t, geometry, source_instances, monitor_instances, bipolar, umax, elevation, azimuth,# title=pop!(axis1, :title),
            axis1...)
        if t == T
            display(f)
        end

        if !isnothing(y)
            n, = size(y)
            ylims = extrema(stack(y))
            if isempty(labels)
                labels = String.(Symbol.((1:n)))
            end
            # ylims = extrema.(y)
            axis2 = merge((;
                    title="monitors",
                    limits=((0, T), ylims),), axis2)
            # labels = pop!(axis2, :labels)
            #    xlabel= pop!(axis2,:xlabel)
            #    ylabel= pop!(axis2,:ylabel)
            ax = Axis(g2; axis2...)
            for (y, label) = zip(y, labels)
                lines!(ax, 0:dt:(i-1)*dt, y[1:i]; label,)
            end
            axislegend()
            rowsize!(f.layout, 1, Auto(2.5))
        end
    end
    println("saved simulation recording to $fn")
    f
end
