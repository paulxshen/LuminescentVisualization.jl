function plotfield!(
    f,
    u::AbstractArray,
    ;
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

    title = "$title\nt = $t\n"

    # colormap = [(:blue, 1), (:red, 1)]
    # colormap = :seismic
    colormap = bipolar ? :seismic : [(:white, 0), (:orange, 1)]
    colorrange = bipolar ? (-1, 1) : (0, 1)
    algorithm = bipolar ? :absorption : :mip
    u ./= umax
    # if bipolar
    #     u = (u .+ 1) ./ 2
    # end
    d = ndims(u)

    "plot field"
    ax, __ = volume(f, u; axis=(; kw..., type=Axis3, title,), algorithm, colormap, colorrange,)
    !isnothing(elevation) && (ax.elevation[] = elevation)
    !isnothing(azimuth) && (ax.azimuth[] = azimuth)
    # Colorbar(f)

    if !isnothing(geometry)
        "plot geometry"
        volume!(f, geometry, colormap=[(:white, 0), (:gray, 0.2)])#, colorrange=(ϵ1, ϵ2))
    end

    "plot monitors"
    if !isempty(monitor_instances)
        a = zeros(size(u))
        for (i, m) = enumerate(monitor_instances)
            a[first(values(m.idxs))...] .= 1
            text = isempty(m.label) ? "m$i" : m.label
            text!(f, first(values(m.centers))..., ; text, align=(:center, :center))
        end
        volume!(f, a, colormap=[(:white, 0), (:teal, 0.2)])#, colorrange=(ϵ1, ϵ2))
        # # save("temp/$t.png", f)
    end

    "plot sources"
    for (i, s) = enumerate(source_instances)
        volume!(f, first(values(s._g)), colormap=[(:white, 0), (:yellow, 0.2)])
        text = isempty(s.label) ? "s$i" : s.label
        text!(f, first(values(s.c))..., ; text, align=(:center, :center))
    end
    # # save("temp/$t.png", f)
end
# rotate_cam!(ax.scene, (45, 0, 0))

function recordsim(fn, u, y=nothing;
    dt, geometry=nothing,
    source_instances=[],
    monitor_instances=[],
    lims_scale=0.5,
    umax=maximum(abs, u[round(Int, length(u) / 2)]) * lims_scale,
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
    # lims_scale = pop!(axis1, :lims_scale)
    # # umax = pop!(axis1,:umax)
    # bipolar = pop!(axis1, :bipolar)
    n = length(u)
    T = dt * (n - 1)
    t = 0:frameat:T
    f = Figure(size=(400, 500))
    g1 = f[1, 1]
    g2 = f[2, 1]
    rowsize!(f.layout, 1, Auto(1.5))

    r = record(f, fn, t; framerate) do t
        i = round(Int, t / dt + 1)
        empty!(f)
        # ax = Axis(f[1, 1];)

        plotfield!(g1, u[i]; t, geometry, source_instances, monitor_instances, bipolar, umax, elevation, azimuth,# title=pop!(axis1, :title),
            axis1...)

        if !isnothing(y)
            n, = size(y)
            if isempty(labels)
                labels = String.(Symbol.((1:n)))
            end
            ylims = extrema(y)
            axis2 = merge((;
                    title="monitors",
                    limits=((0, T), ylims),), axis2)
            # labels = pop!(axis2, :labels)
            #    xlabel= pop!(axis2,:xlabel)
            #    ylabel= pop!(axis2,:ylabel)
            ax = Axis(g2; axis2...)
            for (y, label) = zip(eachcol(y), labels)
                lines!(ax, 0:dt:(i-1)*dt, y[1:i]; label,)
            end
            axislegend()
        end
    end
    println("saved simulation recording to $fn")
    r
end
