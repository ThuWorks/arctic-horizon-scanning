library("geodata")
library("terra")
#library("dynRB")
library("rgbif")
library("factoextra")
library("ggplot2")
library("dplyr")
#library("sf")
library("grateful")

cite_packages(citation.style = "APA7th")


#Get bio variables from worldClim
bioVars = worldclim_global(var="bio", 10, "resources", version="2.1")

#Check bioVars properties 
bioVars
names(bioVars)
ext(bioVars)
crs(bioVars, proj = T, describe = T)
units(bioVars)

#annual temperature [[1]]
bioVars[[1]]
plot(bioVars[[1]])

# ------------------------------------ CAVM shape ------------------------------------------------------------

#Write SpatVector file of cavm shape
# Citation:
# CAVM Team. 2003. Circumpolar Arctic Vegetation Map. (1:7,500,000 scale), Conservation of Arctic Flora and Fauna (CAFF) 
# Map No. 1. U.S. Fish and Wildlife Service, Anchorage, Alaska. ISBN: 0-9767525-0-6, ISBN-13: 978-0-9767525-0-9

cavm = vect("resources/Cavm2003/aga_circumpolar_geobotanical_2003.shp")
crs(cavm, proj = T, describe = T)
plot(cavm)

#Change projection to same as bioVars
cavm = terra::project(cavm, "+proj=longlat +lat_0=90 +lon_0=180 +x_0=0 +y_0=0 +datum=WGS84 +no_defs +units=m")
crs(cavm, proj = T, describe = T)
plot(cavm)

##Separate Arctic into regions level 3 by TDWG
tdwgl3 = vect("resources/TDWGLevel3/level3.shp")
crs(tdwgl3, proj = T, describe = T)
plot(tdwgl3)

#Crop Regions into Arctic
cropAR = crop(tdwgl3, cavm)
plot(cropAR)
cavmRegions = mask(cropAR, cavm)
plot(cavmRegions)
plot(cavm, add =T) #Here it seems some information is lost

#Crop WorldClim data to Arctic CAVM
crop = crop(bioVars, cavm)
#plot(crop)
bioVarsMask = mask(crop, cavm)
plot(bioVarsMask)

#Check out min and max values
terra::minmax(bioVarsMask)

#Check properties and make into dataframe
bioVarsMask
bioVarsMask_df = as.data.frame(bioVarsMask)

#Bio variables explanation:
# BIO1 = Annual Mean Temperature
# BIO2 = Mean Diurnal Range (Mean of monthly (max temp - min temp))
# BIO3 = Isothermality (BIO2/BIO7) (×100)
# BIO4 = Temperature Seasonality (standard deviation ×10
# BIO5 = Max Temperature of Warmest Month
# BIO6 = Min Temperature of Coldest Month
# BIO7 = Temperature Annual Range (BIO5-BIO6)
# BIO8 = Mean Temperature of Wettest Quarter
# BIO9 = Mean Temperature of Driest Quarter
# BIO10 = Mean Temperature of Warmest Quarter
# BIO11 = Mean Temperature of Coldest Quarter
# BIO12 = Annual Precipitation
# BIO13 = Precipitation of Wettest Month
# BIO14 = Precipitation of Driest Month
# BIO15 = Precipitation Seasonality (Coefficient of Variation)
# BIO16 = Precipitation of Wettest Quarter
# BIO17 = Precipitation of Driest Quarter
# BIO18 = Precipitation of Warmest Quarter
# BIO19 = Precipitation of Coldest Quarter

#----------------------------------------------- PCA ---------------------------------------------

## PCA of bioVars in the Arctic
gPca <- prcomp(bioVarsMask_df, center = TRUE, scale. = TRUE)
##summary describes which principal component accounts for most information
#Use summary to find most important PCs according to proportion of variance
summary(gPca)

scores = as.data.frame(gPca$x)
head(scores[1:4])

