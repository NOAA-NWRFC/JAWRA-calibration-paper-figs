import::from(plotly, ggplotly)
import::from(readr, read_csv, cols)

##############
#Load and Format Data
###############

no_fa_bs_path = "bs_nofa.csv"
fa_bs_path = "bs_fa.csv"

no_fa_bs = read_csv(no_fa_bs_path, col_types = cols()) 
fa_bs = read_csv(fa_bs_path, col_types = cols()) 

bs_combo = rbind(no_fa_bs,fa_bs)

#change columns from character to factors
#master_degrade$type = as.factor(master_degrade$type)
bs_combo =  bs_combo |> mutate_if(is.character,as.factor)
bs_combo$metric = factor(bs_combo$metric,levels=c('nnse','npbias','R2','nkge'))

##############
#Plot figure
###############

g = ggplot() +
  geom_violin(data=bs_combo |> filter(fold == 'BS'),aes(x=forcing_adj,y=value),color='black',fill='white') +
  geom_jitter(data=bs_combo |> filter(fold != 'BS'),
              aes(x=forcing_adj,y=value,fill=fold),height=0,width=.05,shape=21,size=2) +
  facet_grid(rows = vars(metric), cols = vars(LID), scales = 'free_y')+
  ylab(expression(paste("Metric Score")))+xlab('') +
  scale_x_discrete(labels = c("Forcing Adjustment" = "Forcing\nAdjustment",
                              "No Forcing Adjustment" = "No Forcing\nAdjustment")) +
  theme_minimal() +
  labs(fill = "CV-Fold:") +
  theme(panel.border = element_rect(colour = "black", fill=NA, linewidth=1),
        axis.ticks.x.bottom=element_line(colour = "black", linewidth=.5),
        plot.title = element_text(hjust = 0.5),
        text = element_text(size = 12),
        legend.position = "bottom")

ggsave("bs_fa_compare.png",g,width = 9, height = 6,bg = 'white')