#!/usr/bin/env bash

mkdir -p exp/oar-log/

  # oarsub -p "cluster='gros'" -l walltime=00:45 --stderr=exp/oar-log/%jobid%-${pseudo_speaker_test}-err-more.log --stdout=exp/oar-log/%jobid%-${pseudo_speaker_test}-out-more.log "./run.sh --pseudo-speaker-test-index 5 --stage 8 --sub-stage 3"
  # exit 0

log_suffix=random_select_test_asr
for i in {1..100}
do
  pseudo_speaker_test=$(cat ./exp/xvector_selected_rand_100/spk_list.scp | tail -n+"$i" | head -1 | cut -d" " -f1)
# , 'graffiti-8.nancy.grid5000.fr', 'graffiti-9.nancy.grid5000.fr', 'graffiti-10.nancy.grid5000.fr', 'graffiti-11.nancy.grid5000.fr', 'graffiti-12.nancy.grid5000.fr', 'graffiti-13.nancy.grid5000.fr', 'graffiti-7.nancy.grid5000.fr'

  # oarsub -q production -p "host in ('graffiti-2.nancy.grid5000.fr', 'graffiti-3.nancy.grid5000.fr', 'graffiti-4.nancy.grid5000.fr', 'graffiti-5.nancy.grid5000.fr')" -l walltime=2:30 --stderr=exp/oar-log/%jobid%-${pseudo_speaker_test}-err-$log_suffix.log --stdout=exp/oar-log/%jobid%-${pseudo_speaker_test}-out-$log_suffix.log "./run.sh --pseudo-speaker-test-index $i"
  oarsub -q production -p "host in ('grimani-1.nancy.grid5000.fr', 'grimani-2.nancy.grid5000.fr', 'grimani-3.nancy.grid5000.fr', 'grimani-4.nancy.grid5000.fr')" -l walltime=4:30 --stderr=exp/oar-log/%jobid%-${pseudo_speaker_test}-err-$log_suffix.log --stdout=exp/oar-log/%jobid%-${pseudo_speaker_test}-out-$log_suffix.log "./run.sh --pseudo-speaker-test-index $i"

  # oarsub -q production -p "cluster='grappe'" -l walltime=03:45 --stderr=exp/oar-log/%jobid%-${pseudo_speaker_test}-err-$log_suffix.log --stdout=exp/oar-log/%jobid%-${pseudo_speaker_test}-out-$log_suffix.log "./run.sh --pseudo-speaker-test-index $i --stage 9 --sub-stage 0"
  # exit 0
done

# "cluster='graffiti'"
# graffiti cluster 1 gpu 0 always fails
# "host in ('graffiti-2.nancy.grid5000.fr', 'graffiti-3.nancy.grid5000.fr', 'graffiti-4.nancy.grid5000.fr', 'graffiti-5.nancy.grid5000.fr', 'graffiti-6.nancy.grid5000.fr', 'graffiti-7.nancy.grid5000.fr', 'graffiti-8.nancy.grid5000.fr', 'graffiti-9.nancy.grid5000.fr', 'graffiti-10.nancy.grid5000.fr', 'graffiti-11.nancy.grid5000.fr', 'graffiti-12.nancy.grid5000.fr', 'graffiti-13.nancy.grid5000.fr')"
