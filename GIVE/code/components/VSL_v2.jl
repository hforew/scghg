using Mimi

# Calculate the value of a statistical life
# follows equations from FUND 
# println("VSL v2")

@defcomp VSL_v2 begin

    country       = Index()

    α             = Parameter(unit = "US\$2005")    # VSL scaling parameter
    ϵ             = Parameter()                     # Income elasticity of the value of a statistical life.
    y₀            = Parameter(unit = "US\$2005")    # Normalization constant.
    pc_gdp        = Parameter(index=[time, country], unit = "US\$2005/yr/person") # Country-level per capita GDP ($/person).

    vsl           = Variable(index=[time, country], unit = "US\$2005/yr") # Value of a statistical life ($).
    
    function run_timestep(p, v, d, t)
      for c in d.country
           v.vsl[t,c] = p.α * (p.pc_gdp[t,174] / p.y₀) ^ p.ϵ  # v2 for give t, set all countrie to USA VSL
          # @show c   # shows the c parameter. 174 is for USA
        end
    end
end