##rotation describes which variable accounts for the most information
#Use rotation to find what bio Variable describes the most important PCs best
bioVarsLoadings = gPca$rotation
bioVarsLoadings = as.data.frame(bioVarsLoadings)
names(bioVarsLoadings)

#find biggest absolute values in the different components
bioVarsLoadings$PC1
#find the biggest absolute value in PC1
max(abs(bioVarsLoadings$PC1))
#Find the name of biggest absolute value in PC1
rownames(bioVarsLoadings)[which.max(abs(bioVarsLoadings$PC1))]

#Find max abs names and values for all PCs and put it in a dataframe with all values given
bioVarsMaxAbsPC = do.call(cbind, lapply(seq_along(bioVarsLoadings), function(i) {
  x = bioVarsLoadings[[i]]
  max_i = order(abs(x), decreasing = T)[1:19]
  setNames(data.frame(rownames(bioVarsLoadings)[max_i], abs(x[max_i]), abs( x[max_i]) / sum( abs(x) )*100 ), 
           c(colnames(bioVarsLoadings)[i], paste0(colnames(bioVarsLoadings)[i], "_abs (∝)"), paste0(colnames(bioVarsLoadings)[i], "_pct (%)")))
}))

write.csv(bioVarsMaxAbsPC, "outputs/most Important BioVariables.csv", row.names = F)

plot(gPca)

#loadings only
fviz_pca_var(gPca, 
             axes = c(1, 2 ),
             col.var = "contrib",
             gradient.cols = c("#E41A1C", "#377EB8", "#4DAF4A", "#984EA3"),
             repel = T,
             )


fviz_pca_var(gPca, 
             axes = c(3, 4),
             col.var = "contrib",
             gradient.cols = c("#E41A1C", "#377EB8", "#4DAF4A", "#984EA3"),
             repel = T,
)

#a test to visualize it simpler
fviz_pca_var(gPca, labelsize = 4, repel = TRUE,
             select.var = list(cos2 = 0.75), col.var = "contrib", gradient.cols = c("#E41A1C", "#377EB8", "#4DAF4A", "#984EA3"))

#Make it 3D

# Once you have it oriented correctly, run this code:
M <- par3d("userMatrix")
dput(M)

# You'll get a structure as output. Then start your R Markdown document with something like this:
library(rgl)
options(rgl.useNULL = TRUE)
M <- structure(...) # Replace the ... with the structure you got as output

# In each code chunk that produces a plot, write code like this:
plot3d(gPca$rotation[,1:19])
text3d(gPca$rotation[,1:3], texts=rownames(gPca$rotation), col="red", cex=0.8)
coords <- NULL
for (i in 1:nrow(gPca$rotation)) {
  coords <- rbind(coords, rbind(c(0,0,0), gPca$rotation[i,1:3]))
}
lines3d(coords, col="red", lwd=1)
par3d(userMatrix = M)
rglwidget()

## ----------------------------------------------- Gbif --------------------------------------------------------------
#The download from GBIF will be changed at a later date in order to include a whole lot more data

#Check extent of cavm
plot(cavm)
lines(ext(cavm))

#convert cavm extent to WKT string
ext(cavm)[1]
ext(cavm)[3]
cavmWKT = sprintf("POLYGON ((%f %f, %f %f, %f %f, %f %f, %f %f))", ext(cavm)[1], ext(cavm)[3], ext(cavm)[1], ext(cavm)[4], 
                  ext(cavm)[2], ext(cavm)[4], ext(cavm)[2], ext(cavm)[3], ext(cavm)[1], ext(cavm)[3])
cavmWKT
#Something happened so the sprintf representation did not work. Insetad all data outside this polygon was downloaded. 
#The version below is from the GBIF map site by using the sprintf polygon. The site edited the string into the following:
cavmWKT = "POLYGON((-169.50929 55.79623,172.06954 55.79623,172.06954 83.62742,-169.50929 83.62742,-169.50929 55.79623))"
#Prepare GBIF keys
taxonName = "Tracheophyta"
taxonKey = name_backbone(taxonName)$usageKey
#Test data download
occ_download_prep(pred("taxonKey", taxonKey), 
                  pred("hasGeospatialIssue", FALSE),
                  pred("hasCoordinate", TRUE),
                  pred("geometry", cavmWKT),
                  pred("occurrenceStatus","PRESENT"),
                  pred_in("basisOfRecord", "Occurrence"),
                  format = "SIMPLE_CSV"
                  )

