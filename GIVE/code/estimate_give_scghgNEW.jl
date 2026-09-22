######################################
############################  preamble
######################################

## set the environment (comment out to use global enviro, with MimiGIVE#ce-fix or latest MimiGIVE)
# activates enviro within GIVE folder (using Project.toml and manifest.toml files)
# using Pkg;
# Pkg.activate(joinpath(@__DIR__, ".."));  # activate enviro 1 folder up from current dir (i.e. GIVE folder)

## instantiate the environment
# Pkg.instantiate(); # installs any missing packages 


## precompile  
using Revise
using Mimi, MimiGIVE, MimiRFFSPs, DataDeps, Random, CSV, DataFrames, Statistics, Query, CSVFiles; # load packages

include("components/VSL_rep.jl") # replicates as orignal VSL
include("components/VSL_v0.jl") # Test VSL change
include("components/VSL_v2.jl") # Test VSL change
include("components/VSL_v3.jl") #  Test VSL change
include("components/new_sector_damages.jl") # dummy sector
include("components/DamageAggregator_NewSectorDamages.jl") # dummy sector
include("components/Damages_RegionAggregatorSum_NewSectorDamages.jl") # dummy sector
include("components/Fire_damages.jl") # fire sector
include("components/DamageAggregator_FireDamages.jl") # fire sector
include("components/Damages_RegionAggregatorSum_FireDamages.jl") # fire sector
# include("main_new_sector.jl") # I believe main main_new_sector duplicates this file, estimate_give_scghgNEW
# include("main_model_new_sector.jl")
# include("main_mcs_new_sector.jl")
# include("scc_new_sector.jl")

println("starting data download")
## automatically download data dependancies (rffsps)
ENV["DATADEPS_ALWAYS_ACCEPT"] = "true" # modify enviro var (set some config variable)
MimiRFFSPs.datadep"rffsps_v5" # downloads 

######################################
##################### model parameters
######################################

## set random seed for monte carlo 
 seed = 42;
# seed = 1; # MY SEED

## set number of monte carlo draws
n = 2;  # reduce number for test

## set emissions year
year = 2020;

## choose damage module
damages = :give;

## version 

# code_ver = "ver-ceFix" # hardcoded version of MimiGIVE
 code_ver = "v2.1.1" # hardcoded version of MimiGIVE

version = "V6"  # my hardcoded version

## choose gas
gas = :CO2;  # colon for symbol variables (like a string, or list of option for function)

## set named list of discount rates
discount_rates = 
    [
      #  (label = "1.5% Ramsey", prtp = exp(0.000091496)-1, eta  = 1.016010261),
        (label = "2.0% Ramsey", prtp = exp(0.001972641)-1, eta  = 1.244459020),
      #  (label = "2.5% Ramsey", prtp = exp(0.004618785)-1, eta  = 1.421158057)
    ];

## choose the model objects that you would like to save by uncommenting the lines (optional).
save_list = 
    [
        (:Socioeconomic, :co2_emissions),                      # Emissions (GtC/yr)
       #  (:Socioeconomic, :ch4_emissions),                    # Emissions (GtCH4/yr)
       #  (:Socioeconomic, :n2o_emissions),                    # Emissions (GtN2O/yr)
         (:Socioeconomic, :population),                       # Country-level population (millions of persons)
         (:Socioeconomic, :population_global),                # Global population (millions of persons)
         (:Socioeconomic, :gdp_global),                       # Global GDP (billions of USD $2005/yr)
         (:PerCapitaGDP, :global_pc_gdp),                     # Global per capita GDP (thousands of USD $2005/yr)
         (:TempNorm_1850to1900, :global_temperature_norm),    # Global surface temperature anomaly (K) from preinudstrial
         (:co2_cycle, :co2),                                  # Total atmospheric concentrations (ppm)
        # (:ch4_cycle, :CH₄),                                  # Total atmospheric concentrations (ppb)
        # (:n2o_cycle, :N₂O),                                  # Total atmospheric concentrations (ppb)
        # (:OceanPH, :pH),                                     # Ocean pH levels
        # (:OceanHeatAccumulator, :del_ohc_accum),             # Accumulated Ocean heat content anomaly
         (:global_sea_level, :sea_level_rise),                # Total sea level rise from all components (includes landwater storage for projection periods) (m)
         (:CromarMortality, :excess_deaths),                  # Country-level excess deaths
         (:CromarMortality, :excess_death_rate),              # Country-level excess death rate
         (:DamageAggregator, :cromar_mortality_damage),       # Mortality damages 
         (:DamageAggregator, :agriculture_damage),            # Agricultural damages  
         (:DamageAggregator, :energy_damage),                  # Energy Damages
         # (:DamageAggregator, :park_mortality_damage),          # new sector fire
         # (:fire_mortality_damages, :excess_deaths),              # new sector fire
         # (:fire_mortality_damages, :mortality_costs),              # new sector fire
         # (:fire_mortality_damages, :excess_death_rate),              # new sector fire
         (:CromarMortality, :mortality_costs),    
         (:DamageAggregator, :total_damage),                  
         (:DamageAggregator, :total_damage_share),                  
         (:DamageAggregator, :total_damage_domestic),   
         (:global_netconsumption, :net_cpc),                                             
         (:VSL, :vsl)
    ];

