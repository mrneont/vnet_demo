#!/bin/tcsh

# TRAIN: run the VNET on training data
# -> on FULL RES data

# Run this script from its partner run*.tcsh script.
# Can be run on either a slurm/swarm system (like Biowulf) or on a desktop.

# ---------------------------------------------------------------------------

if ( "`whoami`" == "taylorpa3" ) then
    echo "++ Special stage to prepare for running on biowulf"
    source /data/NIMH_SSCC/ptaylor/miniconda3/etc/profile.d/conda.csh   \
           >& /dev/null
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
set dir_train      = ${dir_inroot}/data_03_train
set dir_aug_full   = ${dir_inroot}/data_12_aug_full
set dir_train_full = ${dir_inroot}/data_13_train_full

# supplementary directory (reference data, etc.)
set dir_suppl      = ${dir_inroot}/supplements

# set output directory **
set sdir_out = ${dir_train_full}
set lab_out  = "TRAIN_FULL_VNET"

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
###echo "++ Load conda env: test_cuda_env2"
###conda activate test_cuda_env2
echo "++ Load conda env: vnet_tech_2024_01_02"
conda activate vnet_tech_2024_01_02

if ( $status ) then
    echo "** ERROR: not finding conda env"
    set ecode = 1
    goto COPY_AND_EXIT
endif

# at the moment, need to run this program from the directory that has
# related scripts
#### NB: to run sorensen, validation dsets also need EDT
cd ${dir_vnet_run}
python run_ml_ss.py                                                          \
    -input_dir             ${dir_aug_full}                                   \
    -output_dir            ${sdir_out}                                       \
    -train_batch_size      3                                                 \
    -num_epochs            20                                                \
    -do_write_nifti        1                                                 \
    -save_mask_rate        5                                                 \
    -save_checkpoint_rate  10                                                \
    -loss_func             'WtSorensen_Dice'                                 \
    -verb                  1

if ( ${status} ) then
    set ecode = 2
    goto COPY_AND_EXIT
endif

if ( 0 ) then
   `python run_ml_ss.py 
      -d 'training_dataset_path' 
      -o 'output_dir_path' 
      -e epoch_num 
      -s seed 
      -l learning_rate 
      -dn data_normalization 
      -L  Loss_function 
      -W  write_to_output_dir_path 
      -trb batch_size_training 
      -tr_shuf shuffle_flag 
      -mask_everyn 1 
      -chpt_everyn 1 
      -r 1 `
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

