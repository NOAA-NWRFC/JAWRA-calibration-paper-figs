# NWRFC calibration paper figures

Supporting data and code for reproducing figures in:

Walters, G., Bracken, C., et al., "A comprehensive calibration framework for the Northwest River Forecast Center." Journal of the American Water Resources Association (JAWRA), accepted for publication in 2026. [Preprint](https://eartharxiv.org/repository/view/8993/)

Get the data for the figures: [![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.18845515.svg)](https://doi.org/10.5281/zenodo.18845515)

## Quick start

### 1. Install mamba and get a Stadia Maps API key
- Install mamba (or micromamba) so `mamba` is available on your PATH.
- Create a Stadia Maps account and generate an API key ([Link](https://docs.stadiamaps.com/authentication/#api-keys)).

### 2. Configure local environment variables

Copy the tracked template and update the API key:

```bash
cp .env.example .env
```

Edit `.env` and set:

```bash
STADIA_MAPS_API_KEY=<your_api_key>
```

`zenodo_id` is set by default and points to the published paper dataset.

### 3. Download data and create the environment

```bash
make setup
```

This command:

- validates your Stadia Maps API key
- validates the Zenodo record ID
- creates or updates the local mamba environment
- downloads and unpacks the Zenodo zip contents into `data/`

### 4. Recreate figures

```bash
make figures
```

Outputs are written to `figures/`.

## Cleanup

Remove downloaded data, generated figures, and the local mamba environment:

```bash
make clean
```

## Legal disclaimer

This is a scientific product and does not represent official communication from NOAA or the U.S. Department of Commerce. All code is provided "as is."

See full disclaimer: [NOAA GitHub Policy](https://github.com/NOAAGov/Information)
\
 \
 \
<img src="https://www.weather.gov/bundles/templating/images/header/header.png" alt="NWS-NOAA Banner">

[National Oceanographic and Atmospheric Administration](https://www.noaa.gov) | [National Weather Service](https://www.weather.gov/) | [Northwest River Forecast Center](https://www.nwrfc.noaa.gov/rfc/)
