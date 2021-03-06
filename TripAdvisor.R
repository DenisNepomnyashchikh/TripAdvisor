# Mice imputation missing values will likely take a few minutes (150 iterations). 
# Be patient!

# Uncomment to set up packages 
#install.packages("ggplot2")
#install.packages("ggmap")
#install.packages("mice")
#install.packages("corrplot")
#install.packages("AID")
#install.packages("scatterplot3d")

# An Implementation of the Grammar of Graphics
library(ggplot2) 
# A collection of functions to visualize spatial data and models
# on top of static maps from various online sources
library(ggmap) 
# Multivariate Imputation by Chained Equations
library(mice) 
# Visualization of a correlation matrix
library(corrplot) 
# Estimation of Box-Cox Power Transformation Parameter
library(AID)
# 3D Visualization
library(scatterplot3d)

# Function for reseting par
resetPar <- function() {
  dev.new()
  op <- par(no.readonly = TRUE)
  dev.off()
  op
}

# Load data (choose your working directory)
load("6-tripadvisor2.RData")

# Create data frames (suitable names)
ta <- as.data.frame(tripadvisor2[1])
tta <- as.data.frame(tripadvisor2[2])

# Recoding variables for map (suitable names)
lat <- ta$tripadvisor.latitude
lon <- ta$tripadvisor.longitude
tlat <- tta$top3attractions.latitude
tlon <- tta$top3attractions.longitude
df <- as.data.frame(cbind(lon,lat))
tdf <- as.data.frame(cbind(tlon,tlat))

# Recoding other variables (suitable names)
num.rooms <- ta$tripadvisor.number_of_rooms
city.rank <- ta$tripadvisor.city_ranking
foto.c <- ta$tripadvisor.foto_count
rat.tot <- ta$tripadvisor.rating_total
c.rat.tot <- ta$tripadvisor.count_ratings_total
hotel.pr <- ta$tripadvisor.hotel_price
dis.s1 <- ta$tripadvisor.distance_to_sight1
dis.s2 <- ta$tripadvisor.distance_to_sight2
dis.s3 <- ta$tripadvisor.distance_to_sight3
dis.cc <- ta$tripadvisor.distance_to_city_center
name <- ta$tripadvisor.hotel_name
cr.fam <- ta$tripadvisor.count_ratings_family
cr.co <- ta$tripadvisor.count_ratings_couple
cr.sin <- ta$tripadvisor.count_ratings_single
cr.bus <- ta$tripadvisor.count_ratings_business
cr.to <- ta$tripadvisor.count_ratings_total

# Transform categorical variable to continious data
my.sum.rat <- (5*ta$tripadvisor.rating_excellent+
                 4*ta$tripadvisor.rating_verygood+
                 3*ta$tripadvisor.rating_average+
                 2*ta$tripadvisor.rating_poor+
                 ta$tripadvisor.rating_terrible)

# Create new dataset with continious data (we exclude binary dichotomous and other unimportant data (state, zip, url))
t.data <- as.data.frame(cbind(my.sum.rat, foto.c, num.rooms, hotel.pr, dis.s1, dis.s2, dis.s3, dis.cc, cr.fam, cr.bus, cr.sin, cr.co))

# Set row names as name of hotels
row.names(t.data) <- name

# Structure and summary of the data
str(t.data)
summary(t.data)
# We have missing data in rating, counts ratings and hotel prices.
# Implement linear regression and package Mice to impute missing values.

###########################################
# Impute missing values 
###########################################

# Regression
# set without field "my.sum.rat"
predict_prices <- data.frame(t.data[2:8], ta[30:74]*1)
# set with all fields
all_data <- data.frame(t.data, ta[30:74]*1)

predict_prices <- na.omit(predict_prices)
# str(predict_prices)

# linear regression to determine significant variables and their coefficients
regression <- lm(hotel.pr ~ 
                   num.rooms+
                   foto.c +
                   tripadvisor.f3_RoomService                             +
                   tripadvisor.f5_Bar.Lounge                              +
                   tripadvisor.f10_Concierge                              +
                   tripadvisor.f28_DryCleaning                            +
                   tripadvisor.f43_Refrigeratorinroom                                               
                 , data = predict_prices)
