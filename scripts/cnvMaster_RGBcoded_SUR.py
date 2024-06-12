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
        colors.append((b, g, r))  # CV2 reverse RGB
    return colors


def saveImg(i,j,zoom,xTile,yTile,f,allColors):
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
        imgDir = f"../tiles/{varName}/{saveDateTime}"
        devNull = os.system('mkdir -p %s/%d/%d' % (imgDir, zoom, x))
        cv2.imwrite('%s/%d/%d/%d.webp' % (imgDir, zoom, x, y), np.flipud(varRGB))


def genTiles():
    global zoom, allColors, xTile, yTile, f
    values = data
    
    ##  GENERATE COLORS
    allColors = np.array([[0, 0, 0]])
    allColors = np.concatenate((allColors, RGB(values)), axis=0)
    
    mask = values.mask
    values = fillnodata(values, mask=~mask, max_search_distance=2)

    ##  0:360 -> -180:180
    values = np.roll(values, int(len(lonNC)/2), axis=1)
    # mask = np.roll(mask, int(len(lonNC)/2), axis=1)
    
    ##  INTERPOLATE
    values[np.isnan(values)] = missingValue
    f = interpolate.interp2d(xNC, yNC, values)

    for zoom in np.arange(minZoom, maxZoom + 1):
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
            saveImg(i,j,zoom,xTile,yTile,f,allColors)

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

##  0:360 -> -180:180
lonNC[lonNC >= 180] -= 360
lonNC = np.roll(lonNC, int(len(lonNC)/2))

##  MERCATOR
R = 6378137
xNC = R * lonNC * np.pi / 180.
yNC = R * np.log(np.tan(np.pi / 4 + latNC * np.pi / 180 / 2))


##  SURFACE HEAT FLUX
data = nc.variables['qtot'][0]
missingValue = nc.variables['qtot']._FillValue
varName = 'surfaceHeatFlux'
minOrg = -5000
step = 1
genTiles()


##  SURFACE WATER FLUX
# data = nc.variables['emp'][0]
# missingValue = nc.variables['emp']._FillValue
# varName = 'surfaceWaterFlux'
# minOrg = -2
# step = 0.001
# genTiles()


##  SEA SURFACE ELEVATION
data = nc.variables['ssh'][0]
missingValue = nc.variables['ssh']._FillValue
varName = 'seaSurfaceElevation'
minOrg = -10
step = 0.001
genTiles()


##  SEA BOUNDARY LAYER THICKNESS
data = nc.variables['surface_boundary_layer_thickness'][0]
missingValue = nc.variables['surface_boundary_layer_thickness']._FillValue
varName = 'boundaryLayerThickness'
minOrg = 0
step = 1
genTiles()


##  MIXED LAYER THICKNESS
data = nc.variables['mixed_layer_thickness'][0]
missingValue = nc.variables['mixed_layer_thickness']._FillValue
varName = 'mixedLayerThickness'
minOrg = 0
step = 1
genTiles()
