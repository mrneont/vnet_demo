#!/bin/tcsh

# LOWRES: make a copy of lower res (4mm voxel) data

# Run it from its partner run*.tcsh script (either slurm/swarm or desktop).

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

# set output directory **
set sdir_out = ${dir_lowres}
set lab_out  = "LOWRES"

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

# get list of all data to copy
cd ${dir_basic}
set all_dset = `find . -name "*.nii.gz" | cut -b3- | sort`

# work from top of output dir
cd ${sdir_out}

# data has ad3=(1.0, 1.0, 1.0), orient = RSP, and n4 = (208, 192, 208, 1)
foreach dset ( ${all_dset} )
    echo "++ PROC DSET: ${dset}"

    # get part of path, and make sure that exits in output dir
    set p1 = `dirname ${dset}`
    \mkdir -p ${p1}

    # get appropriate resampling mode for mask vs orig dset
    if ( `python -c "print(int('_mask' in '${dset}'))"` ) then
        echo "++ ... is mask"
        set rmode = NN
    else
        set rmode = Linear
    endif

    # resample to 4x4x4 mm**3... 
    3dresample                           \
        -dxyz    4 4 4                   \
        -rmode   ${rmode}                \
        -input   ${dir_basic}/${dset}    \
        -prefix  ${dset}

    if ( ${status} ) then
        set ecode = 1
        goto COPY_AND_EXIT
    endif

    # ... and make sure its dims are divisible by 16
    3dZeropad                            \
        -overwrite                       \
        -R -2 -L -2                      \
        -A -2 -P -2                      \
        -prefix ${dset}                  \
        ${dset}

    if ( ${status} ) then
        set ecode = 2
        goto COPY_AND_EXIT
    endif
end

echo "++ FINISHED ${lab_out}"

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

