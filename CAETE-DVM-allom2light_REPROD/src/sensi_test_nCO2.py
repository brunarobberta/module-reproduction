# Copyright 2017- LabTerra

#     This program is free software: you can redistribute it and/or modify
#     it under the terms of the GNU General Public License as published by
#     the Free Software Foundation, either version 3 of the License, or
#     (at your option) any later version.)

#     This program is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU General Public License for more details.

#     You should have received a copy of the GNU General Public License
#     along with this program.  If not, see <http://www.gnu.org/licenses/>.

# AUTHOR: JP Darela

# sensi_test.py
import os
import shutil
import multiprocessing as mp
from pathlib import Path
import joblib
from post_processing import write_h5
import h52nc

from parameters import BASE_RUN, ATTR_FILENAME, run_path, pls_path

# Experiment - nCO2 No eCO2 - HISTORICAL
assert run_path.exists(), "Wrong path to initial conditions"
assert pls_path.exists(), "Wrong path to Attributes Table"

with open(run_path, 'rb') as fh:
    init_conditions = joblib.load(fh)

# new outputs folder
dump_folder = Path(f"{BASE_RUN}_nCO2")

for gridcell in init_conditions:
    gridcell.clean_run(dump_folder, "init_cond")

h52nc.EXPERIMENT = "nCO2"
from caete import run_breaks_hist as rb


def zip_gridtime(grd_pool, interval):
    res = []
    for i, j in enumerate(grd_pool):
        res.append((j, interval[i % len(interval)]))
    return res


def apply_funX(grid, brk):
    grid.run_caete(brk[0], brk[1], fix_co2="1980")
    return grid


n_proc = mp.cpu_count()

for i, brk in enumerate(rb):
    print(f"Applying model to the interval {brk[0]}-{brk[1]}")
    init_conditions = zip_gridtime(init_conditions, (brk,))
    with mp.Pool(processes=n_proc) as p:
        init_conditions = p.starmap(apply_funX, init_conditions)

to_write = Path(os.path.join(Path("../outputs"), dump_folder)).resolve()
attrs = Path(os.path.join(to_write, Path(ATTR_FILENAME))).resolve()
h5path = Path(os.path.join(to_write, Path('CAETE.h5'))).resolve()
nc_outputs = Path(os.path.join(to_write, Path('nc_outputs')))

shutil.copy(pls_path, attrs)
write_h5(to_write)
h52nc.h52nc(h5path, nc_outputs)
