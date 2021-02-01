#!/usr/bin/env bash

mkdir -p exp/oar-log/

for i in {1..40}
do
  pseudo_speaker_test=$(cat ./exp/xvector_selected/spk_list.scp | tail -n+"$i" | head -1 | cut -d" " -f1)
# , 'graffiti-8.nancy.grid5000.fr', 'graffiti-9.nancy.grid5000.fr', 'graffiti-10.nancy.grid5000.fr', 'graffiti-11.nancy.grid5000.fr', 'graffiti-12.nancy.grid5000.fr', 'graffiti-13.nancy.grid5000.fr', 'graffiti-7.nancy.grid5000.fr'
  oarsub -q production -p "host in ('graffiti-4.nancy.grid5000.fr', 'graffiti-5.nancy.grid5000.fr', 'graffiti-6.nancy.grid5000.fr', 'graffiti-7.nancy.grid5000.fr', 'graffiti-8.nancy.grid5000.fr', 'graffiti-9.nancy.grid5000.fr', 'graffiti-11.nancy.grid5000.fr')" -l walltime=44:00 --stderr=exp/oar-log/%jobid%-${pseudo_speaker_test}-err.log --stdout=exp/oar-log/%jobid%-${pseudo_speaker_test}-out.log "./run.sh --pseudo-speaker-test-index $i"
done

# "cluster='graffiti'"
# graffiti cluster 1 gpu 0 always fails
# "host in ('graffiti-2.nancy.grid5000.fr', 'graffiti-3.nancy.grid5000.fr', 'graffiti-4.nancy.grid5000.fr', 'graffiti-5.nancy.grid5000.fr', 'graffiti-6.nancy.grid5000.fr', 'graffiti-7.nancy.grid5000.fr', 'graffiti-8.nancy.grid5000.fr', 'graffiti-9.nancy.grid5000.fr', 'graffiti-10.nancy.grid5000.fr', 'graffiti-11.nancy.grid5000.fr', 'graffiti-12.nancy.grid5000.fr', 'graffiti-13.nancy.grid5000.fr')"
