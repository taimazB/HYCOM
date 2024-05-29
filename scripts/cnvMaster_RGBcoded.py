import numpy as np
from netCDF4 import Dataset
from scipy import interpolate
import multiprocessing
import os
import cv2
import math
import argparse
from rasterio.fill import fillnodata
from datetime import datetime, timedelta
# import matplotlib.pyplot as plt


###################################################################
###########################  FUNCTIONS  ###########################

def xMercator(lon):
    return R * lon * np.pi / 180.


def yMercator(lat):
    return R * np.log(np.tan(np.pi / 4 + lat * np.pi / 180 / 2))


def RGB(var):
    maxValue = math.ceil((np.nanmax(var)-minOrg)/step)
    colors = []
    for i in range(maxValue+1):
        r = math.floor(i/256/256)
        g = math.floor((i-r*256*256)/256)
        b = i - 256*(256*r+g)
        # colors.append((r,g,b))
        colors.append((b, g, r, 255))  # CV2 reverse RGB
    return colors


def saveImg(i, j, zoom, depth, xTile, yTile, f, allColors):
    x, y = i, 2**zoom - j - 1
    xTileSub = xTile[i * tileSize:(i + 1) * tileSize]
    yTileSub = yTile[j * tileSize:(j + 1) * tileSize]
    try:
        if (yTileSub.min() > yNC.max() or yTileSub.max() < yNC.min()):
            print('Exit 1')
            return
    except:
        print('Exit 2')
        return
    varNew = f(xTileSub, yTileSub)
    varNew[varNew < minOrg] = np.nan
    # To trim the interpolation tail from the right side
    iLonMax = np.argmin(np.abs(xTile - xMercator(lonNC[-1])))
    if ((i + 1) * tileSize > iLonMax):
        if (i * tileSize > iLonMax):
            varNew[:, :] = np.nan
        else:
            varNew[:, iLonMax % tileSize:] = np.nan
    #
    # To trim the interpolation tail from the left side
    iLonMin = np.argmin(np.abs(xTile - xMercator(lonNC[0])))
    if (i * tileSize < iLonMin):
        if ((i + 1) * tileSize < iLonMin):
            varNew[:, :] = np.nan
        else:
            varNew[:, :iLonMin % tileSize] = np.nan
    #
    # To trim the interpolation tail from the top side
    jLatMax = np.argmin(np.abs(yTile - yMercator(latNC[-1])))
    if ((j + 1) * tileSize > jLatMax):
        if (j * tileSize > jLatMax):
            varNew[:, :] = np.nan
        else:
            varNew[jLatMax % tileSize:, :] = np.nan
    #
    # To trim the interpolation tail from the bottom side
    jLatMin = np.argmin(np.abs(yTile - yMercator(latNC[0])))
    if (j * tileSize < jLatMin):
        if ((j + 1) * tileSize < jLatMin):
            varNew[:, :] = np.nan
        else:
            varNew[:jLatMin % tileSize, :] = np.nan
    #
    if (np.any(~np.isnan(varNew))):
        varNewRounded = np.round(varNew, int(-math.log10(step)))
        varNewInt = ((varNewRounded - minOrg) / step).astype(np.uint16)
        varNewInt[varNewInt < 0] = 0
        varRGB = allColors[varNewInt].astype(np.uint8)
        # imageio.imwrite('tiles/%s/%d/%d/%d.png' % (fileName, zoom, i, 2**zoom - j - 1), np.flipud(varRGB))
        imgDir = f"../tiles/{varName}/{saveDateTime}/depth-{depth}"
        devNull = os.system('mkdir -p %s/%d/%d' % (imgDir, zoom, x))
        cv2.imwrite('%s/%d/%d/%d.webp' % (imgDir, zoom, x, y), np.flipud(varRGB))


def genTiles(iDepth):
    depth = int(depthNC[iDepth])
    values = data[iDepth]
    mask = values.mask
    values = fillnodata(values, mask=~mask, max_search_distance=2)

    ##  0:360 -> -180:180
    values = np.roll(values, int(len(lonNC)/2), axis=1)
    mask = np.roll(mask, int(len(lonNC)/2), axis=1)

    ##  INTERPOLATE
    # values[mask] = missingValue
    f = interpolate.interp2d(xNC, yNC, values)

    allColors = np.array([[0, 0, 0, 0]])
    allColors = np.concatenate((allColors, RGB(values)), axis=0)

    for zoom in np.arange(minZoom, maxZoom + 1):
        print(f"##  Depth: {depth} | Zoom: {zoom}")
        noOfPoints = 2**zoom * tileSize
        #
        xTile = np.linspace(xMercator(-180), xMercator(180), noOfPoints)
        yTile = np.linspace(yMercator(-maxTileLat), yMercator(maxTileLat),
                            noOfPoints)
        iStart = math.floor(np.abs(xTile - xNC[0]).argmin() / tileSize)
        iEnd = math.floor(np.abs(xTile - xNC[-1]).argmin() / tileSize) + 1
        jStart = math.floor(np.abs(yTile - yNC[0]).argmin() / tileSize)
        jEnd = math.floor(np.abs(yTile - yNC[-1]).argmin() / tileSize) + 1
        iters = np.array(
            np.meshgrid(np.arange(iStart, iEnd),
                        np.arange(jStart, jEnd))).T.reshape(-1, 2)
        #
        for i,j in iters:
            saveImg(i,j,zoom,depth,xTile,yTile,f,allColors)

