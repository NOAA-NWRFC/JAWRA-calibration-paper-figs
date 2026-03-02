.ONESHELL:
.SHELLFLAGS = -eu -o pipefail -c

# Load environment variables if present; setup target enforces required values.
-include .env
export

ENV_PREFIX := mamba_env/create_figs
ENV_YML := create_figs.yml
SETUP_STAMP := .setup-complete
DATA_ZIP := data/nwrfc-calibration-paper-data.zip

.PHONY: setup clean figures check-env

check-env:
	@test -f .env || (echo "Error: .env not found. Copy .env.example to .env and set STADIA_MAPS_API_KEY."; exit 1)
	@test -n "$(STADIA_MAPS_API_KEY)" || (echo "Error: STADIA_MAPS_API_KEY is empty in .env"; exit 1)
	@test "$(STADIA_MAPS_API_KEY)" != "your_key_here" || (echo "Error: STADIA_MAPS_API_KEY is still set to placeholder value"; exit 1)
	@test -n "$(zenodo_id)" || (echo "Error: zenodo_id is empty in .env"; exit 1)

$(SETUP_STAMP): $(ENV_YML) | check-env
	@echo "Checking Stadia Maps API key..."
	@curl --silent --fail \
		"https://tiles.stadiamaps.com/tiles/alidade_smooth/1/1/1.png?api_key=$(STADIA_MAPS_API_KEY)" \
		-I > /dev/null || \
		(echo "Error: Invalid STADIA_MAPS_API_KEY"; exit 1)
	@echo "Validating Zenodo ID ($(zenodo_id))..."
	@curl --silent --fail \
		"https://zenodo.org/api/records/$(zenodo_id)" \
		-I > /dev/null || (echo "Error: Zenodo ID '$(zenodo_id)' not found or private"; exit 1)

	@mkdir -p mamba_env data figures
	@echo "Creating/updating mamba environment..."
	if [ -d "$(ENV_PREFIX)" ]; then \
		mamba env update -p "$(ENV_PREFIX)" -f "$(ENV_YML)" --prune; \
	else \
		mamba env create -p "$(ENV_PREFIX)" -f "$(ENV_YML)"; \
	fi

	@echo "Pulling Zenodo Record..."
	mamba run -p "$(ENV_PREFIX)" zenodo_get "$(zenodo_id)" -o ./data
	@test -f "$(DATA_ZIP)" || (echo "Error: Expected $(DATA_ZIP) after download"; exit 1)
	@rm -rf data/.tmp_unzip
	@mkdir -p data/.tmp_unzip
	@echo "Unzipping Zenodo Record..."
	@unzip -q -o "$(DATA_ZIP)" -d data/.tmp_unzip
	@test -d data/.tmp_unzip/nwrfc-calibration-paper-data || (echo "Error: Unexpected zip structure"; exit 1)
	@cp -R data/.tmp_unzip/nwrfc-calibration-paper-data/. data/
	@rm -rf data/.tmp_unzip
	@touch "$(SETUP_STAMP)"

setup: $(SETUP_STAMP)
	@echo "Setup complete."

figures: $(SETUP_STAMP)
	@echo "Creating fig1-basin-map..."
	@mamba run -p "$(ENV_PREFIX)" Rscript fig1-basin-map.R > /dev/null
	@echo "Saved to 'figures/fig1-basin-map.png'"

	@echo "Creating fig5-zone-map..."
	@STADIA_MAPS_API_KEY="$(STADIA_MAPS_API_KEY)" mamba run -p "$(ENV_PREFIX)" python fig5-zone-map.py > /dev/null
	@echo "Saved to 'figures/fig5-zone-map.png'"

	@echo "Creating fig7-cdf-metric-summary..."
	@mamba run -p "$(ENV_PREFIX)" Rscript fig7-cdf-metric-summary.R > /dev/null
	@echo "Saved to 'figures/fig7-cdf-metric-summary.pdf'"

	@echo "Creating fig8-budyko-camels..."
	@mamba run -p "$(ENV_PREFIX)" Rscript fig8-budyko-camels.R > /dev/null
	@echo "Saved to 'figures/fig8-budyko-camels.pdf'"

	@echo "Creating fig9-simulation-2019-22 & fig10-cyclical-sf..."
	@mamba run -p "$(ENV_PREFIX)" Rscript fig9-10-detailed-analysis.R > /dev/null
	@echo "Saved to 'figures/fig9-simulation-2019-22.pdf'"
	@echo "Saved to 'figures/fig10-cyclical-sf.pdf'"

	@echo "Creating fig11-cv-bootstrapping..."
	@mamba run -p "$(ENV_PREFIX)" Rscript fig11-cv-bootstrapping.R > /dev/null
	@echo "Saved to 'figures/fig11-cv-bootstrapping.png'"

clean:
	@if [ -d "$(ENV_PREFIX)" ]; then mamba remove -p "$(ENV_PREFIX)" --all; fi
	@rm -rf mamba_env figures data "$(SETUP_STAMP)"
