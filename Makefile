.ONESHELL:
.SHELLFLAGS = -eu -o pipefail -c

# Load the environment variables
include .env
export

# Add this line to tell Make that these are commands, not files
.PHONY: setup clean figures

setup:
	@echo "Checking Stadia Maps API key: $(STADIA_MAPS_API_KEY)"
	@curl --silent --fail \
		"https://tiles.stadiamaps.com/tiles/alidade_smooth/1/1/1.png?api_key=$(STADIA_MAPS_API_KEY)" \
		-I > /dev/null || \
		(echo "Error: Invalid STADIA_MAPS_API_KEY"; exit 1)
	@echo "Validating Zenodo ID ($(zenodo_id))..."
	@curl --silent --fail \
		"https://zenodo.org/api/records/$(zenodo_id)" \
		-I > /dev/null || (echo "Error: Zenodo ID '$(zenodo_id)' not found or private"; exit 1)
	
	@mkdir -p mamba_env data figures
	@echo "Making mamba environment..."
	mamba env create -p mamba_env/create_figs -f create_figs.yml
	
	@echo "Pulling Zenodo Record..."
	#mamba run -p mamba_env/create_figs zenodo_get $(zenodo_id) -o ./data
	#@unzip -q data/nwrfc-calibration-paper-data.zip
	#@mv nwrfc-calibration-paper-data/* data
	#@rm -r nwrfc-calibration-paper-data

figures:
	@echo "Creating fig1-basin-map..."
	@mamba run -p mamba_env/create_figs Rscript fig1-basin-map.R > /dev/null
	@echo "Saved to 'figures/fig1-basin-map.png'"

	@echo "Creating fig5-zone-map..."
	@mamba run -p mamba_env/create_figs python fig5-zone-map.py -a $(STADIA_MAPS_API_KEY) > /dev/null
	@echo "Saved to 'figures/fig5-zone-map.png'"

	@echo "Creating fig7-cdf-metric-summary..."
	@mamba run -p mamba_env/create_figs Rscript fig7-cdf-metric-summary.R > /dev/null
	@echo "Saved to 'figures/fig7-cdf-metric-summary.pdf'"

	@echo "Creating fig8-budyko-camels..."
	@mamba run -p mamba_env/create_figs Rscript fig8-budyko-camels.R > /dev/null
	@echo "Saved to 'figures/fig8-budyko-camels.pdf'"

	@echo "Creating fig9-simulation-2019-22 & fig10-cyclical-sf..."
	@mamba run -p mamba_env/create_figs Rscript fig9-10-detailed-analysis.R > /dev/null
	@echo "Saved to 'figures/fig9-simulation-2019-22.pdf'"
	@echo "Saved to 'figures/fig10-cyclical-sf.pdf'"

	@echo "Creating fig11-cv-bootstrapping..."
	@mamba run -p mamba_env/create_figs Rscript fig11-cv-bootstrapping.R > /dev/null
	@echo "Saved to 'figures/fig11-cv-bootstrapping.png'"

clean:
	mamba remove -p mamba_env/create_figs --all
	@rm -r mamba_env figures #data