##############################################################################

parser = argparse.ArgumentParser()

parser.add_argument("--fileName", help="netCDF file name", required=True)
parser.add_argument("--minZoom", help="Minimum Zoom Level",
                    type=int, required=True)
parser.add_argument("--maxZoom", help="Maximum Zoom Level",
                    type=int, required=True)

args = parser.parse_args()

fileName = args.fileName
minZoom = args.minZoom
maxZoom = args.maxZoom

maxTileLat = 85.0511287798066
tileSize = 512  # px

nc = Dataset(fileName, 'r')

hours = nc.variables['time'][0].data+0
baseTime = datetime.strptime(nc.variables['time'].time_origin, '%Y-%m-%d %H:%M:%S')
saveDateTime = (baseTime + timedelta(hours=hours)).strftime('%Y%m%d_%H%M')

lonNC = nc.variables['lon'][:].data
latNC = nc.variables['lat'][:].data
depthNC = nc.variables['depth'][:].data

##  0:360 -> -180:180
lonNC[lonNC >= 180] -= 360
lonNC = np.roll(lonNC, int(len(lonNC)/2))

##  MERCATOR
R = 6378137
xNC = R * lonNC * np.pi / 180.
yNC = R * np.log(np.tan(np.pi / 4 + latNC * np.pi / 180 / 2))


##  TEMPERATURE
temperatureNC = nc.variables['water_temp'][0]
missingValue = nc.variables['water_temp'].missing_value
data = temperatureNC
varName = 'temperature'
minOrg = -100
step = 0.1
with multiprocessing.Pool() as p:
    p.map(genTiles, range(len(depthNC)))

##  SALINITY
salinityNC = nc.variables['salinity'][0]
missingValue = nc.variables['salinity'].missing_value
data = salinityNC
varName = 'salinity'
minOrg = 0
step = 0.01
with multiprocessing.Pool() as p:
    p.map(genTiles, range(len(depthNC)))


##  DENSITY
##  Calculate Density
##  https://link.springer.com/content/pdf/bbm%3A978-3-319-18908-6%2F1.pdf
##  temperature range: 0 - 40
##  salinity range: 0 - 42
a0 = 999.842594
a1 = 6.793953 * 10**-2
a2 = -9.095290*10**-3
a3 = 1.001685*10**-4
a4 = -1.120083*10**-6
a5 = 6.536332*10**-9
b0 = 8.2449*10**-1
b1 = -4.0899*10**-3
b2 = 7.6438*10**-5
b3 = -8.2467*10**-7
b4 = 5.3875*10**-9
c0 = -5.7246*10**-3
c1 = 1.0227*10**-4
c2 = -1.6546*10**-6
d0 = 4.8314*10**-4

temperatureNC[temperatureNC<0] = np.nan

def calcDensityAtDepth(iDepth):
    density_SMOW = a0 + a1*temperatureNC[iDepth] + a2*temperatureNC[iDepth]**2 + a3*temperatureNC[iDepth]**3 + a4*temperatureNC[iDepth]**4 + a5*temperatureNC[iDepth]**5
    B1 = b0 + b1*temperatureNC[iDepth] + b2*temperatureNC[iDepth]**2 + b3*temperatureNC[iDepth]**3 + b4*temperatureNC[iDepth]**4
    C1 = c0 + c1*temperatureNC[iDepth] + c2*temperatureNC[iDepth]**2
    return iDepth, density_SMOW + B1*salinityNC[iDepth] + C1*salinityNC[iDepth]**1.5 + d0*salinityNC[iDepth]**2

with multiprocessing.Pool() as p:
    data = p.map(calcDensityAtDepth, range(len(depthNC)))

data = np.ma.stack(list(map(lambda x:x[1], data)))
varName = 'density'
minOrg = 900
step = 0.1
with multiprocessing.Pool() as p:
    p.map(genTiles, range(len(depthNC)))
