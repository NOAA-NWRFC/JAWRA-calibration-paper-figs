library(tidyverse)
import::from(hydroGOF, KGE, NSE, pbias)
import::from(xtable, xtable, print.xtable)
import::from(ggthemes, colorblind_pal)

options(
  readr.show_progress = FALSE,
  readr.show_col_types = FALSE,
  pillar.width = 1e6,
  dplyr.summarise.inform = FALSE
)

data_dir <- "nwrfc-calibration-paper-data/CAMELS_all_locations/2zone"
calb_dir <- "results_por_01"

basins <- list.files(data_dir)
# usgs_locations <- read_csv("data/imputation/202005_usgs_locations.csv") |>
#   filter(lid %in% basins)

calb_data <- basins |>
  map(function(basin) {
    read_csv(file.path(data_dir, basin, calb_dir, "optimal_daily.csv")) |>
      mutate(basin = basin) |>
      rename(obs = flow_cfs, sim = sim_flow_cfs) |>
      mutate(
        date_chr = sprintf("%s-%02d-%02d", year, month, day),
        date = fast_strptime(date_chr, "%Y-%m-%d")
      )
  }) |>
  bind_rows()

calb_data_long <- calb_data |>
  pivot_longer(c(obs, sim), values_to = "flow", names_to = "data_type")

# overall metric table
calb_data |>
  group_by(basin) |>
  summarise(kge = KGE(sim, obs), nse = NSE(sim, obs), .groups = "drop") |>
  xtable(digits = 3) |>
  print.xtable(include.rownames = FALSE)


par_limits <- basins |>
  map(function(basin) {
    read_csv(file.path(data_dir, basin, "pars_limits.csv")) |>
      mutate(basin = basin)
  }) |>
  bind_rows()

pars_optimal <- basins |>
  map(function(basin) {
    read_csv(file.path(data_dir, basin, calb_dir, "pars_optimal.csv")) |>
      mutate(basin = basin)
  }) |>
  bind_rows()

# zones <- optimal_pars |>
#   pull(zone) |>
#   unique() |>
#   as.character() |>
#   sort() |>
#   str_subset("-")

states_optimal_6h <- basins |>
  map(function(basin) {
    read_csv(file.path(data_dir, basin, calb_dir, "optimal_states_6hr.csv"), show = FALSE)[-(1:(366 * 4)), ] |>
      mutate(datetime = ISOdatetime(year, month, day, 0, 0, 0)) %>%
      pivot_longer(-c(datetime, year, month, day, hour), names_sep = "_", names_to = c("variable", "zonei")) %>%
      mutate(
        wyear = ifelse(month >= 10, year + 1, year),
        type = "adjusted"
      ) %>%
      pivot_wider(id_cols = c(datetime, year, month, day, hour, zonei, wyear, type), names_from = variable)
  }, .progress = TRUE) |>
  bind_rows()

#optimal_states_6h <- optimal_states_6h_ %>%
#  inner_join(data.frame(zone = zones, zonei = as.character(1:n_zones)), by = "zonei")


budyko <- function(x, pars) {
  scf <- pars[name == "scf"] |>
    select(zone, value) |>
    rename(scf = value) |>
    as_tibble()
  # for(z in sort(unique(x$zone))){
  b <- x %>%
    mutate(wyear = ifelse(month >= 10, year + 1L, year)) %>%
    inner_join(scf, by = "zone") %>%
    group_by(zone, type) %>%
    mutate(map2 = map * (1 - ptps) + map * ptps * scf) %>%
    summarise(pet = mean(pet), map = mean(map2), aet = mean(aet), .groups = "drop") %>%
    mutate(x = pet / map, y = aet / map)

  bx <- seq(0, max(max(b$x), 2), by = 0.05)
  by <- (bx * tanh(1 / bx) * (1 - exp(-bx)))^(1 / 2)

  # p = ggplot(b %>% filter(zone==z))+
  p <- ggplot(b) +
    geom_line(aes(x, y), data = data.frame(x = c(0, 1), y = c(0, 1))) +
    geom_hline(aes(yintercept = 0.997)) +
    geom_vline(aes(xintercept = 1), linetype = "dashed") +
    geom_line(aes(x, y), data = data.frame(x = bx, y = by), linetype = "dotted") +
    geom_point(aes(x, y, shape = type, color = zone)) +
    scale_shape_manual("", values = c(19, 1)) +
    # scale_color_discrete()+
    # xlim(c(0,2))+ylim(c(0,1))+
    xlab("Dryness Index (PET/P)") +
    ylab("Evaporative Index (AET/P)") +
    theme_minimal() +
    geom_text(aes(x, y, label = label), data = data.frame(x = 0.5, y = 0.5, label = "Energy Limit"), angle = 45, vjust = -1) +
    geom_text(aes(x, y, label = label), data = data.frame(x = 0.25, y = .98, label = "Water Limit"), vjust = 1) +
    geom_text(aes(x, y, label = label), data = data.frame(x = 0.5, y = 0.05, label = "Energy Limited")) +
    geom_text(aes(x, y, label = label), data = data.frame(x = 1.5, y = 0.05, label = "Water Limited")) +
    coord_equal(expand = F, clip = "off")
  # coord_cartesian(xlim=c(0,1.05*max(b$x)))+
  print(p)
  # }
}
