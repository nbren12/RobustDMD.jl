#====================================================================
    Proximal Gradient Solver for Outer Problem
====================================================================#

type PG_options
    itm::Int64
    tol::Float64
    ifstats::Bool
    show_his::Bool
    print_frequency::Int64

    prox::Function
end

function PG_solve_DMD!(vars, params, svars, options::PG_options)
    # iteration parameters
    itm = options.itm;
    tol = options.tol;
    ifstats = options.ifstats;
    stats = OptimizerStats(itm,ifstats);
    pft = options.print_frequency;
    show_history = options.show_his;
    # prox function
    prox = options.prox;
    # problem dimensions
    m = params.m;
    n = params.n;
    k = params.k;

    # pre-allocate the variables
    gαr  = zeros(k<<1);
    gαr⁺ = zeros(k<<1);
    αr  = vars.alphar;
    prox(αr)
    αr⁻ = copy(αr);
    α_fg! = (gαr, αr) -> alpha_fg!(αr, gαr, vars, params, svars);
    α_g!  = (gαr, αr) -> alphagrad!(αr, gαr, vars, params, svars);
    α_f   = (αr) -> alphafunc(αr, vars, params, svars);

    # initialize variables
    obj = α_fg!(gαr, αr);
    err = 1.0;
    noi = 0;

    updateOptimizerStats!(stats,obj,err,noi,ifstats)
    
    if ( isnan(obj) || isinf(obj) )
        println("BAD INITIAL GUESS ",αr)
        println("ABORT")
        return
    end

    while err ≥ tol
        η = descent_PG!(αr⁻, αr, gαr, obj, α_f, prox);
        prox(αr);

        obj = α_fg!(gαr, αr);
        err = vecnorm(αr - αr⁻)/η;
        #err = vecnorm(αr - αr⁻)
        copy!(αr⁻, αr);
        noi += 1;
        # @show gαr;
        # @show αr;
        (noi % pft == 0 && show_history) && @printf("PG: iter %4d, obj %1.2e, err %1.2e\n",
                                                    noi, obj, err);

        updateOptimizerStats!(stats,obj,err,noi,ifstats)
        
        noi ≥ itm && break;
    end

    return stats
    
end

#-----------------------------------------------------------------------------------------
# Descent Line Search
#----------------------------------------------------------------------------------------
function descent_PG!(x⁻, x, g, obj, f, prox; αmin = 1e-8, tol = 1e-12)
    n = length(x);
    α = 10.0;
    noi = 0;
    for i = 1:n
        x[i] = x⁻[i] - α*g[i];
    end
    prox(x);
    obj⁺ = f(x);
    while obj⁺ > obj || isnan(obj⁺)
        α *= 0.5;
        for i = 1:n
            x[i] = x⁻[i] - α*g[i];
        end
        prox(x);
        obj⁺ = f(x);
        noi += 1;
        # noi ≥ 5 && break;
        α < αmin && break;
    end
    # @show noi, α
    if (obj⁺ > obj || isnan(obj⁺))
        α = 0
        for i = 1:n
            x[i] = x⁻[i]
        end
    end
    return α;
end


#-----------------------------------------------------------------------------------------
# Descent Line Search
#----------------------------------------------------------------------------------------
function armijo_PG!(x⁻, x, g, obj, f, prox; αmin = 1e-8, tol = 1e-12)
    n = length(x);
    α = 10.0;
    noi = 0;
    for i = 1:n
        x[i] = x⁻[i] - α*g[i];
    end
    prox(x);
    obj⁺ = f(x);
    while obj⁺ > obj || isnan(obj⁺)
        α *= 0.5;
        for i = 1:n
            x[i] = x⁻[i] - α*g[i];
        end
        prox(x);
        obj⁺ = f(x);
        noi += 1;
        # noi ≥ 5 && break;
        α < αmin && break;
    end
    # @show noi, α
    if (obj⁺ > obj || isnan(obj⁺))
        α = 0
        for i = 1:n
            x[i] = x⁻[i]
        end
    end
    return α;
end
