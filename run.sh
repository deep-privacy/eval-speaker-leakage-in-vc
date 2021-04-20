#!/bin/bash

set -e

#===== begin config =======

stage=4
sub_stage=0
sub_stage7=4
sub_sub_stage7=0
init_kaldi=false

export path_to_kaldi="/srv/storage/talc@talc-data.nancy/multispeech/calcul/users/pchampion/lab/voice_privacy/Voice-Privacy-Challenge-2020/kaldi"

vc_toolkit=voice_privacy
asr_eval_model=exp/models/asr_eval

# The Voice conversion system will be apply for all speakers to the same pseudospeaker.
pseudo_speaker_test_index=1

. utils/parse_options.sh || exit 1;

if $init_kaldi; then
  ln -s $path_to_kaldi/egs/wsj/s5/utils ./utils || true
  ln -s $path_to_kaldi/egs/wsj/s5/steps ./steps || true
  ln -s $path_to_kaldi/egs/sre08/v1/sid  ./sid || true
  echo "linking to kaldi done"
  exit 0
fi
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
  dset=libri
  for suff in dev test; do
    printf "${GREEN}\nStage 0: Downloading ${dset}_${suff} set...${NC}\n"
    local/download_data.sh ${dset}_${suff} || exit 1;
  done
fi

# Download pretrained models
if [ $stage -le 1 ]; then
  printf "${GREEN}\nStage 1: Downloading pretrained models...${NC}\n"
  local/download_models.sh || exit 1;
fi

voice_conversion_exp=$(realpath exp/vc_toolkit_exp_$vc_toolkit)
mkdir -p $voice_conversion_exp || exit 1;

if [ $stage -le 2 ]; then
printf "${GREEN}\nMaking evaluation subsets...${NC}\n"
  local/make_eval_dataset.sh || exit 1;
fi

if [ $stage -le 3 ]; then
  printf "${GREEN}\nStage 3: Preparing requirements for '$vc_toolkit'.${NC}\n"

  dataset="libri_test_enrolls libri_test_trials_f libri_test_trials_m"
  ./vc_toolkit_helper/$vc_toolkit/setup.sh --voice-conversion-exp $voice_conversion_exp \
    --stage 3 $dataset

  ./local/train_select_xvector.sh
fi

pseudo_speaker_test=$(cat ./exp/xvector_selected/spk_list.scp | tail -n+"$pseudo_speaker_test_index" | head -1 | cut -d" " -f1)

if [ $stage -le 4 ]; then
  printf "${GREEN}\nStage 4: Selecting pseudospeaker to anonymize the speech data.${NC}\n"

  echo
  echo "(Test) PseudoSpeaker selected $pseudo_speaker_test to anonymize train data"

  for name in libri_test\_{enrolls,trials_f,trials_m}; do
    ./vc_toolkit_helper/$vc_toolkit/make_pseudospeaker.sh --voice-conversion-exp $voice_conversion_exp \
      --stage $sub_stage $name $pseudo_speaker_test

  done
fi

if [ $stage -le 5 ]; then
  printf "${GREEN}\nStage 5: Converting Speech.${NC}\n"

  f_job=0 # failed job
  pids=() # initialize pids
  nvidia-smi >/dev/null 2>&1 || error_code=$?; if [[ "${error_code}" -eq 0 ]]; then ngpu=$(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l); fi
  ngpu=3 # Sync all jobs

  suff=test
  for name in libri_$suff\_{enrolls,trials_f,trials_m}; do

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

  [ ${f_job} -gt 0 ] && echo "$0: ${f_job} background jobs are failed." && exit 1

fi

