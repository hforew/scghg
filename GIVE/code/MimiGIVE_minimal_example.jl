using MimiGIVE

discount_rates = [
	(label = "1.5% Ramsey", prtp = exp(0.000091496)-1, eta  = 1.016010261),
	(label = "2.0% Ramsey", prtp = exp(0.001972641)-1, eta  = 1.244459020),
        (label = "2.5% Ramsey", prtp = exp(0.004618785)-1, eta  = 1.421158057)
]
 
save_list = [(:CromarMortality, :excess_deaths)]
 
# run mc sim, save extra data in a folder called "output"
result = MimiGIVE.compute_scc(
	year = 2020,
	n = 2,
	discount_rates = discount_rates,
	save_list = save_list,
	output = "output",
)
 
# iterate through the results, and just print the keys and values inside
for (k, v) in result[:scc]
 	println("key = $k, value = $v")
end
