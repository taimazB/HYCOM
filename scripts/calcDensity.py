import numpy as np
from netCDF4 import Dataset
import sys
import matplotlib.pyplot as plt
from scipy import interpolate
import multiprocessing
import os
import imageio
# import tracemalloc
from datetime import datetime, timedelta
import math


fileT = sys.argv[1]
fileS = sys.argv[2]
fileD = sys.argv[3]

ncT = Dataset(fileT, 'r')
ncS = Dataset(fileS, 'r')

temp = np.array(ncT.variables['temperature'][:])
salt = np.array(ncS.variables['salinity'][:])

latNC = ncT.variables['latitude'][:].data
lonNC = ncT.variables['longitude'][:].data

##  Calculate Density
##  https://link.springer.com/content/pdf/bbm%3A978-3-319-18908-6%2F1.pdf
##  temperature range: 0 - 40
##  salinity range: 0 - 42
temp[temp<0] = np.nan

a0 = 999.842594
a1 = 6.793953 * 10**-2
a2 = -9.095290*10**-3
a3 = 1.001685*10**-4
a4 = -1.120083*10**-6
a5 = 6.536332*10**-9
rho_SMOW = a0 + a1*temp + a2*temp**2 + a3*temp**3 + a4*temp**4 + a5*temp**5

b0 = 8.2449*10**-1
b1 = -4.0899*10**-3
b2 = 7.6438*10**-5
b3 = -8.2467*10**-7
b4 = 5.3875*10**-9
B1 = b0 + b1*temp + b2*temp**2 + b3*temp**3 + b4*temp**4

c0 = -5.7246*10**-3
c1 = 1.0227*10**-4
c2 = -1.6546*10**-6
C1 = c0 + c1*temp + c2*temp**2

d0 = 4.8314*10**-4

rho = rho_SMOW + B1*salt + C1*salt**1.5 + d0*salt**2


#################################################
##  Save 3D rho as nc (OPASS)
ncD = Dataset(fileD, 'w', format='NETCDF4')

# define axis size
ncD.createDimension('latitude', len(latNC))
ncD.createDimension('longitude', len(lonNC))

# create latitude axis
latitude = ncD.createVariable('latitude', 'double', ('latitude'), zlib=True)
latitude.standard_name = 'latitude'
latitude.long_name = 'latitude'
latitude.units = 'degrees_north'
latitude.axis = 'Y'

# create longitude axis
longitude = ncD.createVariable('longitude', 'double', ('longitude'), zlib=True)
longitude.standard_name = 'longitude'
longitude.long_name = 'longitude'
longitude.units = 'degrees_east'
longitude.axis = 'X'

# create variable array
rhoOut = ncD.createVariable('density', 'double', ('latitude', 'longitude'), zlib=True, least_significant_digit=1)
rhoOut.long_name = 'Density'
rhoOut.units = 'kg/m3'
rhoOut.coordinates = "latitude longitude"

# Filling with date
longitude[:] = lonNC[:]
latitude[:] = latNC[:]
rhoOut[:, :] = rho[:, :]

# close files
ncD.close()
