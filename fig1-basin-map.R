library(tidyverse)
library(sf)

options(
  readr.show_progress = FALSE,
  readr.show_col_types = FALSE,
  pillar.width = 1e6
)


nwrfc_domain <- st_read(
  "data/fig1-basin-map/NWRFC_boundary.shp"
)
nwrfc_camels <- st_read(
  "data/fig1-basin-map/CAMELS_NWRFC.shp"
)

calb_basins_to_plot <- st_read(
  "data/fig1-basin-map/NWRFC_Forecast_Basins_20241001.shp"
) |>
  filter(LID %in% c("FSSO3", "WGCM8", "SAKW1"))

forecast_points <- st_read(
  "data/fig1-basin-map/NWRFC_Forecast_Points_20240512.shp"
)

flowlines <- st_read(
  "data/fig1-basin-map/NWRFC_Flowlines.shp"
)
big_rivers <- flowlines |>
  filter(Name %in% c("Columbia River", "Snake River"))

states <- st_read(
  "data/fig1-basin-map/cb_2018_us_state_5m.shp"
) |>
  filter(
    NAME %in%
      c(
        "Washington",
        "Oregon",
        "Idaho",
        "Montana",
        "Wyoming",
        "California",
        "Nevada",
        "Utah"
      )
  )
countries <- "data/fig1-basin-map/world-administrative-boundaries.shp" |>
  st_read() |>
  filter(name %in% c("Canada"))

map <- ggplot() +
  geom_sf(data = states, fill = NA, color = gray(.8)) +
  geom_sf(data = countries, fill = NA, color = gray(.8)) +
  geom_sf(data = nwrfc_domain, fill = NA, linewidth = .8) +
  # geom_sf(data = basins, fill = NA) +
  geom_sf(data = nwrfc_camels, fill = grey(.7)) +
  geom_sf(aes(fill = LID), data = calb_basins_to_plot) +
  geom_sf(
    data = flowlines,
    fill = NA,
    color = rgb(0.55, 0.71, 0.8),
    linewidth = 0.25
  ) +
  geom_sf(
    data = big_rivers,
    fill = NA,
    color = rgb(0.55, 0.71, 0.8),
    linewidth = 0.75
  ) +
  geom_sf(data = forecast_points, color = rgb(0.41, 0.41, 0.41)) +
  # color = rgb(0.4, 0.6, 0.8)
  # geom_sf(aes(fill = LID), data = basins |> filter(substr(LID, 1, 5) %in% basins_to_plot)) +
  # geom_sf(aes(fill = LID), data = basins |> filter(name == "FSSSO3")) +
  # geom_sf(aes(fill = LID), data = basins |> filter(basins_to_plot %in% basins)) +
  coord_sf(xlim = c(-124.5, -110), ylim = c(41, 52.5)) +
  scale_fill_manual("", values = c("#337357", "#FFD23F", "#EE4266")) +
  theme_minimal() +
  theme(
    legend.position = "inside",
    legend.position.inside = c(.8, .8),
    panel.grid = element_blank()
  )
map
if (!dir.exists('figures')) dir.create('figures')
ggsave("figures/fig1-basin-map.png", width = 8, height = 8, dpi = 600)
