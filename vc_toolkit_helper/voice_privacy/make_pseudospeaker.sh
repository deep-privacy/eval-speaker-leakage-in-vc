#!/bin/bash

set -e

#===== begin config =======

stage=0
nj=$(nproc)
voice_conversion_exp=""

pseudo_xvec_rand_level=spk  # spk (all utterances will have same xvector) or utt (each utterance will have randomly selected xvector)
cross_gender="false"        # true, same gender xvectors will be selected; false, other gender xvectors
distance="plda"             # cosine/plda
proximity="farthest"        # nearest/farthest
f0_transformation="false"   # apply f0 transformation
rand_seed=2020


. ./cmd.sh
. ./path.sh

. utils/parse_options.sh || exit 1;

data_netcdf=$(realpath $voice_conversion_exp/feats/am_nsf_data)   # directory where features for voice anonymization will be stored
mkdir -p $data_netcdf || exit 1;

BASEDIR=$(dirname $0)
VC_DIR=$BASEDIR/path

src_data=$1
target_spk=$2
anoni_pool=$(realpath $voice_conversion_exp)/data/libritts_train_other_500
anon_xvec_out_dir=$(realpath $voice_conversion_exp)/feats/anoni_pool

rm $anon_xvec_out_dir/xvectors_$src_data || true
ln -s $(realpath $voice_conversion_exp)/feats/x_vector/xvectors_$src_data $anon_xvec_out_dir/xvectors_$src_data

# X-Vector model used in the VoicePrivacy Challenge
xvec_nnet_dir=exp/models/2_xvect_extr/exp/xvector_nnet_1a
plda_dir=${xvec_nnet_dir}

data_realpath=$(realpath ".")/data

cd $VC_DIR
source ./path.sh
cd -

if [ $stage -le 0 ]; then
  printf "\n  ${GREEN}Stage 0: Generating pseudo-speakers for ${src_data}.${NC}\n"
  cd $VC_DIR
  local/anon/make_pseudospeaker.sh --rand-level ${pseudo_xvec_rand_level} \
    --cross-gender ${cross_gender} --distance ${distance} \
    --proximity ${proximity} --rand-seed ${rand_seed} \
    $data_realpath/$src_data $anoni_pool $anon_xvec_out_dir \
    ${plda_dir} || exit 1;
  cd -
fi


# cd $VC_DIR
# #  pchampio/F0_mod/extract_f0_stats.sh
# cd -

if [ $stage -le 1 ]; then
  printf "\n  ${GREEN}Stage 1: Generating feature for the vc system for ${src_data}.${NC}\n"
  ppg_out_dir=$(realpath $voice_conversion_exp)/feats/ppg

  cd $VC_DIR
  local/anon/make_netcdf.sh --f0_mod $f0_transformation $data_realpath/$src_data ${ppg_out_dir}/ppg_${src_data}/phone_post.scp \
    ${anon_xvec_out_dir}/xvectors_${src_data}/pseudo_xvecs/pseudo_xvector.scp \
    ${data_netcdf}/${src_data} || exit 1;
  cd -
fi

# PATCH ON VPC
if [ $stage -le 2 ]; then
  printf "\n  ${GREEN}Stage 2: converting to the same x-vector ${src_data}.${NC}\n"

  target_scp_xvector=${anon_xvec_out_dir}/xvectors_${src_data}/pseudo_xvecs/pseudo_xvector.scp
  if [[ $src_data = *"trials"*  ]]; then
    if [[ $src_data = *"dev"*  ]]; then
      target_scp_xvector=${anon_xvec_out_dir}/xvectors_libri_dev_enrolls/pseudo_xvecs/pseudo_xvector.scp
    fi
    if [[ $src_data = *"test"*  ]]; then
      target_scp_xvector=${anon_xvec_out_dir}/xvectors_libri_test_enrolls/pseudo_xvecs/pseudo_xvector.scp
    fi

    # take target scp from test for "libri_train_clean_360 voxceleb1_test"
    if [[ $src_data = *"train"*  ]]; then
      target_scp_xvector=${anon_xvec_out_dir}/xvectors_libri_test_enrolls/pseudo_xvecs/pseudo_xvector.scp
    fi
    if [[ $src_data = *"voxceleb1"*  ]]; then
      target_scp_xvector=${anon_xvec_out_dir}/xvectors_libri_test_enrolls/pseudo_xvecs/pseudo_xvector.scp
    fi
  fi

  python $BASEDIR/create_xvector_f0_data.py \
    $data_realpath/$src_data \
    ${anon_xvec_out_dir}/xvectors_${src_data}/pseudo_xvecs/pseudo_xvector.scp \
    ${data_netcdf}/${src_data} \
    $target_spk \
    $target_scp_xvector || exit 1
fi
