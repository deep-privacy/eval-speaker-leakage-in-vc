#!/bin/bash

set -e

#===== begin config =======

stage=0
nj=$(nproc)
voice_conversion_exp=""

. ./cmd.sh
. ./path.sh

. utils/parse_options.sh || exit 1;

src_data=$1
target_spk=$2

BASEDIR=$(dirname $0)
VC_DIR=$BASEDIR/path

data_netcdf=$(realpath $voice_conversion_exp/feats/am_nsf_data-$target_spk)   # directory where features for voice anonymization will be stored
anon_xvec_out_dir=$(realpath $voice_conversion_exp)/feats/anoni_pool


if [ $stage -le 0 ]; then
  cd $VC_DIR
  printf "    ${GREEN}\nStage 0: Generate waveform from NSF model for ${src_data}.${NC}\n"
  local/vc/am/01_gen.sh ${data_netcdf}/${src_data} || exit 1;
  cd -
fi

if [ $stage -le 1 ]; then
  cd $VC_DIR
  printf "    ${GREEN}\nStage 1: Generate waveform from NSF model for ${src_data}.${NC}\n"
  local/vc/nsf/01_gen.sh ${data_netcdf}/${src_data} || exit 1;
  cd -
fi

if [ $stage -le 2 ]; then
  printf "    ${GREEN}\nStage 2: Creating new data directories corresponding to anonymization.${NC}\n"
  wav_path=${data_netcdf}/${src_data}/nsf_output_wav
  new_data_dir=data/${src_data}-${target_spk}_anon

  find "$wav_path" -maxdepth 1 -name "*.htk" -print0 | xargs -0 rm || true

  if [ -d "$new_data_dir" ]; then
    rm -rf ${new_data_dir}
  fi
  utils/copy_data_dir.sh data/${src_data} ${new_data_dir}
  [ -f ${new_data_dir}/feats.scp ] && rm ${new_data_dir}/feats.scp
  [ -f ${new_data_dir}/vad.scp ] && rm ${new_data_dir}/vad.scp
    # Copy new spk2gender in case cross_gender vc has been done
  cp ${anon_xvec_out_dir}/xvectors_${src_data}-$target_spk/pseudo_xvecs/spk2gender ${new_data_dir}/
  awk -v p="$wav_path" '{print $1, "sox", p"/"$1".wav", "-t wav -R -b 16 - |"}' data/${src_data}/wav.scp > ${new_data_dir}/wav.scp


  if [ -f data/$src_data/enrolls ]; then
    cp -v data/$src_data/enrolls $new_data_dir || exit 1
  else
    [ ! -f data/$src_data/trials ] && echo " -> File data/$src_data/trials does not exist!!!!!!" && exit 0;
    cp -v data/$src_data/trials $new_data_dir || exit 1
  fi
fi
