#!/bin/bash

set -e

#===== begin config =======

export path_to_kaldi="/srv/storage/talc@talc-data.nancy/multispeech/calcul/users/pchampion/lab/voice_privacy/Voice-Privacy-Challenge-2020/kaldi"
asr_eval_model=exp/models/asr_eval

. utils/parse_options.sh || exit 1;

. ./cmd.sh
. ./path.sh

printf "${GREEN}\nStage 6.b: Performing intelligibility assessment using ASR decoding on original speaker used as a target${NC}\n"

# cat ./exp/xvector_selected/spk_list.scp | cut -d\  -f1 > ./exp/xvector_selected/spklist

# subset_data_dir.sh --spk-list ./exp/xvector_selected/spklist ./data/libritts_train_other_500 ./data/libritts_train_other_500_xvector_selected

# local/asr_eval.sh --dset libritts_train_other_500_xvector_selected --model $asr_eval_model --results ./results/original_speech/xvector_selected || exit 1
# exit 1

TMPFILE=$(mktemp /tmp/example.XXXXXXXXXX) || exit 1

for i in {1..40}
do
  pseudo_speaker_test=$(cat ./exp/xvector_selected/spk_list.scp | tail -n+"$i" | head -1 | cut -d" " -f1)
  echo $pseudo_speaker_test > $TMPFILE
  subset_data_dir.sh --spk-list $TMPFILE ./data/libritts_train_other_500 ./data/libritts_train_other_500_xvector_selected_$pseudo_speaker_test


  (
  # local/asr_eval.sh --dset libritts_train_other_500_xvector_selected_$pseudo_speaker_test --model $asr_eval_model --results ./results/original_speech/xvector_selected_$pseudo_speaker_test || exit 1

  scoringAnalysis.sh --dataDir ./data/libritts_train_other_500_xvector_selected_$pseudo_speaker_test \
      --decodeDir ./exp/models/asr_eval/decode_libritts_train_other_500_xvector_selected_${pseudo_speaker_test}_tgsmall \
      --langDir ./exp/models/asr_eval/lang_test_tgsmall || exit 1;
  echo "OK"

  scoringAnalysis.sh --dataDir ./data/libritts_train_other_500_xvector_selected_$pseudo_speaker_test \
      --decodeDir ./exp/models/asr_eval/decode_libritts_train_other_500_xvector_selected_${pseudo_speaker_test}_tglarge \
      --langDir ./exp/models/asr_eval/lang_test_tglarge || exit 1;
  echo "OK"


  grep WER ./exp/models/asr_eval/decode_libritts_train_other_500_xvector_selected_${pseudo_speaker_test}_tglarge/wer* | utils/best_wer.sh | tee -a ./results/original_speech/xvector_selected_$pseudo_speaker_test/ASR-libritts_train_other_500_xvector_selected_$pseudo_speaker_test
  exit 0
  ) &
done
wait

rm $TMPFILE
