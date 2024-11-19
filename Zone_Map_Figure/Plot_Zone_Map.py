#!/usr/bin/python3

"""

Creates Basin zone maps based on given input of nwslid and number of basins 

Written by Geoffrey Walters PE, 11/15/24

"""


#Debugging
#import pdb; pdb.set_trace()

#################Library#################

import os, time, sys, gc,glob,argparse
import numpy as np, pandas as pd, matplotlib.pyplot as plt
import xarray as xr, rioxarray
import matplotlib.patches as mpatches, matplotlib.colors as mcolors
from argparse import ArgumentParser
from matplotlib.font_manager import FontProperties
from matplotlib import ticker
import geopandas as gpd, cartopy.crs as ccrs
import contextily as ctx
#import cartopy.io.img_tiles as cimgt

#################Argument Declaration#################

desc = "Creates Basin zone maps based on given input of nwslid and number of basins"
parser = argparse.ArgumentParser(description=desc,formatter_class=argparse.ArgumentDefaultsHelpFormatter)
# Add an argument with a default value
parser.add_argument('-z','--zones', dest="zones", default=int(2),nargs =1,type = int, help='Number of zones to plot')
parser.add_argument('-l','--nwslid', dest="lid", default=['WGCM8'],nargs ='+', help='NWLID of basin to plot')
parser.add_argument('-a','--api', dest="api", type=str, help='stadiamaps api')
args = parser.parse_args()

Number_of_zones=args.zones
recalb_lids=args.lid
maps_api = args.api

if not maps_api:
    raise Exception("Must include StadiaMaps API as argument [-a, --api]")
else:
    #configure api
    provider = ctx.providers.Stadia.StamenTerrainBackground (api_key=maps_api)
    # Update the provider URL to include your API key
    provider["url"] = provider["url"] + "?api_key={api_key}"

#################Load Data#################

folder=os.getcwd()
version='A'

cluster_grids_1_zones=xr.open_mfdataset(os.path.join(folder,'zone-cluster-data','Basin_'+version+'_Cluster_Results-1_Zones_20240511.nc'), combine='nested', concat_dim='time', parallel=True)
cluster_grids_2_zones=xr.open_mfdataset(os.path.join(folder,'zone-cluster-data','Basin_'+version+'_Cluster_Results-2_Zones_20240511.nc'), combine='nested', concat_dim='time', parallel=True)
cluster_grids_3_zones=xr.open_mfdataset(os.path.join(folder,'zone-cluster-data','Basin_'+version+'_Cluster_Results-3_Zones_20240511.nc'), combine='nested', concat_dim='time', parallel=True)

lid_key=pd.read_csv(os.path.join(folder,'zone-cluster-data','Basin_'+version+'_LID_Key.csv'),index_col='LID')

cluster_var_grid=xr.open_mfdataset(os.path.join(folder,'zone-cluster-data','Cluster_Grids_Merged.nc'), combine='nested', concat_dim='time', parallel=True)

basin_sf=gpd.read_file(os.path.join(folder,'shapefile','NWRFC_Forecast_Basins_20241001.shp'))
pt_sf=gpd.read_file(os.path.join(folder,'shapefile','NWRFC_Forecast_Points_20240512.shp'))

if version=='A':
    sf_path = glob.glob(os.path.join(folder,'shapefile',str(Number_of_zones)+'_Zones','NWRFC_Forecast_Zones_A*.shp'))[0]
elif version=='B':
    sf_path = glob.glob(os.path.join(folder,'shapefile',str(Number_of_zones)+'_Zones','NWRFC_Forecast_Zones_B*.shp'))[0]
else:
    raise Exception("Input version should be a or b")
zone_sf=gpd.read_file(sf_path)

cluster_grids=cluster_var_grid
if Number_of_zones == 1:
    cluster_grids['zone']=cluster_grids_1_zones.zone
elif Number_of_zones == 2:
    cluster_grids['zone']=cluster_grids_2_zones.zone   
elif Number_of_zones == 3:
    cluster_grids['zone']=cluster_grids_3_zones.zone
else:
    raise Exception("Invalid Number_of_zones varible assignment")

    
################Build Figure#################

#Color Lookup
cmap = plt.colormaps.get_cmap('viridis').resampled(3)