## specify your output directory for the save_list items. comment out if save_list is empty
 output_dir = joinpath(@__DIR__, "../output/save_list/$gas-$version$code_ver$damages-$year-n$n")

## read the series of rffsp-fair pairings. these were randomly selected pairings. read GIVE documentation for other functionality.
## appears redundant? code can execute without?
# fair_parameter_set_ids = CSV.File(joinpath(@__DIR__, "../input/rffsp_fair_sequence.csv"))["fair_id"][1:n];
# rffsp_sampling_ids     = CSV.File(joinpath(@__DIR__, "../input/rffsp_fair_sequence.csv"))["rffsp_id"][1:n];

## GIVE results are in 2005 USD, this is the price deflator to bring the results to 2020 USD. accessed 09/13/2022. source: https://apps.bea.gov/iTable/iTable.cfm?reqid=19&step=3&isuri=1&select_all_years=0&nipa_table_list=13&series=a&first_year=2005&last_year=2020&scale=-99&categories=survey&thetable=
pricelevel_2005_to_2020 = 113.648/87.504;

######################################
####################### estimate scghg
######################################

## set random seed
Random.seed!(seed);

println("create model object")
## get model 
m = MimiGIVE.get_model();

## update VSL change 

if version == "V1" 
  replace!(m, :VSL => VSL_rep) # :VSL is the name of the component and VSL_rep is the object assigned/tagged/titled to component
  Mimi.set_first_last!(m, :VSL, first=2020)
elseif version == "V2"
  replace!(m, :VSL => VSL_v2) # set all countries to USA VSL
  Mimi.set_first_last!(m, :VSL, first=2020) 
elseif version == "V3"
  replace!(m, :VSL => VSL_v3)
  Mimi.set_first_last!(m, :VSL, first=2020)
  connect_param!(m, :VSL => :global_pc_gdp, :PerCapitaGDP => :global_pc_gdp) # set global of VSL to be global from PerCapitaGDP
elseif version == "V0"
  replace!(m, :VSL => VSL_v0)  # TEST. multiple by 1.5
  Mimi.set_first_last!(m, :VSL, first=2020)
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
  park_coeffs       = load(joinpath(@__DIR__,"..", "data", "ParkMortality_damages_coefficients.csv")) |> DataFrame
  park_mapping_raw  = load(joinpath(@__DIR__,"..", "data", "Mapping_countries_to_park_mortality_regions.csv")) |> DataFrame
  park_regions      = (load(joinpath(@__DIR__,"..", "data", "Dimension_park_mortality_regions.csv")) |> @select(:park_mortality_region) |> DataFrame |> Matrix)[:] # not currently a dimension in model
  # Load raw data (cromar - replicate).
  #  park_coeffs       = load(joinpath(@__DIR__,"..", "data", "cromarMortality_damages_coefficients.csv")) |> DataFrame
  #  park_mapping_raw  = load(joinpath(@__DIR__,"..", "data", "Mapping_countries_to_cromar_mortality_regions.csv")) |> DataFrame
  #  park_regions      = (load(joinpath(@__DIR__,"..", "data", "Dimension_cromar_mortality_regions.csv")) |> @select(:park_mortality_region) |> DataFrame |> Matrix)[:] # not currently a dimension in model

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

  # load fire PM2.5 mortality data (% of PM2.5 mortality attributable to fire)
  FirePM25_mortality_mapping  = load(joinpath(@__DIR__,"..", "data", "FirePM2.5_country.csv")) |> DataFrame
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
  park_coeffs       = load(joinpath(@__DIR__,"..", "data","ParkMortality_damages_coefficients.csv")) |> DataFrame
  park_mapping_raw  = load(joinpath(@__DIR__,"..", "data", "Mapping_countries_to_park_mortality_regions.csv")) |> DataFrame
  park_regions      = (load(joinpath(@__DIR__,"..", "data","Dimension_park_mortality_regions.csv")) |> @select(:park_mortality_region) |> DataFrame |> Matrix)[:] # not currently a dimension in model
  # Load raw data (cromar - replicate).
  #  park_coeffs       = load(joinpath(@__DIR__,"..", "data", "cromarMortality_damages_coefficients.csv")) |> DataFrame
  #  park_mapping_raw  = load(joinpath(@__DIR__,"..", "data", "Mapping_countries_to_cromar_mortality_regions.csv")) |> DataFrame
  #  park_regions      = (load(joinpath(@__DIR__,"..", "data", "Dimension_cromar_mortality_regions.csv")) |> @select(:park_mortality_region) |> DataFrame |> Matrix)[:] # not currently a dimension in model

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
  fire_share = load(joinpath(@__DIR__,"..", "data", "FirePM2.5_region.csv")) |> DataFrame

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

