"""DEFINE SOME PARAMETERS FOR CAETÊ EXPERIMENTS"""
from pathlib import Path

# Name of the base historical observed run.
BASE_RUN = 'nclim_isa' #"HISTORICAL-RUN" <- in sombrero this is the 
                  # STANDARD name for the historical observed run

ATTR_FILENAME = "pls_attrs-1000.csv"
START_COND_FILENAME = f"CAETE_STATE_START_nclim_isa_.pkz"

run_path = Path(f"../outputs/{BASE_RUN}/{START_COND_FILENAME}")
pls_path = Path(f"../outputs/{BASE_RUN}/{ATTR_FILENAME}")