summary(regression)
coefficients(regression) # model coefficients
anova(regression)
confint(regression, level=0.95) # CIs for model parameters

# set with actual values, predicted values and absolute error in percents 
predicted_data <- data.frame(actual_pr = predict_prices$hotel.pr, predicted_pr = fitted(regression),
                             percentage_error = round(100*abs(predict_prices$hotel.pr-fitted(regression))/predict_prices$hotel.pr,digits = 4))

summary(predicted_data)

# set to fill the prices values
missing_prices <- data.frame(all_data[4],
                             all_data[3],
                             all_data[2],
                             all_data[15],
                             all_data[17],
                             all_data[22],
                             all_data[40],
                             all_data[55])

# matrix of predictors for "mice" method
predictor_matrix <- matrix(c(
  0,1,1,1,1,1,1,1,
  0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0),
  nrow=8,              # number of rows 
  ncol=8,              # number of columns 
  byrow = TRUE
)
# apply mice to retrieve missing values
tempData <- mice(missing_prices,m=20,maxit=150,meth='pmm',predictorMatrix=predictor_matrix,seed=500)
summary(tempData)
completedData <- complete(tempData,1)

# fill the dataset with price values
all_data$hotel.pr <- completedData$hotel.pr

# fill the dataset with "my.sum.rat" values
tempData <- mice(all_data,m=20,maxit=150,meth='pmm',seed = 500)
all_data <- complete(tempData,1)

# Create new clear dataset
cl.data <- all_data[c(1:12)]
cl.data$city.rank <- city.rank

# Rename rownames as abbreviatoins of hotels names
abr.name <- abbreviate(name, minlength = 2)
row.names(cl.data) <- abr.name

###############################################
#Simple Exploratory analysis
###############################################

#Create geographical maps
map <- get_map(location = c(lon = mean(df$lon), lat = mean(df$lat)), zoom = 12, maptype = "terrain", scale = 2)

#Map with all hotels
#png("map1.png", width=700, height=600)
ggmap(map) +
  geom_point(data = df, color = 'darkred', size = 6, alpha = 0.5, pch = 16)
#dev.off()

#Map with prices and ratings
#png("map2.png", width=700, height=700)
ggmap(map) +
  geom_point(data = df, aes(colour = factor(rat.tot), size = cl.data$hotel.pr)) 
#dev.off()

# Structure and summary of the data
str(cl.data)
summary(cl.data)

# Main features
sapply(cl.data, function(x){
  c(sd = sd(x, na.rm = T), var = var(x, na.rm = T), mad = mad(x, na.rm = T), iqr = IQR(x, na.rm = T))
})

# Correlations
p.cor <- cor(cl.data[-c(5:12)])
s.cor <- cor(cl.data[-c(5:12)], method = "spearman")
k.cor <- cor(cl.data[-c(5:12)], method = "kendall")

# Corrplots
par(mfrow = c(2,2))
corrplot(p.cor, method = "shade", main = 'Pearson')
corrplot(s.cor, method = "shade", main = 'Spearman')
corrplot(k.cor, method = "shade", main = 'Kendall')
par(resetPar())

# Pairs plots 
pairs(cl.data)
pairs(cl.data[c(1:4,13)], pch = 19)
pairs(cl.data[c(5:8)], pch = 19)
#png("withreg.png", width=1100, height=600)
pairs(cl.data[c(9:12)], 
      panel = function (x, y, ...) {
        points(x, y, ...)
        abline(lm(y ~ x), col = "red")
      }, pch=19,cex.labels=2,cex.axis=2)
#dev.off()

# Boxplots
boxplot(cl.data, las = 1)
boxplot(cl.data$my.sum.rat, las = 1)
boxplot(cl.data[c(2,3,4,13)], las = 1)

#png("boxplot.png", width=1100, height=600)
boxplot(cl.data[c(5:8)], las = 1, col = 'red', pch = 19, cex =2, main = 'Distances Boxplot', cex.main = 2)
#dev.off()

boxplot(cl.data[c(9:12)], las = 1)

