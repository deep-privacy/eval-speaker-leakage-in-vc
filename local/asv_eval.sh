#!/bin/bash

set -e

. ./cmd.sh
. ./path.sh

nj=$(nproc)
asv_eval_model=exp/models/asv_eval/xvect_01709_1
plda_dir=$asv_eval_model/xvect_train_clean_360
x_vector_ouput=$asv_eval_model

enrolls=libri_dev_enrolls
trials=libri_dev_trials_f

printf -v results '%(%Y-%m-%d-%H-%M-%S)T' -1
results=exp/results-$results

stage=0

. ./utils/parse_options.sh

for name in $asv_eval_model/final.raw $plda_dir/plda $plda_dir/mean.vec \
    $plda_dir/transform.mat data/$enrolls/enrolls data/$trials/trials ; do
  [ ! -f $name ] && echo "File $name does not exist" && exit 1
done

if [ $stage -le 0 ]; then
  for dset in $enrolls $trials; do
    data=data/$dset
    spk2utt=$data/spk2utt
    [ ! -f $spk2utt ] && echo "File $spk2utt does not exist" && exit 1
    num_spk=$(wc -l < $spk2utt)
    njobs=$([ $num_spk -le $nj ] && echo $num_spk || echo $nj)
      printf "${RED}  compute MFCC: $dset${NC}\n"
      steps/make_mfcc.sh --nj $njobs --cmd "$train_cmd" \
        --write-utt2num-frames true $data || exit 1
      utils/fix_data_dir.sh $data || exit 1
      printf "${RED}  compute VAD: $dset${NC}\n"
      sid/compute_vad_decision.sh --nj $njobs --cmd "$train_cmd" $data || exit 1
      utils/fix_data_dir.sh $data || exit 1
  done

  for dset in $enrolls $trials; do
    data=data/$dset
    spk2utt=$data/spk2utt
    [ ! -f $spk2utt ] && echo "File $spk2utt does not exist" && exit 1
    num_spk=$(wc -l < $spk2utt)
    njobs=$([ $num_spk -le $nj ] && echo $num_spk || echo $nj)
      printf "${RED}  compute x-vect: $dset${NC}\n"
      sid/nnet3/xvector/extract_xvectors.sh --nj $njobs --cmd "$train_cmd" \
        $asv_eval_model $data $x_vector_ouput/xvect_$dset || exit 1
  done
fi

expo=$results/ASV-$enrolls-$trials
mkdir -p $expo

if [ $stage -le 1 ]; then
  printf "${RED}  ASV scoring: $expo${NC}\n"
  xvect_enrolls=$x_vector_ouput/xvect_$enrolls/xvector.scp
  xvect_trials=$x_vector_ouput/xvect_$trials/xvector.scp

  for name in $xvect_enrolls $xvect_trials; do
    [ ! -f $name ] && echo "File $name does not exist" && exit 1
  done
  $train_cmd $expo/log/ivector-plda-scoring.log \
    sed -r 's/_|-/ /g' data/$enrolls/enrolls \| awk '{split($1, val, "_"); ++num[val[1]]}END{for (spk in num) print spk, num[spk]}' \| \
      ivector-plda-scoring --normalize-length=true --num-utts=ark:- \
        "ivector-copy-plda --smoothing=0.0 $plda_dir/plda - |" \
         "ark:cut -d' ' -f1 data/$enrolls/enrolls | grep -Ff - $xvect_enrolls | ivector-mean ark:data/$enrolls/spk2utt scp:- ark:- | \
               ivector-subtract-global-mean $plda_dir/mean.vec ark:- ark:- | transform-vec $plda_dir/transform.mat ark:- ark:- | ivector-normalize-length ark:- ark:- |" \
         "ark:cut -d' ' -f2 data/$trials/trials | sort | uniq | grep -Ff - $xvect_trials | \
             ivector-subtract-global-mean $plda_dir/mean.vec scp:- ark:- | transform-vec $plda_dir/transform.mat ark:- ark:- | ivector-normalize-length ark:- ark:- |" \
        "cat data/$trials/trials | cut -d' ' --fields=1,2 |" $expo/scores || exit 1

  temp_trial=$(mktemp)
  temp_scores=$(mktemp)

  src_spk2gender=data/$trials/trials
  cut -d\  -f 1 ${src_spk2gender} | sort | uniq | while read s; do
    echo "Speaker: $s"
    cat data/$trials/trials | grep "^$s" > $temp_trial
    cat $expo/scores | grep "^$s" > $temp_scores
    eer=`compute-eer <(local/prepare_for_eer.py $temp_trial $temp_scores) 2> /dev/null`
    mindcf1=`sid/compute_min_dcf.py --p-target 0.01 $temp_scores $temp_trial 2> /dev/null`
    mindcf2=`sid/compute_min_dcf.py --p-target 0.001 $temp_scores $temp_trial 2> /dev/null`
    echo "EER: $eer%" | tee $expo/EER_$s
    echo "minDCF(p-target=0.01): $mindcf1" | tee -a $expo/EER_$s
    echo "minDCF(p-target=0.001): $mindcf2" | tee -a $expo/EER_$s
    PYTHONPATH=$(realpath ./tools/cllr) python3 ./tools/cllr/compute_cllr.py \
      -k $temp_trial -s $temp_scores -e | tee $expo/Cllr_$s || exit 1

    # Compute linkability
    PYTHONPATH=$(realpath ./tools/anonymization_metrics) python3 local/compute_linkability.py \
      -k $temp_trial -s $temp_scores \
      -d -o $expo/linkability | tee $expo/linkability_log_$s || exit 1
  done

  cat data/$trials/trials > $temp_trial
  cat $expo/scores > $temp_scores

  eer=`compute-eer <(local/prepare_for_eer.py $temp_trial $temp_scores) 2> /dev/null`
  mindcf1=`sid/compute_min_dcf.py --p-target 0.01 $temp_scores $temp_trial 2> /dev/null`
  mindcf2=`sid/compute_min_dcf.py --p-target 0.001 $temp_scores $temp_trial 2> /dev/null`
  echo "EER: $eer%" | tee $expo/EER
  echo "minDCF(p-target=0.01): $mindcf1" | tee -a $expo/EER
  echo "minDCF(p-target=0.001): $mindcf2" | tee -a $expo/EER
  PYTHONPATH=$(realpath ./tools/cllr) python3 ./tools/cllr/compute_cllr.py \
    -k $temp_trial -s $temp_scores -e | tee $expo/Cllr || exit 1

  # Compute linkability
  PYTHONPATH=$(realpath ./tools/anonymization_metrics) python3 local/compute_linkability.py \
    -k $temp_trial -s $temp_scores \
    -d -o $expo/linkability | tee $expo/linkability_log || exit 1

  rm $temp_trial
  rm $temp_scores
fi



if [ $stage -le 2 ]; then
  src_spk2gender=data/$enrolls/spk2gender

  xvect_enrolls=$x_vector_ouput/xvect_$enrolls
  xvect_trials=$x_vector_ouput/xvect_$trials

  cut -d\  -f 1 ${src_spk2gender} | while read s; do
    # echo "Speaker: $s"
    local/compute_spk_pool_affinity.sh ${plda_dir} ${xvect_enrolls} ${xvect_trials} \
   "$s" "${expo}/affinity_${s}" $expo/log/ivector-spk-plda-scoring.log || exit 1;
  done
fi