#Download the data 
vascPlants = occ_download(pred("taxonKey", taxonKey), 
                          pred("hasGeospatialIssue", FALSE),
                          pred("hasCoordinate", TRUE),
                          pred("geometry", cavmWKT),
                          pred("occurrenceStatus","PRESENT"),
                          pred_in("basisOfRecord", "Occurrence"),
                          format = "SIMPLE_CSV"
                          )
# check status
occ_download_wait(vascPlants)

#get the download Data and import to create dataframe
vascPlants_file = occ_download_get(vascPlants, path = "resources", overwrite = T)
vascPlants_df = occ_download_import(vascPlants_file, path = "resources" )


## test to see which branch includes NA
gbif_test_na_branch = vascPlants_df %>% 
  group_by(kingdom, phylum, class, order, family, genus) %>% 
  summarise(species = species)

apply(gbif_test_na_branch, 2, function(x) 
  any(is.na(x)) | any(is.infinite(x)) 
  )

## check if any lat or long are NA
with(vascPlants_df, any(is.na(decimalLatitude)))
with(vascPlants_df, any(is.na(decimalLongitude)))
with(vascPlants_df, any(decimalLongitude < -169.50929 | decimalLongitude > 172.06954))
with(vascPlants_df, any(decimalLatitude < 55.79623 | decimalLatitude > 83.62742))

#Make into spatial points
vascPlantsLongLat = cbind(vascPlants_df$decimalLongitude, vascPlants_df$decimalLatitude)
sp_occ = vect(vascPlantsLongLat, vascPlants_df, type="points", crs = "+proj=longlat +lat_0=90 +lon_0=180 +x_0=0 +y_0=0 +datum=WGS84 +no_defs +units=m")
sp_occ

#test plot
plot(cavm)
plot(sp_occ, add=T, col="red")

#Crop GBIF points to Arctic CAVM
#take time
startTime = Sys.time()

cropGBIF = crop(sp_occ, cavm)
plot(cropGBIF)
sp_occMask = mask(cropGBIF, cavm)
plot(sp_occMask)

#Check endTime
endTime = Sys.time()
#print the time it took to complete the function
print(ednTime - startTime)

#plot cropped data
plot(cavm)
plot(sp_occMask, add=T, col="red")

#Make corpped data into dataframe from 41 900 entries to 10 096 entries
sp_occCavm_df = as.data.frame(sp_occMask)

#uniqe number of classes
n_distinct(sp_occCavm_df$class)
#uniqe number of orders
n_distinct(sp_occCavm_df$order)
#uniqe number of families
n_distinct(sp_occCavm_df$family)
#uniqe number of genuses
n_distinct(sp_occCavm_df$genus)
#uniqe number of species
n_distinct(sp_occCavm_df$species)

#check for empty strings or NA
any(unique(sp_occCavm_df$species == ""))
any(is.na(unique(sp_occCavm_df$species)))

#List of species occurrences in the CAVM
cavmSpList = as.data.frame(unique(sp_occCavm_df$species))
cavmSpList = cavmSpList[!(cavmSpList$`unique(sp_occCavm_df$species)` == ""), ]
cavmSpList = as.data.frame(cavmSpList)
cavmSpList = `colnames<-`(cavmSpList, "species")

#Check for empty strings on new dataframe
any(cavmSpList == "")

#write species list to CSV
write.csv(cavmSpList, "outputs/Species in the CAVM.csv", row.names = F)

# ------------------------------------ CBVM shape ------------------------------------------------------------
cbvm = vect("resources/NABoreal/NABoreal.shp")
plot(cbvm)
crs(cbvm)