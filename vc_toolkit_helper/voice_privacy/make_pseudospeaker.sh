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
f0_transformation="true"   # apply f0 transformation
rand_seed=2020


. ./cmd.sh
. ./path.sh

. utils/parse_options.sh || exit 1;

BASEDIR=$(dirname $0)
VC_DIR=$BASEDIR/path

src_data=$1
target_spk=$2
anoni_pool=$(realpath $voice_conversion_exp)/data/libritts_train_other_500
anon_xvec_out_dir=$(realpath $voice_conversion_exp)/feats/anoni_pool

data_netcdf=$(realpath $voice_conversion_exp/feats/am_nsf_data/)   # directory where features for voice anonymization will be stored
mkdir -p $data_netcdf || exit 1;

printf "\n  ${GREEN}Stage 0: Making recursive symbolic link.\n"

out_dir=${data_netcdf}-$target_spk/${src_data}
rm -rf $out_dir || true
mkdir -p $out_dir

# cp -f --recursive --symbolic-link  ${data_netcdf}/${src_data}/f0 /tmp/f0 || exit 1;
# ln -s ${data_netcdf}/${src_data}/scp $out_dir/scp || true
# ln -s ${data_netcdf}/${src_data}/xvector $out_dir/xvector || true
# ln -s ${data_netcdf}/${src_data}/f0 $out_dir/f0 || true
ln -s ${data_netcdf}/${src_data}/ppg $out_dir/ppg || true

data_netcdf=$data_netcdf-$target_spk

rm -rf $anon_xvec_out_dir/xvectors_$src_data-$target_spk || true

cp --recursive --symbolic-link  $(realpath $voice_conversion_exp)/feats/x_vector/xvectors_$src_data \
  $anon_xvec_out_dir/xvectors_$src_data-$target_spk || exit 1;

echo "cp -f --recursive --symbolic-link  $(realpath $voice_conversion_exp)/feats/x_vector/xvectors_$src_data  $anon_xvec_out_dir/xvectors_$src_data-$target_spk"
printf "\n  ${GREEN}Stage 0: [Done] Making recursive symbolic link.\n"

# X-Vector model used in the VoicePrivacy Challenge
xvec_nnet_dir=exp/models/2_xvect_extr/exp/xvector_nnet_1a
plda_dir=${xvec_nnet_dir}

data_realpath=$(realpath ".")/data

cd $VC_DIR
source ./path.sh

# initialize pytools
. local/vc/am/init.sh

cd -


if [ $stage -le 0 ]; then
  out_dir=${data_netcdf}/${src_data}

  rm -rf /tmp/f0/$target_spk/${src_data} /tmp/xvector/$target_spk/${src_data}
  mkdir -p $out_dir/scp /tmp/f0/$target_spk/${src_data} /tmp/xvector/$target_spk/${src_data} $out_dir/ppg
  # mkdir -p $out_dir/scp $out_dir/xvector $out_dir/f0 $out_dir/ppg
  ln -s /tmp/xvector/$target_spk/${src_data} $out_dir/xvector
  ln -s /tmp/f0/$target_spk/${src_data} $out_dir/f0

  echo "Writing SCP file.."
  cut -f 1 -d' ' $data_realpath/$src_data/utt2spk > ${out_dir}/scp/data.lst || exit 1;
fi

# if [ $stage -le 1 ]; then
  # printf "\n  ${GREEN}Stage 1: Generating feature for the vc system for ${src_data}.${NC}\n"
  # ppg_out_dir=$(realpath $voice_conversion_exp)/feats/ppg

  # cd $VC_DIR
  # ppg_file=${ppg_out_dir}/ppg_${src_data}/phone_post.scp
  # python local/featex/create_ppg_data.py ${ppg_file} ${data_netcdf}/${src_data} || exit 1;
  # cd -
# fi


target_scp_xvector=$(realpath ".")/exp/xvector_selected/spk_list.scp
dataset_of_target=libritts_train_other_500

# PATCH ON VPC
if [ $stage -le 2 ]; then
  printf "\n  ${GREEN}Stage 2: converting to the same x-vector ${src_data}.${NC}\n"

  python $BASEDIR/create_xvector_f0_data.py \
    "$data_realpath/$src_data" \
    ${anon_xvec_out_dir}/xvectors_${src_data}-$target_spk/xvector.scp \
    ${data_netcdf}/${src_data} \
    $target_spk \
    $target_scp_xvector

  if $f0_transformation; then
    cd $VC_DIR
    f0_out_dir=$(realpath $voice_conversion_exp)/feats/f0/${src_data}
    mkdir -p $f0_out_dir
    if [[ ! -d $f0_out_dir ]]
    then
      echo "Extracting F0 statistic for linear pitch transformation"
      python ./pchampio/F0_mod/create_xvector_f0_map.py "$data_realpath/$src_data" "unused" $f0_out_dir
    fi
    cd -

    echo "Apply linear transformation on F0."
    python $BASEDIR/transform_f0_data.py ./data/${src_data} $target_spk ${data_netcdf}/${src_data} ${dataset_of_target} || exit 1;
  fi
fi


if [ $stage -le 3 ]; then
  printf "\n  ${GREEN}Stage 3: Writing pseudo-speaker spk2gender.\n"
  genderTarget=$(cat ./data/${dataset_of_target}/spk2gender | grep  "^$target_spk" | head -n 1 | awk ' { print $2 }')
  mkdir -p ${anon_xvec_out_dir}/xvectors_${src_data}-$target_spk/pseudo_xvecs/
  cat ./data/${src_data}/spk2utt | awk  "{ print \$1  \" ${genderTarget}\" }" > ${anon_xvec_out_dir}/xvectors_${src_data}-$target_spk/pseudo_xvecs/spk2gender
fi
