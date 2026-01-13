#!/bin/tcsh

# Script to combine the pred_mask and the target(groundtruth)

# notes
# 1) 'do_pred_plus_target.tcsh' is a post-script used before the
#    'do_combo_orig_olay_pred_plus_target.tcsh' script.
# 2)  An intermediate result is created where the predicted mask and the target are added.
# 3)  The intermediate result is named 'out_suffix.nii.gz'. The suffix is the the name of the dataset. 
# 4) 'do_combo_orig_olay_pred_plus_target.tcsh' script overlays the 'out_suffix.nii.gz'
#     over the priginal dataset

#folder structure
#  parent_dir     : parent directory (The full path is given )
#  dir_pred_mask  : folder which has the predicted masks 
#  dir_target     : folder which has the target masks (groundtruth)
#  dir_out        : folder where the result 'out_suffix.nii.gz' is written/stored

# usage example 
# tcsh do_pred_plus_target_cmd.tcsh /Users/narayanaswamyy2/AFNI_VNET/FQC_DA_c14ed246 

#echo "Script to combine the pred_mask and the target(groundtruth)"




# ---------------------------------------------------------------------------

if ( "`whoami`" == "narayanaswamyy2" ) then
    echo "++ Special stage to prepare for running on biowulf"
    source /data/NIMH_SSCC/ptaylor/miniconda3/etc/profile.d/conda.csh   \
           >& /dev/null
endif

# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------

echo "++ Set SLURM"
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

echo "++ Set ECODE"
# initial exit code; we don't exit at fail, to copy partial results back
set ecode = 0


set parent_dir    = $1  # cmd line arguement 
set dset_pred_mask = $2


set dir_target = "target"
set dir_pred_mask = "pred_mask"
set dir_pred_plus_target       = "pred_plus_target"
set dir_orig      = "orig"
set dir_combo      = "combo_images"
set dir_combo_full = "combo_full"

# set output directory
set sdir_out = ${dir_combo_full}
set lab_out  = "MAKE_COMBO"

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


set dset_target = `python -c "print('target_000_train_subj_'+ \
                   ''.join('sub-' + '${dset_pred_mask}'.split('sub-')[1]))"`

set dset_out = `python -c "print('out_' + \
               ''.join('sub-' + '${dset_pred_mask}'.split('sub-')[1]))"`

set dset_orig = `python -c "print('orig_train_subj_'+ \
                                 ''.join('sub-' + '${dset_pred_mask}'.split('sub-')[1]))"`

echo ${dset_orig}

echo ${dset_out}

set base  = `3dinfo -prefix_noext "${dset_target}"`


echo ${base}


set prefix = `python -c "print(''.join('sub-' + '${dset_target}'.split('sub-')[1]))"`
set prefix = `python -c "print('${prefix}'.split('.')[0])"`
echo "prefix"
echo ${prefix}
    # output prefix for montage image
set opref = IMG_${prefix}

echo "${parent_dir}/${dir_target}/${dset_target}"

	# combo is overlap mapped to 1(green)
	# a is vnet_pred_mask mapped to 3(red)
	# b is FS/target mask mapped to 2(blue)
3dcalc -prefix ${parent_dir}/${dir_pred_plus_target}/${dset_out}\
    -expr 'bool(ispositive(a-0.5)+b)*(4-(ispositive(a-0.5)+2*b))' \
    -a ${parent_dir}/${dir_pred_mask}/${dset_pred_mask} \
    -b ${parent_dir}/${dir_target}/${dset_target} \
    -overwrite 

     # make three PNGs
@chauffeur_afni                                  \
        -ulay  ${parent_dir}/${dir_orig}/${dset_orig}                          \
        -olay  ${parent_dir}/${dir_pred_plus_target}/${dset_out}                          \
        -box_focus_slices AMASK_FOCUS_OLAY           \
        -ulay_range 0% 98%                           \
        -func_range 3t                                  \
        -cbar "RedBlueGreen"                   \
        -pbar_posonly                                \
        -opacity     4                               \
        -blowup      2                               \
        -prefix      ${parent_dir}/${dir_combo}/${opref}                        \
        -montx 6 -monty 1                            \
        -set_xhairs OFF                              \
        -label_mode 1 -label_size 4                  \
        -do_clean 
        #-cmd2script        ${parent_dir}/${dir_combo}/${opref}_run.tcsh   \
        

    # glue together separate PNGs
    2dcat                                            \
        -gap     5                                   \
        -gap_col 150 150 150                         \
        -nx 1                                        \
        -ny 3                                        \
        -prefix  ${parent_dir}/${dir_combo}/${opref}.jpg                  \
        ${parent_dir}/${dir_combo}/${opref}*{sag,axi,cor}*png

if ( $status ) then
    echo "** ERROR: exit, badness for: ${dset_out}"
    exit 1
endif


    # clean up, remove separate PNGs
\rm ${parent_dir}/${dir_combo}/${opref}*{sag,axi,cor}*png

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



end	