#Loop through each location
for lid in recalb_lids:
    
    #Get the key value to extract the grids from the xarray
    key=lid_key.loc[lid,['key']].values

    #Extract the grids
    lid_grids=cluster_grids.where(cluster_grids.zone.round(0)==key)

    #Convert the xarray to a dataframe and format
    cluster_df=lid_grids.to_dataframe().dropna(how='all')
    cluster_df.reset_index(inplace=True)
    cluster_df.set_index(['latitude', 'longitude'],inplace=True) 
    cluster_xr=cluster_df.to_xarray()
    cluster_xr.rio.write_crs("epsg:4326", inplace=True)
    cluster_xr=cluster_xr.rio.reproject("EPSG:3857")
    
    #Get shapefile of basin and forecast point
    lid_basin_sf=basin_sf.loc[basin_sf.LID==lid].to_crs(epsg=3857)
    lid_pt_sf=pt_sf.loc[pt_sf.LID==lid].to_crs(epsg=3857)
    
    ###Create the plots###
    #Format the figure space
    fig = plt.figure(figsize=(20, 10), dpi= 80, facecolor='w', edgecolor='k')
     
    #Add two subplots and format relative size
    gs = fig.add_gridspec(4, 10)
        
    #Add map
    proj=ccrs.Mercator.GOOGLE
    ax_map = fig.add_subplot(gs[:4,:4],projection=proj)
    
    #Get map extents
    basin_extents=lid_basin_sf.geometry.bounds
    map_extent=(basin_extents.minx.min(),basin_extents.maxx.max(),
                basin_extents.miny.min(),basin_extents.maxy.max())
    ax_map.set_extent(map_extent,proj)
    
    ctx.add_basemap(ax_map, source=provider)
    
    cluster_xr.zone.plot.imshow(vmin=key[0]+.1,vmax=key[0]+.3,add_colorbar=False,ax=ax_map,cmap='viridis',zorder=2.5,alpha=.50)
      
    #get zone names
    cluster_df['zone_names']=lid+'.'+cluster_df.zone.astype('str').str.split('.').str[-1]
    zone_names=cluster_df.zone_names.sort_values().unique()
    
    #Add Basin delineation and forecast point to map
    lid_basin_sf.plot(ax=ax_map,facecolor='none',edgecolor='black',zorder=5)
    lid_pt_sf.plot(ax=ax_map,facecolor='yellow',edgecolor='black',linewidth=2.5,markersize=50,zorder=10)
    
    
    #Add Axis title
    ax_map.set_title('Map',fontdict={'fontsize': 20})
    
    #create legend
    patches=[]
    for i, zone in enumerate(zone_names):
        patches.append(mpatches.Patch(color=cmap(i), label=zone))
    ax_map.legend(handles=patches,loc='best',fontsize=16)
    
    
    #######################################################################################################
    
    
    cluster_df['zone_names']=lid+'.'+cluster_df.zone.astype('str').str.split('.').str[-1]
    
    #Create blank dataframes to populate with zone data
    ptps_df=pd.DataFrame()
    precip_df=pd.DataFrame()
    swe_df=pd.DataFrame()
    elev_df=pd.DataFrame()
    efc_df=pd.DataFrame()
    ksat_df=pd.DataFrame()

    #loop through each zone (make sure to move from smallest to largest)
    for zone in cluster_df.zone_names.sort_values().unique():

        #for each zone concat that zones data onto the existing dataframe
        ptps_df=pd.concat([ptps_df,cluster_df.loc[cluster_df.zone_names==zone,['PTPS']].multiply(100)],axis=1)
        precip_df=pd.concat([precip_df,cluster_df.loc[cluster_df.zone_names==zone,['Precip']].multiply(0.0393701)],axis=1)
        swe_df=pd.concat([swe_df,cluster_df.loc[cluster_df.zone_names==zone,['SWE']].multiply(0.0393701)],axis=1)
        elev_df=pd.concat([elev_df,cluster_df.loc[cluster_df.zone_names==zone,['Elev']].multiply(3.28084)],axis=1)
        efc_df=pd.concat([efc_df,cluster_df.loc[cluster_df.zone_names==zone,['EFC']]],axis=1)
        ksat_df=pd.concat([ksat_df,cluster_df.loc[cluster_df.zone_names==zone,['Ksat']]],axis=1)
        
    #Update column naming convention to all the dataframes
    ptps_df.columns=cluster_df.zone_names.sort_values().unique()
    precip_df.columns=cluster_df.zone_names.sort_values().unique()
    swe_df.columns=cluster_df.zone_names.sort_values().unique()
    elev_df.columns=cluster_df.zone_names.sort_values().unique()
    efc_df.columns=cluster_df.zone_names.sort_values().unique()
    ksat_df.columns=cluster_df.zone_names.sort_values().unique()

    #Create a dummy axis to create a common y axis label
    ax_dummy = fig.add_subplot(gs[:4,4:])
    # Turn off axis lines and ticks of the big subplot
    ax_dummy.spines['top'].set_color('none')
    ax_dummy.spines['bottom'].set_color('none')
    ax_dummy.spines['left'].set_color('none')
    ax_dummy.spines['right'].set_color('none')
    ax_dummy.tick_params(labelcolor='w', top=False, bottom=False, left=False, right=False)
    ax_dummy.yaxis.set_label_position("right")
    ax_dummy.set_title('Spatial Variability of Parameters used to Delineate Zones',
                       fontdict={'fontsize': 18},fontweight="bold",pad=25)
    
    #Create subplots for each gridded data utilized for the kmean clustering
    ptps_ax=fig.add_subplot(gs[:2,4:6])
    precip_ax=fig.add_subplot(gs[:2,6:8])
    swe_ax=fig.add_subplot(gs[:2,8:])
    elev_ax=fig.add_subplot(gs[2:4,4:6])
    efc_ax=fig.add_subplot(gs[2:4,6:8])
    ksat_ax=fig.add_subplot(gs[2:4,8:])
    
    #Boxplot Color properties
    boxprops = dict(color="black",linewidth=1.5)
    medianprops = dict(color="black",linewidth=1.5)
    whiskerprops = dict(color="black")
    
    #Populate the subplots with boxplots
    ptps_bp,ptps_props=ptps_df.boxplot(ax=ptps_ax, showfliers=False,patch_artist = True, return_type='both',
                                       boxprops=boxprops,medianprops=medianprops,whiskerprops=whiskerprops)
    precip_bp,precip_props=precip_df.boxplot(ax=precip_ax, showfliers=False,patch_artist = True, return_type='both',
                                       boxprops=boxprops,medianprops=medianprops,whiskerprops=whiskerprops)
    swe_bp,swe_props=swe_df.boxplot(ax=swe_ax, showfliers=False,patch_artist = True, return_type='both',
                                       boxprops=boxprops,medianprops=medianprops,whiskerprops=whiskerprops)
    elev_bp,elev_props=elev_df.boxplot(ax=elev_ax, showfliers=False,patch_artist = True, return_type='both',
                                       boxprops=boxprops,medianprops=medianprops,whiskerprops=whiskerprops)
    efc_bp,efc_props=efc_df.boxplot(ax=efc_ax, showfliers=False,patch_artist = True, return_type='both',
                                       boxprops=boxprops,medianprops=medianprops,whiskerprops=whiskerprops)
    ksat_bp,ksat_props=ksat_df.boxplot(ax=ksat_ax, showfliers=False,patch_artist = True, return_type='both',
                                       boxprops=boxprops,medianprops=medianprops,whiskerprops=whiskerprops)

    for props in [ptps_props,precip_props,swe_props,elev_props,efc_props,ksat_props]:
        for i, box in enumerate(props['boxes']):
            box.set(alpha=.5, facecolor=cmap(i))
    
    #Remove x axis grid
    ptps_ax.grid(True, which='major', axis='y',ls=':')
    precip_ax.grid(True, which='major', axis='y',ls=':')
    swe_ax.grid(True, which='major', axis='y',ls=':')
    elev_ax.grid(True, which='major', axis='y',ls=':')
    efc_ax.grid(True, which='major', axis='y',ls=':')
    ksat_ax.grid(True, which='major', axis='y',ls=':')
    
    #Share X labels
    
    ptps_ax.set_xticklabels([])
    precip_ax.set_xticklabels([])
    swe_ax.set_xticklabels([])
    
    #Rotate the x axis label
    elev_ax.tick_params(axis='x',labelrotation=22,labelsize=14)
    efc_ax.tick_params(axis='x', labelrotation=22,labelsize=14)
    ksat_ax.tick_params(axis='x',labelrotation=22,labelsize=14)
    
    #Set the y axis to integer and change font size
    ptps_ax.tick_params(axis='y',labelsize=14,direction="in", pad=-30,length=0)
    ptps_ax.locator_params(axis="y", integer=True, tight=True)
    elev_ax.tick_params(axis='y',labelsize=14,direction="in", pad=-40,length=0)
    elev_ax.yaxis.set_major_formatter(ticker.StrMethodFormatter('{x:,.0f}'))
    elev_ax.locator_params(axis="y", integer=True, tight=True)
    precip_ax.tick_params(axis='y',labelsize=14,direction="in", pad=-30,length=0)
    precip_ax.locator_params(axis="y", integer=True, tight=True)
    swe_ax.tick_params(axis='y',labelsize=14,direction="in", pad=-30,length=0)
    swe_ax.locator_params(axis="y", integer=True, tight=True)
    efc_ax.tick_params(axis='y',labelsize=14,direction="in", pad=-30,length=0)
    efc_ax.locator_params(axis="y", integer=True, tight=True)
    ksat_ax.tick_params(axis='y',labelsize=14,direction="in", pad=-30,length=0)
    ksat_ax.locator_params(axis="y", integer=True, tight=True)

    #Add titles
    ptps_ax.set_title('PTPS',fontdict={'fontsize': 14})
    precip_ax.set_title('Precip',fontdict={'fontsize': 14})
    swe_ax.set_title('SWE',fontdict={'fontsize': 14})
    elev_ax.set_title('Elev',fontdict={'fontsize': 14})
    efc_ax.set_title('EFC',fontdict={'fontsize': 14})
    ksat_ax.set_title('Ksat',fontdict={'fontsize': 14})
    
    #Set the hspace to prevent overlap
    fig.subplots_adjust(hspace = .5)


    #default_font_size = fig.rcParams['font.size']

    
    #Set tight layout
    fig.tight_layout

    #Save figure 
    fig.savefig(os.path.join(folder,lid +'_'+str(Number_of_zones)+'-Zone_Kmean_Map.png'))
 
    plt.clf()
    plt.close('all')
    print(lid+' processed')