# Pairs
panel.hist2 <- function(x, ...)
{
  usr <- par("usr"); on.exit(par(usr))
  par(usr = c(usr[1:2], 0, 1.5) )
  h <- hist(x, plot = FALSE)
  breaks <- h$breaks; nB <- length(breaks)
  y <- h$counts; y <- y/max(y)
  rect(breaks[-nB], 0, breaks[-1], y, col="red", ...)
}


panel.cor2 <- function(x, y, digits=2, prefix="", cex.cor=1,...)
{   usr <- par("usr"); on.exit(par(usr))
par(usr = c(0, 1, 0, 1))
r <- abs(cor(x, y))
rsp <- abs(cor(x,y,method="spearman"))
txt <- format(c(r, 0.123456789), digits=digits)[1]
txt2 <- format(c(rsp, 0.123456789), digits=digits)[1]
text(0.5, 0.5, paste(txt," / ", txt2,sep=""), cex = 2, col="blue")
}

#png("combined.png", width=1100, height=600)
pairs(cl.data[c(1:4,13)], 
      panel = function (x, y, ...) {
        points(x, y, ...)
        abline(lm(y ~ x), col = "red")
      }, pch=19,cex.labels=2,cex.axis=2,upper.panel=panel.cor2, diag.panel=panel.hist2)

#dev.off()

########################################
# Test for Normality # Dmitry Toveskin #
########################################

# Create QQplots
#png("qqplots2.png", width=1100, height=600)
layout(matrix(1:8, ncol = 4, nrow = 2))
sapply(colnames(cl.data), function(x){
  qqnorm(cl.data[[x]], main = x, pch = 19, cex.lab = 2, cex.main = 2, ylab = "")
  qqline(cl.data[[x]], lwd = 2, col = "red")
})
#dev.off()

# Chi-Square plot based on generalized distances
x <- cl.data
cm <- colMeans(x)
S <- cov(x)
d <- apply(x, 1, function (x) t(x-cm) %*% solve(S) %*% (x-cm))
#png("chi-Square_plot.png", width=1100, height=600)
par(mfrow=c(1,1))
plot(qc <- qchisq((1:nrow(x)-1/2)/nrow(x), df=13),
     sd <- sort(d), xlab = expression(paste(chi[13]^2, "Quantile")),
     ylab = "Ordered Distances", xlim = range(qc)*c(1,1.1),
     pch = 19, cex.lab = 1.5, cex.axis = 2, cex = 2, cex.main = 2,
     col=ifelse(rank(abs(qc-sd), ties = "random") > nrow(x)-3, "red", "black"),
     main = 'Chi-Square plot based on generalized distances')
out <- which(rank(abs(qc-sd), ties = "random") > nrow(x)-3)
text(qc[out], sd[out]-1, names(out), cex = 1, col = "blue")
abline(a = 0, b = 1, col = "red", lwd = 2)
#dev.off()

# Shapiro-Wilk test
#png("shapiro.png", width=1100, height=600)
layout(matrix(1:8, ncol = 4, nrow = 2))
sapply(colnames(cl.data), function(x){
  hist(as.numeric(cl.data[[x]]), main = x, xlab = round(shapiro.test(as.numeric(cl.data[[x]]))$p.value,2), 
       col = "red", cex.main = 2, cex.lab = 2)
})
#dev.off()

###############################################
# Box-cox transformation 
###############################################

# Shift counts ratings data to 0.0001 to get positive values
shift.cl.data <- cbind(cl.data[1:8], cl.data[, 9:12]+0.0001, cl.data[13])

# Box-Cox implementation
tr.data <- sapply(shift.cl.data, function(x){
  lambda <- boxcoxnc(x, method = 'sw', plotit = F, lam = seq(-4,4, 0.01))$result[[1]]
  tr <- (x^{lambda}-1)/lambda
  return(tr)
})
tr.data <- as.data.frame(tr.data)
colnames(tr.data) <- colnames(cl.data)
rownames(tr.data) <- rownames(cl.data)

