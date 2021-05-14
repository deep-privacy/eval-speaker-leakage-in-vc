#!/usr/bin/env bash

for i in {1..100}
do
  pseudo_speaker_test=$(cat ./exp/xvector_selected_rand_100/spk_list.scp | tail -n+"$i" | head -1 | cut -d" " -f1)

  ./scoringAnalysis.sh --dataDir ./data/libri_test-${pseudo_speaker_test}_asr_anon  --decodeDir ./exp/models/asr_eval/decode_libri_test-${pseudo_speaker_test}_asr_anon_tglarge --langDir ./exp/models/asr_eval/lang_test_tglarge
done
