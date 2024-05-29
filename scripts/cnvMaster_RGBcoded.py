import numpy as np
from netCDF4 import Dataset
from scipy import interpolate
import multiprocessing
import os
import cv2
import math
import argparse
from rasterio.fill import fillnodata
import json
from datetime import datetime, timedelta
# import imageio
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
        imgDir = f"tiles/depth-{depth}"
        devNull = os.system('mkdir -p %s/%d/%d' % (imgDir, zoom, x))
        cv2.imwrite('%s/%d/%d/%d.webp' % (imgDir, zoom, x, y), np.flipud(varRGB))


def genTiles(iDepth):
    depth = int(depthNC[iDepth])
    temperature = temperatures[iDepth]
    mask = temperature.mask
    fillnodata(temperature, mask=~mask, max_search_distance=2)

    ##  0:360 -> -180:180
    temperature = np.roll(temperature, int(len(lonNC)/2), axis=1)
    mask = np.roll(mask, int(len(lonNC)/2), axis=1)

    ##  INTERPOLATE
    temperature[mask] = missingValue
    f = interpolate.interp2d(xNC, yNC, temperature)

    allColors = np.array([[0, 0, 0, 0]])
    allColors = np.concatenate((allColors, RGB(temperature)), axis=0)

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
                imgDir = f"tiles/depth-{depth}"
                devNull = os.system('mkdir -p %s/%d/%d' % (imgDir, zoom, x))
                cv2.imwrite('%s/%d/%d/%d.webp' % (imgDir, zoom, x, y), np.flipud(varRGB))

##############################################################################

parser = argparse.ArgumentParser()

parser.add_argument("--fileName", help="netCDF file name", required=True)
parser.add_argument("--minZoom", help="Minimum Zoom Level",
                    type=int, required=True)
parser.add_argument("--maxZoom", help="Maximum Zoom Level",
                    type=int, required=True)
parser.add_argument("--minOrg", help="Absolute minimum",
                    type=float, required=True)
parser.add_argument("--step", help="Step", type=float, required=True)

args = parser.parse_args()

fileName = args.fileName
minZoom = args.minZoom
maxZoom = args.maxZoom
minOrg = args.minOrg
step = args.step

maxTileLat = 85.0511287798066
tileSize = 512  # px

nc = Dataset(fileName, 'r')

temperatures = nc.variables['water_temp'][0]

hours = nc.variables['time'][0].data+0
baseTime = datetime.strptime(nc.variables['time'].time_origin, '%Y-%m-%d %H:%M:%S')
saveDateTime = (baseTime + timedelta(hours=hours)).strftime('%Y%m%d_%H%M')

lonNC = nc.variables['lon'][:].data
latNC = nc.variables['lat'][:].data
depthNC = nc.variables['depth'][:].data

missingValue = nc.variables['water_temp'].missing_value

##  0:360 -> -180:180
lonNC[lonNC >= 180] -= 360
lonNC = np.roll(lonNC, int(len(lonNC)/2))

##  MERCATOR
R = 6378137
xNC = R * lonNC * np.pi / 180.
yNC = R * np.log(np.tan(np.pi / 4 + latNC * np.pi / 180 / 2))


with multiprocessing.Pool() as p:
    p.map(genTiles, range(len(depthNC)))



##########################################################################

# varName = fileName.split('_')[1]
# var = nc.variables[varName][:].data
# missingValue = nc[varName].missing_value
# mask = np.bitwise_or(var == missingValue, np.isnan(var))
# fillnodata(var, mask=~mask, max_search_distance=2)

# # latitude, longitude, depth
# lonNC = nc.variables['longitude'][:].data
# latNC = nc.variables['latitude'][:].data
# lonNC[lonNC >= 180] -= 360

# if (np.nanmin(latNC) < -90 or np.nanmax(latNC) > 90):
#     print("##  %s: Latitude range problem!" % fileName)
#     exit()

# # Mercator
# R = 6378137
# xNC = R * lonNC * np.pi / 180.
# yNC = R * np.log(np.tan(np.pi / 4 + latNC * np.pi / 180 / 2))

# mask = np.bitwise_or(var == missingValue, np.isnan(var))
# var[mask] = missingValue
# f = interpolate.interp2d(xNC, yNC, var, kind='linear')


# allColors = np.array([[0, 0, 0, 0]])
# allColors = np.concatenate((allColors, RGB()), axis=0)

# global zoom
# global xTile, yTile
# #
# for zoom in np.arange(minZoom, maxZoom + 1):
#     print("--  Start zoom %d" % zoom)
#     noOfPoints = 2**zoom * tileSize
#     #
#     xTile = np.linspace(xMercator(-180), xMercator(180), noOfPoints)
#     yTile = np.linspace(yMercator(-maxTileLat), yMercator(maxTileLat),
#                         noOfPoints)
#     iStart = math.floor(np.abs(xTile - xNC[0]).argmin() / tileSize)
#     iEnd = math.floor(np.abs(xTile - xNC[-1]).argmin() / tileSize) + 1
#     jStart = math.floor(np.abs(yTile - yNC[0]).argmin() / tileSize)
#     jEnd = math.floor(np.abs(yTile - yNC[-1]).argmin() / tileSize) + 1
#     iters = np.array(
#         np.meshgrid(np.arange(iStart, iEnd),
#                     np.arange(jStart, jEnd))).T.reshape(-1, 2)
#     #
#     with multiprocessing.Pool() as p:
#         p.starmap(saveImg, iters)
