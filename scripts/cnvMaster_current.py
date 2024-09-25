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


##  PARAMETERS
maxTileLat = 85.0511287798066
tileSize = 512  # px
absMax = 3
step = 0.01

###################################################################
###########################  FUNCTIONS  ###########################

def xMercator(lon):
    return R * lon * np.pi / 180.


def yMercator(lat):
    return R * np.log(np.tan(np.pi / 4 + lat * np.pi / 180 / 2))


def saveImg(i,j,zoom,depth,xTile,yTile,fU,fV):
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
    uNew = fU(xTileSub, yTileSub)
    vNew = fV(xTileSub, yTileSub)
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
        imgDir = f"tiles/{varName}/{saveDateTime}/depth-{depth}"
        devNull = os.system('mkdir -p %s/%d/%d' % (imgDir, zoom, x))
        cv2.imwrite('%s/%d/%d/%d.webp' % (imgDir, zoom, x, y), np.flipud(uv))


def genTiles(iDepth):
    depth = int(depthNC[iDepth])
    u = uNC[iDepth]
    v = vNC[iDepth]
    mask = u.mask
    u = fillnodata(u, mask=~mask, max_search_distance=2)
    v = fillnodata(v, mask=~mask, max_search_distance=2)

    ##  0:360 -> -180:180
    u = np.roll(u, int(len(lonNC)/2), axis=1)
    v = np.roll(v, int(len(lonNC)/2), axis=1)
    # mask = np.roll(mask, int(len(lonNC)/2), axis=1)

    ##  INTERPOLATE
    u[np.isnan(u)] = missingValue
    v[np.isnan(v)] = missingValue
    #
    fU = interpolate.interp2d(xNC, yNC, u)
    fV = interpolate.interp2d(xNC, yNC, v)

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
            saveImg(i,j,zoom,depth,xTile,yTile,fU,fV)

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

nc = Dataset(f"nc/{fileName}", 'r')

hours = nc.variables['time'][0].data+0
# baseTime = datetime.strptime(nc.variables['time'].time_origin, '%Y-%m-%d %H:%M:%S')
baseTime = datetime(2000,1,1)
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


##  UV
uNC = nc.variables['water_u'][0]
vNC = nc.variables['water_v'][0]
missingValue = nc.variables['water_u'].missing_value
varName = 'current'
with multiprocessing.Pool() as p:
    p.map(genTiles, range(len(depthNC)))
