#!/bin/tcsh

# LOWRES: make a copy of lower res (4mm voxel) data

# Process one or more subjects via corresponding do_*.tcsh script,
# looping over subj+ses pairs.
# Run on a slurm/swarm system (like Biowulf) or on a desktop.

# To execute:  
#     tcsh RUN_SCRIPT_NAME

# ---------------------------------------------------------------------------

# use slurm? 1 = yes, 0 = no, def: use if available
set use_slurm = $?SLURM_CLUSTER_NAME

# --------------------------------------------------------------------------

# specify script to execute
set cmd           = 01_lowres

# upper directories
set dir_scr       = $PWD
set dir_inroot    = ..
set dir_log       = ${dir_inroot}/logs
set dir_swarm     = ${dir_inroot}/swarms
set dir_basic     = ${dir_inroot}/data_00_basic

# names for logging and swarming/running
set cdir_log      = ${dir_log}/logs_${cmd}
set scr_swarm     = ${dir_swarm}/swarm_${cmd}.txt
set scr_cmd       = ${dir_scr}/do_${cmd}.tcsh

# --------------------------------------------------------------------------

# create log and swarm dirs
\mkdir -p ${cdir_log}
\mkdir -p ${dir_swarm}

# clear away older swarm script 
if ( -e ${scr_swarm} ) then
    \rm ${scr_swarm}
endif

# -------------------------------------------------------------------------
# build swarm execution script

set log = ${cdir_log}/log_${cmd}.txt

echo "tcsh -xf ${scr_cmd}                \\"    >> ${scr_swarm}
echo "     |& tee ${log}"                       >> ${scr_swarm}

# -------------------------------------------------------------------------
# run swarm command

cd ${dir_scr}

echo "++ And start running: ${scr_swarm}"

# simply execute the processing script
tcsh ${scr_swarm}


