#!/bin/bash

set -e

#===== begin config =======

stage=4
sub_stage=0

export path_to_kaldi="/srv/storage/talc@talc-data.nancy/multispeech/calcul/users/pchampion/lab/voice_privacy/Voice-Privacy-Challenge-2020/kaldi"

vc_toolkit=voice_privacy

# The Voice conversion system will be apply for all speakers to the same pseudospeaker.
pseudo_speaker_dev_index=1
pseudo_speaker_test_index=1

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
  voxceleb1_root=./corpus

  "$path_to_kaldi/egs/voxceleb/v1/local/make_voxceleb1_v2.pl" $voxceleb1_root test data/voxceleb1_test
  exit
fi

voice_conversion_exp=$(realpath exp/vc_toolkit_exp_$vc_toolkit)
mkdir -p $voice_conversion_exp || exit 1;

if [ $stage -le 3 ]; then
  printf "${GREEN}\nStage 3: Preparing requirements for '$vc_toolkit'.${NC}\n"

  dataset="libri_train_clean_360 voxceleb1_test"
  ./vc_toolkit_helper/$vc_toolkit/setup.sh --voice-conversion-exp $voice_conversion_exp \
    --stage $sub_stage $dataset
fi

if [ $stage -le 4 ]; then
  printf "${GREEN}\nStage 4: Selecting pseudospeaker to anonymize the speech data.${NC}\n"
  pseudo_speaker_dev=""
  pseudo_speaker_test=""
  for suff in dev test; do
    temp=$(mktemp)
    for name in libri_$suff\_{trials_f,trials_m}; do
      src_spk2gender=data/$name/spk2gender
      cut -d\  -f 1 ${src_spk2gender} >> $temp
    done
    printf "\nSpeaker list in $name ($(cat $temp | wc -l)): "
    cat $temp | while read s; do
      echo -n $s", "
    done
    echo

    spk_pseudo="pseudo_speaker_${suff}_index"
    mk_psuedospk_for=$(cat $temp | tail -n+"${!spk_pseudo}" | head -1)
    if [ $suff = "dev" ]; then
      pseudo_speaker_dev=$mk_psuedospk_for
    else
      pseudo_speaker_test=$mk_psuedospk_for
    fi
    rm $temp
  done

  echo "(Test) PseudoSpeaker selected from $pseudo_speaker_test (Test) to anonymize train data"

  dataset="libri_train_clean_360 voxceleb1_test"
  for name in $(echo $1 | tr " " "\n"); do
    ./vc_toolkit_helper/$vc_toolkit/make_pseudospeaker.sh --voice-conversion-exp $voice_conversion_exp \
      --stage $sub_stage $name $pseudo_speaker_test
  done
fi

if [ $stage -le 5 ]; then
  printf "${GREEN}\nStage 5: Converting Speech.${NC}\n"

  f_job=0 # failed job
  pids=() # initialize pids
  ngpu=1 # Sync all jobs
  nvidia-smi >/dev/null 2>&1 || error_code=$?; if [[ "${error_code}" -eq 0 ]]; then ngpu=$(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l); fi

  datadir=data/libri_train_clean_360
  echo "Spliting $datadir in $ngpu"
  utils/split_data.sh $datadir $ngpu

  split_train360=
  for n in $(seq $ngpu); do
    split_train360="$split_train360 $(basename $datadir)/split$ngpu/$n"
  done
  dataset="$split_train360 voxceleb1_test"
  echo $dataset
  exit

  for name in $(echo $1 | tr " " "\n"); do
    i_GPU=${#pids[@]}
    (
      echo "Running anon $name on GPU $i_GPU"

      $train_cmd ${voice_conversion_exp}/log/anonymize_data_dir.${name}.log \
        CUDA_VISIBLE_DEVICES=$i_GPU \
        ./vc_toolkit_helper/$vc_toolkit/anonymize_data_dir.sh --voice-conversion-exp $voice_conversion_exp \
          --stage $sub_stage $name
    ) &
    pids+=($!) # store background pids

    if [ ${#pids[@]} -gt $((ngpu-1)) ];then for pid in "${pids[@]}"; do wait ${pid} || ((++f_job)) && pids=( "${pids[@]:1}" ) ; done; fi;
  done

  [ ${f_job} -gt 0 ] && echo "$0: ${f_job} background jobs are failed." && false

fi

if [ $stage -le 6 ]; then
  printf "${GREEN}\nStage 6: Evaluate datasets using speaker verification...${NC}\n"
  anon_data_dir=$(realpath $voice_conversion_exp)/data_anon/${src_data}_anon

  # ASV_eval config
  asv_eval_model=exp/models/asv_eval/xvect_01709_1
  plda_dir=${asv_eval_model}/xvect_train_clean_360

  printf -v results '%(%Y-%m-%d-%H-%M-%S)T' -1
  results="test"

  for suff in dev test; do
    printf "${RED}**ASV: libri_${suff}_trials_f, enroll - anonymized, trial - anonymized**${NC}\n"
    local/asv_eval.sh --plda_dir $plda_dir --asv_eval_model $asv_eval_model \
      --enrolls libri_${suff}_enrolls_anon --trials libri_${suff}_trials_f_anon \
      --x-vector-ouput exp/anon_xvector \
      --results ./results/${vc_toolkit}/$results \
      --stage $sub_stage || exit 1;


    printf "${RED}**ASV: libri_${suff}_trials_m, enroll - anonymized, trial - anonymized**${NC}\n"
    local/asv_eval.sh --plda_dir $plda_dir --asv_eval_model $asv_eval_model \
      --enrolls libri_${suff}_enrolls_anon --trials libri_${suff}_trials_m_anon \
      --x-vector-ouput exp/anon_xvector \
      --results ./results/${vc_toolkit}/$results \
      --stage $sub_stage || exit 1;
  done
fi
