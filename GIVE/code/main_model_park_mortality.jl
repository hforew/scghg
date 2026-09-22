using Mimi
using MimiGIVE

include("components/VSL_rep.jl") # replicates as orignal VSL
include("components/VSL_v0.jl") # Test VSL change
include("components/VSL_v2.jl") # Test VSL change
include("components/VSL_v3.jl") #  Test VSL change
include("components/Fire_damages.jl") # fire sector
include("components/DamageAggregator_FireDamages.jl") # fire sector
include("components/Damages_RegionAggregatorSum_FireDamages.jl") # fire sector

function get_modified_model(;version::String="V6")

    ## get model 
    m = MimiGIVE.get_model();

    if version == "V0"
        replace!(m, :VSL => VSL_v0)  # TEST. multiple by 1.5
        Mimi.set_first_last!(m, :VSL, first=2020)

    elseif version == "V1" 
        replace!(m, :VSL => VSL_rep) # :VSL is the name of the component and VSL_rep is the object assigned/tagged/titled to component
        Mimi.set_first_last!(m, :VSL, first=2020)

    elseif version == "V2"
        replace!(m, :VSL => VSL_v2) # set all countries to USA VSL
        Mimi.set_first_last!(m, :VSL, first=2020) 

    elseif version == "V3"
        replace!(m, :VSL => VSL_v3)
        Mimi.set_first_last!(m, :VSL, first=2020)
        connect_param!(m, :VSL => :global_pc_gdp, :PerCapitaGDP => :global_pc_gdp) # set global of VSL to be global from PerCapitaGDP

    elseif version == "V4"
        replace!(m, :VSL => VSL_rep) # :VSL is the name of the component and VSL_rep is the object assigned/tagged/titled to component
        Mimi.set_first_last!(m, :VSL, first=2020)

        # new sector
        println("new sector")
        add_comp!(m, NewSectorDamages, first = 2020, after = :energy_damages)
        connect_param!(m, :NewSectorDamages => :temperature, :temperature => :T)
        connect_param!(m, :NewSectorDamages => :gdp, :Socioeconomic => :gdp)
        replace!(m, :Damages_RegionAggregatorSum => Damages_RegionAggregatorSum_NewSectorDamages) # FORK DOES NOT HAVE Damages_RegionAggregatorSum
        replace!(m, :DamageAggregator => DamageAggregator_NewSectorDamages)
        
        # both components need to start in 2020, this is reset to the model start (1765) by replace!, so we need to reset it to 2020
        Mimi.set_first_last!(m, :DamageAggregator, first=2020)
        Mimi.set_first_last!(m, :Damages_RegionAggregatorSum, first=2020)
        connect_param!(m, :DamageAggregator => :damage_new_sector, :NewSectorDamages => :damages)
        connect_param!(m, :Damages_RegionAggregatorSum => :damage_new_sector, :NewSectorDamages => :damages) # FORK DOES NOT HAVE Damages_RegionAggregatorSum
        connect_param!(m, :DamageAggregator => :damage_new_sector_regions, :Damages_RegionAggregatorSum => :damage_new_sector_regions) # FORK DOES NOT HAVE Damages_RegionAggregatorSum
        
    elseif version == "V5"
        replace!(m, :VSL => VSL_rep) # :VSL is the name of the component and VSL_rep is the object assigned/tagged/titled to component
        Mimi.set_first_last!(m, :VSL, first=2020)

        # new sector
        println("fire")
        add_comp!(m, fire_mortality_damages, first = 2020, after = :energy_damages)
        
        # Load raw data (Park et al. 2024).
        park_coeffs       = load(joinpath(@__DIR__, "..", "data", "ParkMortality_damages_coefficients.csv")) |> DataFrame
        park_mapping_raw  = load(joinpath(@__DIR__, "..", "data", "Mapping_countries_to_park_mortality_regions.csv")) |> DataFrame
        park_regions      = (load(joinpath(@__DIR__, "..", "data", "Dimension_park_mortality_regions.csv")) |> @select(:park_mortality_region) |> DataFrame |> Matrix)[:] # not currently a dimension in model
        # Load raw data (cromar - replicate).
        #  park_coeffs       = load(joinpath(@__DIR__, "data", "cromarMortality_damages_coefficients.csv")) |> DataFrame
        #  park_mapping_raw  = load(joinpath(@__DIR__, "data", "Mapping_countries_to_cromar_mortality_regions.csv")) |> DataFrame
        #  park_regions      = (load(joinpath(@__DIR__, "data", "Dimension_cromar_mortality_regions.csv")) |> @select(:park_mortality_region) |> DataFrame |> Matrix)[:] # not currently a dimension in model

        # Initialize an array to store country-level coefficients
        country_β_mortality = zeros(length(park_mapping_raw.ISO3))  # temporary -- leave unchaged -- will be vector of betas per country alphabetical by country code

        # Loop through the regions and assign regional coefficients to proper sets of countries.
        for r = 1:length(park_regions)
            # Find country indices for region "r"
            r_index = findall(x->x==park_regions[r], park_mapping_raw.park_region)
            # Find index for region "r" coefficient.
            β_index = findfirst(x->x==park_regions[r], park_coeffs[!, "park Region Name"])
            # Assign all countries in that region proper coefficient.
            country_β_mortality[r_index] .= park_coeffs[β_index, "Pooled Beta"]
        end

        # Get indices to reorder park countries mapped to countries dimension (could be correct oder already, this is a safety check)
        # park_indices = indexin(countries, park_mapping_raw.ISO3) # from main -- don't think that need 
        # country_β_mortality = country_β_mortality[park_indices] # from main -- don't think that need 

        update_param!(m, :fire_mortality_damages, :β_fire, country_β_mortality) # assign values from country_β_mortality to β_fire. values assigned from excel output

        # load fire PM2.5 mortality data
        FirePM25_mortality_mapping  = load(joinpath(@__DIR__,"..",  "data", "FirePM2.5_country.csv")) |> DataFrame
        update_param!(m, :fire_mortality_damages, :PM25_mortality_fire, FirePM25_mortality_mapping.fire_pm25_mortality) # connect column 2 to paramater PM25_mortality_fire in component

        socioeconomics_source = :RFF # HARDECODED. RFF is default, but change to SPP if needed
        if socioeconomics_source == :SSP
            connect_param!(m, :fire_mortality_damages, :baseline_mortality_rate, :model_ssp_baseline_mortality_rate) # shared model parameter
        elseif socioeconomics_source == :RFF  # rff is default
            connect_param!(m, :fire_mortality_damages => :baseline_mortality_rate, :Socioeconomic => :deathrate) # deathrate output is input for baseline_mortality_rate in component fire_mortality_damages
        end

        connect_param!(m, :fire_mortality_damages => :population,  :Socioeconomic => :population)
        connect_param!(m, :fire_mortality_damages => :temperature, :temperature => :T)
        connect_param!(m, :fire_mortality_damages => :vsl, :VSL => :vsl)

        replace!(m, :Damages_RegionAggregatorSum => Damages_RegionAggregatorSum_FireDamages) #
        replace!(m, :DamageAggregator => DamageAggregator_FireDamages)
        # both components need to start in 2020, this is reset to the model start (1765) by replace!, so we need to reset it to 2020
        Mimi.set_first_last!(m, :DamageAggregator, first=2020)
        Mimi.set_first_last!(m, :Damages_RegionAggregatorSum, first=2020)
        connect_param!(m, :DamageAggregator => :damage_park_mortality, :fire_mortality_damages => :mortality_costs) # take output from fire_damages comp as input for aggregator
        connect_param!(m, :Damages_RegionAggregatorSum => :damage_park_mortality, :fire_mortality_damages => :mortality_costs) # 
        connect_param!(m, :DamageAggregator => :damage_park_mortality_regions, :Damages_RegionAggregatorSum => :damage_park_mortality_regions) # 

    elseif version == "V6"
        replace!(m, :VSL => VSL_rep) # :VSL is the name of the component and VSL_rep is the object assigned/tagged/titled to component
        Mimi.set_first_last!(m, :VSL, first=2020)
        # new sector
        println("fire")
        add_comp!(m, fire_mortality_damages, first = 2020, after = :energy_damages)
        # Load raw data (Park et al. 2024).
        park_coeffs       = load(joinpath(@__DIR__, "..", "data", "ParkMortality_damages_coefficients.csv")) |> DataFrame
        park_mapping_raw  = load(joinpath(@__DIR__, "..", "data", "Mapping_countries_to_park_mortality_regions.csv")) |> DataFrame
        park_regions      = (load(joinpath(@__DIR__, "..",  "data", "Dimension_park_mortality_regions.csv")) |> @select(:park_mortality_region) |> DataFrame |> Matrix)[:] # not currently a dimension in model
        # Load raw data (cromar - replicate).
        #  park_coeffs       = load(joinpath(@__DIR__, "data", "cromarMortality_damages_coefficients.csv")) |> DataFrame
        #  park_mapping_raw  = load(joinpath(@__DIR__, "data", "Mapping_countries_to_cromar_mortality_regions.csv")) |> DataFrame
        #  park_regions      = (load(joinpath(@__DIR__, "data", "Dimension_cromar_mortality_regions.csv")) |> @select(:park_mortality_region) |> DataFrame |> Matrix)[:] # not currently a dimension in model

        # Initialize an array to store country-level coefficients
        country_β_mortality = zeros(length(park_mapping_raw.ISO3))  # temporary -- leave unchaged -- will be vector of betas per country alphabetical by country code

        # Loop through the regions and assign regional coefficients to proper sets of countries.
        for r = 1:length(park_regions)
            # Find country indices for region "r"
            r_index = findall(x->x==park_regions[r], park_mapping_raw.park_region)
            # Find index for region "r" coefficient.
            β_index = findfirst(x->x==park_regions[r], park_coeffs[!, "park Region Name"])
            # Assign all countries in that region proper coefficient.
            country_β_mortality[r_index] .= park_coeffs[β_index, "Pooled Beta"]
        end

        # Get indices to reorder park countries mapped to countries dimension (could be correct oder already, this is a safety check)
        # park_indices = indexin(countries, park_mapping_raw.ISO3) # from main -- don't think that need 
        # country_β_mortality = country_β_mortality[park_indices] # from main -- don't think that need 
        update_param!(m, :fire_mortality_damages, :β_fire, country_β_mortality) # assign values from country_β_mortality to β_fire. values assigned from excel output

        # Load fire PM2.5 mortality data by region
        fire_share = load(joinpath(@__DIR__, "..", "data", "FirePM2.5_region.csv")) |> DataFrame

        # Initialize array for country-level fire PM2.5 mortality values
        country_firePM25_mortality = zeros(length(park_mapping_raw.ISO3))  # temporary -- leave unchanged -- will be vector of values per country alphabetical by country code

        # Loop through regions and assign regional values to proper sets of countries
        for r = 1:length(park_regions)
            # Find country indices for region "r"
            r_index = findall(x->x==park_regions[r], park_mapping_raw.park_region)
            
            # Find index for region "r" coefficient
            fire_index = findfirst(x->x==park_regions[r], fire_share[!, "park Region Name"])
            
            # Assign all countries in that region proper fire PM2.5 value
            country_firePM25_mortality[r_index] .= fire_share[fire_index, "firePM25mortality_pct"]
        end

        # Update model parameter with country-level PM2.5 mortality values
        update_param!(m, :fire_mortality_damages, :PM25_mortality_fire, country_firePM25_mortality)

        socioeconomics_source = :RFF # HARDECODED. RFF is default, but change to SPP if needed
        if socioeconomics_source == :SSP
            connect_param!(m, :fire_mortality_damages, :baseline_mortality_rate, :model_ssp_baseline_mortality_rate) # shared model parameter
        elseif socioeconomics_source == :RFF  # rff is default
            connect_param!(m, :fire_mortality_damages => :baseline_mortality_rate, :Socioeconomic => :deathrate) # deathrate output is input for baseline_mortality_rate in component fire_mortality_damages
        end

        connect_param!(m, :fire_mortality_damages => :population,  :Socioeconomic => :population)
        connect_param!(m, :fire_mortality_damages => :temperature, :temperature => :T)
        connect_param!(m, :fire_mortality_damages => :vsl, :VSL => :vsl)

        replace!(m, :Damages_RegionAggregatorSum => Damages_RegionAggregatorSum_FireDamages) #
        replace!(m, :DamageAggregator => DamageAggregator_FireDamages)

        # both components need to start in 2020, this is reset to the model start (1765) by replace!, so we need to reset it to 2020
        Mimi.set_first_last!(m, :DamageAggregator, first=2020)
        Mimi.set_first_last!(m, :Damages_RegionAggregatorSum, first=2020)
        connect_param!(m, :DamageAggregator => :damage_park_mortality, :fire_mortality_damages => :mortality_costs) # take output from fire_damages comp as input for aggregator
        connect_param!(m, :Damages_RegionAggregatorSum => :damage_park_mortality, :fire_mortality_damages => :mortality_costs) # 
        connect_param!(m, :DamageAggregator => :damage_park_mortality_regions, :Damages_RegionAggregatorSum => :damage_park_mortality_regions) # 
    end

    return m

end