#!/bin/tcsh

# TRAIN: run the VNET on training data
# -> on FULL RES

# This script processes a corresponding do_*.tcsh script.
# Can be run on either a slurm/swarm system (like Biowulf) or on a desktop.

# To execute:  
#     tcsh RUN_SCRIPT_NAME

# ---------------------------------------------------------------------------

# use slurm? 1 = yes, 0 = no, def: use if available
set use_slurm = $?SLURM_CLUSTER_NAME

# --------------------------------------------------------------------------

# specify script to execute
set cmd           = 13_train_full

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

# ***special for biowulf setup
source /data/NIMH_SSCC/ptaylor/miniconda3/etc/profile.d/conda.csh >& /dev/null 

# Note on running this:
# + re. memory, 60GB was unnecessarily high; like 30GB would be fine.
# + re. CPUs: 8 all got used; so now going to try with higher count like 32

swarm                                                          \
    -f ${scr_swarm}                                            \
    #--partition=norm,quick                                     \
    --partition=gpu                                            \
    --threads-per-process=8                                    \
    --gb-per-process=60                                        \
    --time=20:00:00                                            \
    ##--gres=lscratch:10                                         \
    --gres=gpu:a100:1                                          \
    --logdir=${cdir_log}                                       \
    --job-name=job_${cmd}                                      \
    --merge-output                                             \
    --usecsh



exit
# simply execute the processing script
tcsh ${scr_swarm}


