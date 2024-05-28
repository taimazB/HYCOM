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
# import matplotlib.pyplot as plt


###################################################################
###########################  FUNCTIONS  ###########################

def xMercator(lon):
    return R * lon * np.pi / 180.


def yMercator(lat):
    return R * np.log(np.tan(np.pi / 4 + lat * np.pi / 180 / 2))


def saveImg(i, j):
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
    uNew = fU(yTileSub, xTileSub)
    vNew = fV(yTileSub, xTileSub)
    #
    # uNew[uNew < -absMax] = 0
    # uNew[uNew > absMax] = 0
    # vNew[vNew < -absMax] = 0
    # vNew[vNew > absMax] = 0
    # To trim the interpolation tail from the right side
    iLonMax = np.argmin(np.abs(xTile - xMercator(lonNC[-1])))
    if ((i + 1) * tileSize > iLonMax):
        if (i * tileSize > iLonMax):
            uNew[:, :] = np.nan
            vNew[:, :] = np.nan
        else:
            uNew[:, iLonMax % tileSize:] = np.nan
            vNew[:, iLonMax % tileSize:] = np.nan
    #
    # To trim the interpolation tail from the left side
    iLonMin = np.argmin(np.abs(xTile - xMercator(lonNC[0])))
    if (i * tileSize < iLonMin):
        if ((i + 1) * tileSize < iLonMin):
            uNew[:, :] = np.nan
            vNew[:, :] = np.nan
        else:
            uNew[:, :iLonMin % tileSize] = np.nan
            vNew[:, :iLonMin % tileSize] = np.nan
    #
    # To trim the interpolation tail from the top side
    jLatMax = np.argmin(np.abs(yTile - yMercator(latNC[-1])))
    if ((j + 1) * tileSize > jLatMax):
        if (j * tileSize > jLatMax):
            uNew[:, :] = np.nan
            vNew[:, :] = np.nan
        else:
            uNew[jLatMax % tileSize:, :] = np.nan
            vNew[jLatMax % tileSize:, :] = np.nan
    #
    # To trim the interpolation tail from the bottom side
    jLatMin = np.argmin(np.abs(yTile - yMercator(latNC[0])))
    if (j * tileSize < jLatMin):
        if ((j + 1) * tileSize < jLatMin):
            uNew[:, :] = np.nan
            vNew[:, :] = np.nan
        else:
            uNew[:jLatMin % tileSize, :] = np.nan
            vNew[:jLatMin % tileSize, :] = np.nan
    #
    if (np.any(~np.isnan(uNew))):
        uNew = np.round(255*(uNew+absMax)/(2*absMax))
        vNew = np.round(255*(vNew+absMax)/(2*absMax))
        uv = np.dstack((uNew*np.nan, vNew, uNew)) ## B, G, R
        imgDir = fileName.split('.')[0]
        devNull = os.system('mkdir -p tiles/%s/%d/%d' % (imgDir, zoom, i))
        cv2.imwrite('tiles/%s/%d/%d/%d.webp' %
                    (imgDir, zoom, x, y), np.flipud(uv))


##############################################################################

parser = argparse.ArgumentParser()

parser.add_argument("--fileName", help="netCDF file name", required=True)
parser.add_argument("--minZoom", help="Minimum Zoom Level",
                    type=int, required=True)
parser.add_argument("--maxZoom", help="Maximum Zoom Level",
                    type=int, required=True)
parser.add_argument("--absMax", help="Absolute maxmimum of speed",
                    type=float, required=True)

args = parser.parse_args()

fileName = args.fileName
minZoom = args.minZoom
maxZoom = args.maxZoom
absMax = args.absMax

maxTileLat = 85.0511287798066
tileSize = 512  # px

nc = Dataset(fileName, 'r')
u = nc.variables['u'][:].data
v = nc.variables['v'][:].data
missingValue = nc['u'].missing_value

u[u==missingValue] = 0
v[v==missingValue] = 0

# latitude, longitude, depth
lonNC = nc.variables['longitude'][:].data
latNC = nc.variables['latitude'][:].data
lonNC[lonNC >= 180] -= 360

if (np.nanmin(latNC) < -90 or np.nanmax(latNC) > 90):
    print("##  %s: Latitude range problem!" % fileName)
    exit()

# Mercator
R = 6378137
xNC = R * lonNC * np.pi / 180.
yNC = R * np.log(np.tan(np.pi / 4 + latNC * np.pi / 180 / 2))

fU = interpolate.RectBivariateSpline(yNC, xNC, u)
fV = interpolate.RectBivariateSpline(yNC, xNC, v)

global zoom
global xTile, yTile
#
for zoom in np.arange(minZoom, maxZoom + 1):
    print("--  Start zoom %d" % zoom)
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
    with multiprocessing.Pool() as p:
        p.starmap(saveImg, iters)