# QQplots after boxcox transformation
#png("afterboxcox1.png", width=1100, height=600)
layout(matrix(1:8, ncol = 4, nrow = 2))
sapply(colnames(tr.data), function(x){
  tr = tr.data[[x]]
  shapiro = shapiro.test(tr)
  sub = sprintf('p-value: %.3g', shapiro$p.value)
  qqnorm(tr, main = x, pch = 19, cex.lab = 2, cex.main = 2, sub = sub)
  qqline(tr, lwd = 2, col = 'red')
})
#dev.off()

# Histogramm after boxcox transformation
#png("afterboxcoxhist1.png", width=1100, height=600)
layout(matrix(1:8, ncol = 4, nrow = 2))
sapply(colnames(tr.data), function(x){
  tr = tr.data[[x]]
  hist(tr, main = x, xlab = round(shapiro.test(tr)$p.value,2),
       col = 'cyan', cex.main = 2, cex.lab = 2, ylab = "")
})
#dev.off()

# Hypothesis Tests
pval.obs <- sapply(shift.cl.data, function(x){
  shapiro.test(x)$p.value
}) 
pval.tr <- sapply(tr.data, function(x){
  shapiro.test(x)$p.value
})
alpha = 0.05
dec.obs <- ifelse(pval.obs < alpha, 'HA', 'H0')
dec.tr <- ifelse(pval.tr < alpha, 'HA', 'H0')
data.frame(pval.obs, dec.obs, pval.tr, dec.tr)
# So, based on significant level of alpha = 0.05 we reject HA 
# hypothesis about non-normality (p-value bigger than an alpha)

###########################################
# Detecting Outliers 
###########################################

scale.data <- as.data.frame(apply(cl.data, 2, scale))
which(scale.data > 3.5) # 0 possible outliers

# Reduce critical threshold to 3 (only 0.27% probability in normal distribution)
which(scale.data > 3) # 3 possible outliers 

# Subset outliers
subset(scale.data, hotel.pr>3)
subset(scale.data, dis.cc>3)
subset(scale.data, num.rooms>3)
# We detect 3 outliers with 2 hotels only (SPAH and HI&SMV)

# Subset outliers in original data
subset(cl.data, hotel.pr>500)
subset(cl.data, dis.cc>6)
subset(cl.data, num.rooms>300)

# Chi-Square plot based on generalized distances
x <- cl.data
cm <- colMeans(x)
S <- cov(x)
d <- apply(x, 1, function (x) t(x-cm) %*% solve(S) %*% (x-cm))
#png("chi-Square_plot_outliers.png", width=1100, height=600)
par(mfrow=c(1,1))
plot(qc <- qchisq((1:nrow(x)-1/2)/nrow(x), df=13),
     sd <- sort(d), xlab = expression(paste(chi[13]^2, "Quantile")),
     ylab = "Ordered Distances", xlim = range(qc)*c(1,1.1),
     pch = 19, cex.lab = 1.5, cex.axis = 2, cex = 2, cex.main = 2, 
     col=ifelse(sd > qchisq(.95, df=13), "red", "black"),
     main = 'Chi-Square plot based on generalized distances')
out <- which(sd > qchisq(.95, df=13))
text(qc[out], sd[out]-1, names(out), cex = 1, col = "blue")
#dev.off()
# This method shows 3 possible outliers (SPAH, SGH, HI&SMV)

# Examine possible outliers
# HI&SMV
#png("out1.png", width=1100, height=600)
pairs(cl.data[c(5:9)], pch = 19, panel = function(x, y, ...){
  points(x, y, ...)
  points(x[1], y[1], cex=3, lwd=2, col = 'red')
})
#dev.off()

# SPAH
#png("out2.png", width=1100, height=600)
pairs(cl.data[c(1:4)], pch = 19, panel = function(x, y, ...){
  points(x, y, ...)
  points(x[15], y[15], cex=3, lwd=2, col = 'red')
})
#dev.off()

# SGH
pairs(cl.data, pch = 19, panel = function(x, y, ...){
  points(x, y, ...)
  points(x[26], y[26], cex=3, lwd=2, col = 'red')
})
# The last one is not outlier!
# So we have 2 outliers (SPAH and HI&SMV)

# Deleting outliers for original dataset
final.data <- cl.data[-c(1, 15),]
# Deleting outliers for boxcox transformed dataset
tr.data <- tr.data[-c(1, 15),]
abr.name <- abr.name[-c(1, 15)]


