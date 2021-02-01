#!/usr/bin/env bash

export path_to_kaldi="/srv/storage/talc@talc-data.nancy/multispeech/calcul/users/pchampion/lab/voice_privacy/Voice-Privacy-Challenge-2020/kaldi"
. ./cmd.sh
. ./path.sh

pip_install=false

dataset="dev" # dev or test
datatype="anon" # original or anon or all
level="utt" # utt or spk
folder="exp/anon_xvector" # or exp/anon_xvector_white-box

. utils/parse_options.sh || exit 1;

if $pip_install; then
  pip3 install kaldi_io==0.9.4 --user
  pip3 install h5py=2.10.0 --user
  pip3 install seaborn==0.11.0 --user
  pip3 install sklearn --user
fi

BASEDIR=$(dirname $0)

basedir="$(realpath ".")"


echo "==="
ls $folder/xvect_libri_${dataset}_trials_m_anon/ | grep -E ".*[0-9]+.scp" | while read -r line ; do
cat $folder/xvect_libri_${dataset}_trials_m_anon//$line
done | cut -d'-' -f1 | uniq | awk '{a[$0]++}END{for(i in a){if(a[i]-1)print i,a[i]}}' | sort -n
echo "==="
echo "If there is line between ===, the xvectors.scp files arn't splited by speakers"

python3 $BASEDIR/kaldi_plot_xvectors.py \
  $basedir \
  $dataset  $datatype $level $folder
