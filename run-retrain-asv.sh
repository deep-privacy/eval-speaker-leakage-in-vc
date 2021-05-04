#!/bin/bash

set -e

#===== begin config =======

stage=4
sub_stage=0

export path_to_kaldi="/srv/storage/talc@talc-data.nancy/multispeech/calcul/users/pchampion/lab/voice_privacy/Voice-Privacy-Challenge-2020/kaldi"

vc_toolkit=voice_privacy

pseudo_speaker_test=

. utils/parse_options.sh || exit 1;

if [ $vc_toolkit = "voice_privacy" ]; then
  vc_toolkit_path="/srv/storage/talc@talc-data.nancy/multispeech/calcul/users/pchampion/lab/voice_privacy/Voice-Privacy-Challenge-2020/baseline"

  if [ ! -d "./vc_toolkit_helper/$vc_toolkit/path" ]; then
    ln -s  $vc_toolkit_path ./vc_toolkit_helper/$vc_toolkit/path
  fi
fi

. ./cmd.sh
. ./path.sh

# Download datasets
if [ $stage -le 0 ]; then
  data_url_librispeech=www.openslr.org/resources/12  # Link to download LibriSpeech corpus
  # $path_to_kaldi/egs/librispeech/s5/local/download_and_untar.sh "." $data_url_librispeech train-clean-360

  # The trials file is downloaded by local/make_voxceleb1_v2.pl.
  # In order to download VoxCeleb-1 corpus, please go to: http://www.robots.ox.ac.uk/~vgg/data/voxceleb/
  voxceleb1_root=$(realpath corpus)

  "$path_to_kaldi/egs/voxceleb/v1/local/make_voxceleb1_v2.pl" $voxceleb1_root test data/voxceleb1_test
fi

voice_conversion_exp=$(realpath exp/vc_toolkit_exp_$vc_toolkit)
mkdir -p $voice_conversion_exp || exit 1;


f_job=0 # failed job
pids=() # initialize pids
ngpu=1 # Sync all jobs
nvidia-smi >/dev/null 2>&1 || error_code=$?; if [[ "${error_code}" -eq 0 ]]; then real_ngpu=$(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l); fi
ngpu=4 # Sync all jobs
[ $ngpu -gt $real_ngpu ] && ngpu=$real_ngpu

datadir=data/libri_train_clean_360
echo "Spliting $datadir in $ngpu"
utils/split_data.sh $datadir $ngpu

split_train360=
for n in $(seq $ngpu); do
  split_dataset=$(echo "$(basename $datadir)/split$ngpu/$n" | tr "/" "_")
  rm -rf data/"$split_dataset" || true
  ln -s "$(basename $datadir)/split$ngpu/$n" data/"$split_dataset"
  split_train360="$split_train360 $split_dataset"
done
dataset="$split_train360"

if [ $stage -le 3 ]; then
  printf "${GREEN}\nStage 3: Preparing requirements for '$vc_toolkit'.${NC}\n"
  ./vc_toolkit_helper/$vc_toolkit/setup.sh --voice-conversion-exp $voice_conversion_exp \
    --stage 3 "$dataset"
fi

# if [ -d "data/libri_train_clean_360-${pseudo_speaker_test}_anon" ]; then
  # validate_data_dir.sh  "data/libri_train_clean_360-${pseudo_speaker_test}_anon"
  # RESULT=$?
  # if [ $RESULT -eq 0 ]; then
    # stage=7
  # fi
# fi

if [ $stage -le 4 ]; then
  printf "${GREEN}\nStage 4: Selecting pseudospeaker to anonymize the speech data.${NC}\n"

  echo "(Test) PseudoSpeaker selected $pseudo_speaker_test to anonymize train data"

  for name in $(echo $dataset | tr " " "\n"); do
    ./vc_toolkit_helper/$vc_toolkit/make_pseudospeaker.sh --voice-conversion-exp $voice_conversion_exp \
      --stage $sub_stage $name $pseudo_speaker_test &
  done
  wait
fi

if [ $stage -le 5 ]; then
  printf "${GREEN}\nStage 5: Converting Speech.${NC}\n"

  for name in $(echo $dataset | tr " " "\n"); do
    i_GPU=${#pids[@]}
    (
      echo "Running anon $name on GPU $i_GPU - ${voice_conversion_exp}/log/anonymize_data_dir.${name}-$pseudo_speaker_test.log"

      $train_cmd ${voice_conversion_exp}/log/anonymize_data_dir.${name}-$pseudo_speaker_test.log \
        CUDA_VISIBLE_DEVICES=$i_GPU \
        ./vc_toolkit_helper/$vc_toolkit/anonymize_data_dir.sh --voice-conversion-exp $voice_conversion_exp \
          --stage $sub_stage $name $pseudo_speaker_test
    ) &
    pids+=($!) # store background pids

    if [ ${#pids[@]} -gt $((ngpu-1)) ];then for pid in "${pids[@]}"; do wait ${pid} || ((++f_job)) && pids=( "${pids[@]:1}" ) ; done; fi;
  done
  wait

  [ ${f_job} -gt 0 ] && echo "$0: ${f_job} background jobs are failed." && exit 1
fi

if [ $stage -le 6 ]; then
  printf "${GREEN}\nStage 6: Preparing dataset for x-vector training.${NC}\n"
  libri_train=$(echo $dataset | cut -f1-$ngpu -d" " | tr " " "\n" | awk -v a=$pseudo_speaker_test '{print $0"-"a}' | awk '{print "data/"$1"_anon"}')
  utils/combine_data.sh data/libri_train_clean_360-${pseudo_speaker_test}_anon $libri_train
  tmp=$(mktemp)
  cp data/libri_train_clean_360-${pseudo_speaker_test}_anon/spk2gender $tmp
  cat $tmp | sed  "s/\([0-9]*\).*\(.\)/\1 \2/" | sort  | uniq > data/libri_train_clean_360-${pseudo_speaker_test}_anon/spk2gender
  rm $tmp
  cp data/libri_train_clean_360_utt2spk data/libri_train_clean_360-${pseudo_speaker_test}_anon/utt2spk
  cp data/libri_train_clean_360_spk2utt data/libri_train_clean_360-${pseudo_speaker_test}_anon/spk2utt
fi

if [ $stage -le 7 ]; then
  sleep 3
  ./run_asv_eval_train.sh --stage $sub_stage --train_dir_slug "for_anon_${pseudo_speaker_test}" --pseudo-speaker-test ${pseudo_speaker_test}
fi