########################################################
# Principal Component Analysis
########################################################

# Use new dataset without outliers and transformed to normality
setforpca <- tr.data

# Covariance matrix
round(cov(setforpca),2)
apply(setforpca, 2, sd)

# Correlation matrix
round(cor(setforpca), 2)

# Standartization variables by their ranges
rge <- sapply(setforpca, function(x) diff(range(x)))
scalesetforpca <- sweep(setforpca,2,rge, FUN = '/')

# Variances of the standartized rates
sapply(scalesetforpca, var)

# We use correlation matrix because our variables are measured in different units. 
data.pca <- princomp(scalesetforpca, cor = T)

# Get the importance of components and loadings
summary(data.pca, loadings = TRUE)

# Scree diagram
#png("screePCA.png", width=1100, height=600)
plot(data.pca, type = 'l', col = 'red', main = 'Scree diagram', lwd = 2, cex.main = 2)
abline (v = 3)
#dev.off()

# Three PC explain  86,7% of the variance
# The first PC consists of all variables and all of them 
# have nearly the same influence on ths component.
# The second PC consists of almost all variables but cr.sin and hotel.pr.
# The distances variables have the greatest influences on this component.
# In the third PC variable hotel.pr and city.rank have the greatest 
# influences on this component.

# Biplot
#png("bilot.png", width=600, height=600)
biplot(data.pca,  main = 'Biplot', cex.main = 2)
#dev.off()

# This biplot shows that at least two principal components are needed
# to explain a great portion of the variance. All features have nearly 
# the same influence on the components. 
# If we want choose the "best" hotel, we try to find hotel with
# minimum prices, close to signs, with good ratings.
# SPH looks like optimum and next pretendents are TWPA and TEAJDVH 

# Plot first two principal components
#png("2PC.png", width=1100, height=600)
plot(data.pca$scores[,1:2], pch = 20, cex = 2, cex.lab = 1.5, cex.main = 2, main = 'First two principal components')
text(data.pca$scores[,1], data.pca$scores[,2], abr.name, cex=1.5, pos=4, col="red")
#dev.off()

# Plot first three principal components
#png("3PC.png", width=1100, height=600)
pairs(data.pca$scores[,1:3], pch = 19, cex = 2, cex.main = 2, main = 'Three principal components')
#dev.off()

# 3D plot
#png("3dscatter.png", width=1100, height=600)
scatterplot3d(data.pca$scores[,1:3], pch = 19, type = 'h', angle = 55)
#dev.off()

############################################
# Cluster Analysis 
############################################

#Hierarchical clustering 
methods = c("average", "single", "complete")
#png("hiercluster.png", width=1100, height=600)
opar = par(mfrow = c(1, 3))
sapply(methods, function(method) {
  res.clust = hclust(dist(scalesetforpca), method = method)
  plot(res.clust, main = sprintf("hclust - method: %s", method), cex.main = 2)
})
#dev.off()
par(opar)
# 3 clusters are optimum for this case

#K-means clustering
#Compute within-groups of squares for one- to six-group solutions 
n <- nrow(scalesetforpca)
wss <- rep(0,6)
wss[1] <- (n-1)*sum(sapply(scalesetforpca, var))
for (i in 2:6){
  wss[i] <- sum(kmeans(scalesetforpca, centers = i)$withinss)
}

# Plot
plot(wss, type = 'b', col = 'red', pch = 19, lwd = 2,
     xlab = 'Number of groups',
     ylab = 'Within groups sum of squares',
     main = 'Number of groups')