if [ $stage -le 6 ]; then
  printf "${GREEN}\nStage 6.a: Evaluate datasets using speaker verification...${NC}\n"
  anon_data_dir=$(realpath $voice_conversion_exp)/data_anon/${src_data}-${pseudo_speaker_test}_anon

  # ASV_eval config
  asv_eval_model=exp/models/asv_eval/xvect_01709_1
  plda_dir=${asv_eval_model}/xvect_train_clean_360

  results="eval_spk_$pseudo_speaker_test"

  # for suff in dev test; do
  suff=test
    printf "${RED}**ASV: libri_${suff}_trials_f, enroll - anonymized, trial - anonymized**${NC}\n"
    local/asv_eval.sh --plda_dir $plda_dir --asv_eval_model $asv_eval_model \
      --enrolls libri_${suff}_enrolls-${pseudo_speaker_test}_anon --trials libri_${suff}_trials_f-${pseudo_speaker_test}_anon \
      --x-vector-ouput exp/anon_xvector_$pseudo_speaker_test \
      --results ./results/${vc_toolkit}/$results \
      --stage $sub_stage


    printf "${RED}**ASV: libri_${suff}_trials_m, enroll - anonymized, trial - anonymized**${NC}\n"
    local/asv_eval.sh --plda_dir $plda_dir --asv_eval_model $asv_eval_model \
      --enrolls libri_${suff}_enrolls-${pseudo_speaker_test}_anon --trials libri_${suff}_trials_m-${pseudo_speaker_test}_anon \
      --x-vector-ouput exp/anon_xvector_$pseudo_speaker_test \
      --results ./results/${vc_toolkit}/$results \
      --stage $sub_stage
  # done

  printf "${GREEN}\nStage 6.b: Performing intelligibility assessment using ASR decoding on $suff...${NC}\n"
  utils/combine_data.sh data/libri_${suff}-${pseudo_speaker_test}_asr_anon data/libri_${suff}_{trials_f,trials_m}-${pseudo_speaker_test}_anon || exit 1
  local/asr_eval.sh --dset libri_${suff}-${pseudo_speaker_test}_asr_anon --model $asr_eval_model --results ./results/${vc_toolkit}/$results || exit 1;
fi


if [ $stage -le 7 ]; then
  printf "${GREEN}\nStage 6.b: RETRAIN...${NC}\n"
  sudo-g5k nvidia-smi -c 3
  ./run-retrain-asv.sh --pseudo-speaker-test $pseudo_speaker_test --stage $sub_stage7 --sub_stage $sub_sub_stage7
fi

if [ $stage -le 8 ]; then
  printf "${GREEN}\nStage 8.a: Evaluate datasets using RETRAINED (ON test-spk) speaker verification...${NC}\n"
  anon_data_dir=$(realpath $voice_conversion_exp)/data_anon/${src_data}_anon

  # ASV_eval config
  # asv_eval_model=exp/models/asv_eval_b1_anon/xvect_01709_1
  # plda_dir=${asv_eval_model}/xvect_train_clean_360

  asv_eval_model=exp/retrain/for_anon_${pseudo_speaker_test}/xvect_01709_10
  plda_dir=${asv_eval_model}/xvect_train_clean_360-${pseudo_speaker_test}_anon

  results="eval_spk_${pseudo_speaker_test}_retrain"

  # for suff in dev test; do
  suff=test
    printf "${RED}**ASV: libri_${suff}_trials_f, enroll - anonymized, trial - anonymized**${NC}\n"
    local/asv_eval.sh --inverse_vad false --plda_dir $plda_dir --asv_eval_model $asv_eval_model \
      --enrolls libri_${suff}_enrolls-${pseudo_speaker_test}_anon --trials libri_${suff}_trials_f-${pseudo_speaker_test}_anon \
      --x-vector-ouput exp/anon_xvector_white-box_$pseudo_speaker_test \
      --results ./results/${vc_toolkit}/$results \
      --stage $sub_stage


    printf "${RED}**ASV: libri_${suff}_trials_m, enroll - anonymized, trial - anonymized**${NC}\n"
    local/asv_eval.sh --inverse_vad false --plda_dir $plda_dir --asv_eval_model $asv_eval_model \
      --enrolls libri_${suff}_enrolls-${pseudo_speaker_test}_anon --trials libri_${suff}_trials_m-${pseudo_speaker_test}_anon \
      --x-vector-ouput exp/anon_xvector_white-box_$pseudo_speaker_test \
      --results ./results/${vc_toolkit}/$results \
      --stage $sub_stage
  # done

fi

# exit 0
if [ $stage -le 9 ]; then

  # ASV_eval config
  asv_eval_model=exp/models/asv_eval/xvect_01709_1
  plda_dir=${asv_eval_model}/xvect_train_clean_360

  suff=test
    printf "${RED}**ASV: libri_${suff}_trials_m, enroll -  trial  == Original **${NC}\n"
    local/asv_eval.sh --inverse_vad false --plda_dir $plda_dir --asv_eval_model $asv_eval_model \
      --enrolls libri_${suff}_enrolls --trials libri_${suff}_trials_m \
      --x-vector-ouput exp/xvector_original \
      --results ./results/original_speech \
      --stage $sub_stage

    printf "${RED}**ASV: libri_${suff}_trials_m, enroll -  trial  == Original **${NC}\n"
    local/asv_eval.sh --inverse_vad false --plda_dir $plda_dir --asv_eval_model $asv_eval_model \
      --enrolls libri_${suff}_enrolls --trials libri_${suff}_trials_f \
      --x-vector-ouput exp/xvector_original \
      --results ./results/original_speech \
      --stage $sub_stage
fi