println("start estimation")
## estimate scghg  --> function compute_scc is from MimiGIVE package
 results = 
    MimiGIVE.compute_scc(m, 
                        n                       = n , 
                        gas                     = gas, 
                        year                    = year, 
                        pulse_size              = 0.0001,                   ## scales the defalut pulse size of 1Gt to 100k metric tons 
                        certainty_equivalent    = true,                     
                        fair_parameter_set      = :deterministic,           ## optionally read the rffsp-fair parameter sequence from file
                        fair_parameter_set_ids  = fair_parameter_set_ids,   ## optionally read the rffsp-fair parameter sequence from file
                        rffsp_sampling          = :deterministic,           ## optionally read the rffsp-fair parameter sequence from file
                        rffsp_sampling_ids      = rffsp_sampling_ids,       ## optionally read the rffsp-fair parameter sequence from file
                        CIAM_GDPcap             = true, 
                        discount_rates          = discount_rates, 
                        save_list               = save_list,                ## comment out if save_list is empty
                        output_dir              = output_dir,               ## comment out if save_list is empty
                        save_slr_damages        = true,                    ## save coastal damages, comparable to including DamageAggregator components in save_list
                        save_cpc                = true,                     ## must be true to recover certainty equivalent scghgs
                        compute_domestic_values = false,
                        save_md                = true,
                        compute_sectoral_values = true);

 ## estimate scghg  --> function compute_modified_scc replaces compute_scc from MimiGIVE package                       
#  results = 
#     compute_modified_scc(m, 
#                         n                       = n , 
#                         gas                     = gas, 
#                         year                    = year, 
#                         pulse_size              = 0.0001,                   ## scales the defalut pulse size of 1Gt to 100k metric tons 
#                         certainty_equivalent    = true,                     
#                         fair_parameter_set      = :deterministic,           ## optionally read the rffsp-fair parameter sequence from file
#                         fair_parameter_set_ids  = fair_parameter_set_ids,   ## optionally read the rffsp-fair parameter sequence from file
#                         rffsp_sampling          = :deterministic,           ## optionally read the rffsp-fair parameter sequence from file
#                         rffsp_sampling_ids      = rffsp_sampling_ids,       ## optionally read the rffsp-fair parameter sequence from file
#                         CIAM_GDPcap             = true, 
#                         discount_rates          = discount_rates, 
#                         save_list               = save_list,                ## comment out if save_list is empty
#                         output_dir              = output_dir,               ## comment out if save_list is empty
#                         save_slr_damages        = true,                    ## save coastal damages, comparable to including DamageAggregator components in save_list
#                         save_cpc                = true,                     ## must be true to recover certainty equivalent scghgs
#                         compute_domestic_values = false,
#                         save_md                = true,
#                         compute_sectoral_values = true);

                
######################################
####################### export results
######################################

## blank data
scghgs = DataFrame(sector = String[], 
                   discount_rate = String[], 
                   trial = Int[], 
                   #scghg = Int[]
                   scghg = Float64[] # changing data type for 2 dp below
                  );
    
## populate data
for (k, v) in results[:scc] # results is the output of the model run, looping thru scc property
    for (i, sc) in enumerate(v.ce_sccs)
        push!(scghgs, 
        (sector = String(k.sector), 
        discount_rate = k.dr_label, 
        trial = i, 
        # scghg = round(Int, sc*pricelevel_2005_to_2020)
         scghg = round(sc*pricelevel_2005_to_2020,digits=2)
        # scghg = sc*pricelevel_2005_to_2020
        )
      )
    end
end

## export full distribution    
scghgs |> save(joinpath(@__DIR__, "../output/scghgs/full_distributions/$gas/sc_dist$version$code_ver-$gas-$damages-$year-n$n.csv"));

## collapse to the certainty equivalent scghgs
scghgs_mean = combine(groupby(scghgs, [:sector, :discount_rate]), 
                      # :scghg => (x -> round(Int, mean(x))) .=> :scghg
                      # :scghg => (x -> round(mean(x), digits=0)) .=> :scghg
                      :scghg => (x -> round(mean(x), digits=2)) .=> :scghg
                     )

## export average scghgs    
scghgs_mean |> save(joinpath(@__DIR__, "../output/scghgs/sc$version$code_ver-$gas-$damages-$year-n$n.csv"));

# scghgs_mean |> save(joinpath(@__DIR__, "../output/scghgs_VSL_mod/sc-$gas-$damages-$year-n$n.csv"));

## end of script, have a great day.