#Define number of clusters
data<-scalesetforpca
plotWSSVsK = function(data) {
     n = nrow(data)
     # Determine possible numbers for K*
     Ks = seq(n - 1L)
     # WSS for the actual data
     tot.wss = sapply(Ks, function(k) {
     kmeans(data, centers = k, algorithm = "Lloyd")$tot.withinss
     })
  
     # WSS for the uniformaly generated data
     unif.data = matrix(runif(2*n, min = min(data[, 1]), max = max(data[, 2])), ncol = 2)
     exp.tot.wss = sapply(Ks, function(k) {
     kmeans(unif.data, centers = k)$tot.withinss
     })
  
     # Actually draw the plot
     plot(Ks, tot.wss, type = "b", col = "red", pch = 20, lwd = 2, cex = 2, xlab = "Number of clusters", ylab = 'Total WSS', main = 'Number of clusters', cex.main = 2, cex.lab = 1.5)
     lines(Ks, exp.tot.wss, col = "blue", lwd = 2)
     points(Ks, exp.tot.wss , col = "blue", pch = 20, cex = 2)
     legend("topright", c("Actual data", "Uniformly distributed data"), lwd=2, col=c("red", "blue"))
}

#png("WSS.png", width=1100, height=600)
plotWSSVsK(data) # 3 clusters
abline(v=3)
#dev.off()


# Plot clusters for principal components in color
k <- kmeans(scalesetforpca, centers = 3)
z <- as.numeric(k$cluster)
clz <- c('blue', 'red', 'green')[z]
#png("kmeans2.png", width=1100, height=600)
plot(data.pca$scores[,1:2], pch = 19, cex.lab=1.5, cex = 2,  cex.axis=1.5, col=clz, lwd=2, main = 'K-means clustering', cex.main = 2)
text(data.pca$scores[,1], data.pca$scores[,2], abr.name, cex=1.5, pos=4, col="red")
#dev.off()

#png("kmeans3.png", width=1100, height=600)
pairs(data.pca$scores[,1:3], pch = 19, col = clz, main = 'K-means clustering for 3 PC', cex.main = 2, cex = 2)
#dev.off()

# 3D plot
#png("3dscatter2.png", width = 600, height=600)
scatterplot3d(data.pca$scores[,1:3], pch = 19, type = 'h', angle = 55, color = clz, main = 'K-means clustering for 3 PC')
#dev.off()

############################
# Scenario 
############################
# We recommend to choose any hotels from second cluster. 
# Now we try to explore features from each hotel in that 
# cluster depends on various scenarios (single, couple, family and business)

rec.hotels <- row.names(tr.data[k$clust==1,])
rec.hotels
#Extract only binary data
binary.data <- all_data[13:57]

# Subset some useful features 
useful.bin.data <- binary.data[c(1,2,5,9,12,20,22,23,25,26,29,34)]
rename <- c('FreeWiFi', 'Pool', 'Bar', 'Laundry', 'FreeParking', 'FamilyRooms', 'AirCond', 'Minibar', 'BussCenter', 'ChildActiv', 'MeetRooms', 'Babysit')
colnames(useful.bin.data) <- rename
rownames(useful.bin.data) <- rownames(cl.data)

# Create  table of features with hotels from recommended cluster
recommend.cluster <- cbind(useful.bin.data[rec.hotels,], cl.data[rec.hotels, c(1, 4, 8)])

# Create single scenario
# List of features: FreeWiFi, LaundryService, AirConditioning, Minibar
single.sc <- recommend.cluster[c(1, 4, 7, 8, 13, 14, 15)]
single.sc # Best choice - TEaJdVH (The Epiphany, a Joie de Vivre Hotel)

# Create family scenario
# List of features: FreeWiFi, Pool, LaundaryService, FreeParking, FamilyRooms, AirConditioning, Babysitting
family.sc <- recommend.cluster[c(1, 2, 4, 5, 6, 7, 12, 13, 14, 15)]
family.sc # Best choices: SPH (Stanford Park Hotel) and STI (Stanford Terrace Inn)

# Create couple scenario
# List of features: FreeWiFi, Pool, BarLounge, AirConditioning, Minibar
couple.sc <- recommend.cluster[c(1, 2, 3, 7, 13, 14, 15)]
couple.sc # Best choices: SPH (Stanford Park Hotel), TEaJdVH (The Epiphany, a Joie de Vivre Hotel) and CI (Creekside Inn)

# Create business scenario
# List of features: FreeWiFi, BarLounge, AirConditioning, BusinesCenter, MeetingRoom
business.sc <- recommend.cluster[c(1, 3, 7, 9, 11, 13, 14, 15)]
business.sc # Best choice: TEaJdVH (The Epiphany, a Joie de Vivre Hotel)