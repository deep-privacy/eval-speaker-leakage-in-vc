#!/usr/bin/env bash

export path_to_kaldi="/srv/storage/talc@talc-data.nancy/multispeech/calcul/users/pchampion/lab/voice_privacy/Voice-Privacy-Challenge-2020/kaldi"
. ./cmd.sh
. ./path.sh

pool_data="vc_toolkit_helper/voice_privacy/path/data/libritts_train_other_500"
xvec_out_dir="vc_toolkit_helper/voice_privacy/path/exp/models/2_xvect_extr/exp/xvector_nnet_1a/anon/xvectors_libritts_train_other_500"
combine_genders=false
init_ln=false # ln voice_privacy libritts_train_other_500 to this toolkit
output_x_vec_select="exp/xvector_selected_rand_100"

. utils/parse_options.sh || exit 1;

mkdir -p $output_x_vec_select

if $init_ln; then
  ln -s $(pwd)/$xvec_out_dir  exp/models/2_xvect_extr/exp/xvector_nnet_1a/anon/
fi

rm $output_x_vec_select/*

python3 local/train_select_xvector_rand.py $pool_data $xvec_out_dir $combine_genders $output_x_vec_select
