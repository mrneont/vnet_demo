#!/bin/tcsh

# AUG: run data augmentation for VNET; for both train and validation

# Run this script from its partner run*.tcsh script.
# Can be run on either a slurm/swarm system (like Biowulf) or on a desktop.

# ---------------------------------------------------------------------------

if ( "`whoami`" == "taylorpa3" ) then
    echo "++ Special stage to prepare for running on biowulf"
    source /data/NIMH_SSCC/ptaylor/miniconda3/etc/profile.d/conda.csh
endif

# ---------------------------------------------------------------------------


# use slurm? 1 = yes, 0 = no (def: use if available)
set use_slurm = $?SLURM_CLUSTER_NAME

# ----------------------------- biowulf-cmd ---------------------------------
if ( $use_slurm ) then
    # load modules: ***** add any other necessary ones
    source /etc/profile.d/modules.csh
    module load afni

    # set N_threads for OpenMP
    setenv OMP_NUM_THREADS $SLURM_CPUS_ON_NODE
endif
# ---------------------------------------------------------------------------

# initial exit code; we don't exit at fail, to copy partial results back
set ecode = 0

# ---------------------------------------------------------------------------
# top level definitions (constant across demo)
# ---------------------------------------------------------------------------

# upper directories
set dir_inroot     = ${PWD:h}                        # one dir above scripts/
set dir_log        = ${dir_inroot}/logs
set dir_vnet_run   = ${dir_inroot}/vnet_afni_run     # dir with used vnet code
set dir_basic      = ${dir_inroot}/data_00_basic
set dir_lowres     = ${dir_inroot}/data_01_lowres
set dir_aug        = ${dir_inroot}/data_02_aug

# supplementary directory (reference data, etc.)
set dir_suppl      = ${dir_inroot}/supplements

# set output directory
set sdir_out = ${dir_aug}
set lab_out  = "DATA_AUG"

# ----------------------------- biowulf-cmd --------------------------------
if ( $use_slurm ) then
    # try to use /lscratch for speed; store "real" output dir for later copy
    if ( -d /lscratch/$SLURM_JOBID ) then
        set usetemp  = 1
        set sdir_BW  = ${sdir_out}
        set sdir_out = /lscratch/$SLURM_JOBID/${subjid}

        # prep for group permission reset
        \mkdir -p ${sdir_BW}
        set grp_own  = `\ls -ld ${sdir_BW} | awk '{print $4}'`
    else
        set usetemp  = 0
    endif
endif
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# run programs
# ---------------------------------------------------------------------------

# make output top-level dir
\mkdir -p ${sdir_out}

# from ${dir_suppl}/environment_vnet_tech_2024_01_02.yml
echo "++ Load conda env vnet_tech_2024_01_02"
conda activate vnet_tech_2024_01_02

if ( $status ) then
    echo "** ERROR: not finding conda env"
    set ecode = 1
    goto COPY_AND_EXIT
endif

# at the moment, need to run augmentation from dir that has related scripts
cd ${dir_vnet_run}/data_augmentation_scripts

# augment the training data
python data_augmentation_wrapper.py                                          \
    -input_dir           ${dir_lowres}/training                              \
    -output_dir          ${sdir_out}/training                                \
    -num_cp              3                                                   \
    -exec_mode           swarm

if ( ${status} ) then
    set ecode = 2
    goto COPY_AND_EXIT
endif

# ... and for creating VNET, we need to copy over the validation data, too
echo "++ Copy validation tree (via augmentation of only 1 'copy')"
python data_augmentation_wrapper.py                                          \
    -input_dir           ${dir_lowres}/validation                            \
    -output_dir          ${sdir_out}/validation                              \
    -num_cp              1                                                   \
    -exec_mode           swarm

if ( ${status} ) then
    set ecode = 3
    goto COPY_AND_EXIT
endif

echo "++ FINISHED ${lab_out}"

conda deactivate

# ---------------------------------------------------------------------------

COPY_AND_EXIT:

# ----------------------------- biowulf-cmd --------------------------------
if ( $use_slurm ) then
    # if using /lscratch, copy back to "real" location
    if( ${usetemp} && -d ${sdir_out} ) then
        echo "++ Used /lscratch"
        echo "++ Copy from: ${sdir_out}"
        echo "          to: ${sdir_BW}"
        \cp -pr   ${sdir_out}/* ${sdir_BW}/.

        # reset group permission
        chgrp -R ${grp_own} ${sdir_BW}
    endif
endif
# ---------------------------------------------------------------------------

if ( ${ecode} ) then
    echo "++ BAD FINISH: ${lab_out} (ecode = ${ecode})"
else
    echo "++ GOOD FINISH: ${lab_out}"
endif

exit ${ecode}

