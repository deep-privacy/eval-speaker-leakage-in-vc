#!/bin/bash

set -e

#===== begin config =======

stage=0
nj=$(nproc)
voice_conversion_exp=""

data_url_libritts=www.openslr.org/resources/60     # Link to download LibriTTS corpus
dataset=$1

. ./cmd.sh
. ./path.sh

. utils/parse_options.sh || exit 1;

anoni_pool=$(realpath $voice_conversion_exp)/data/libritts_train_other_500
corpora=$(realpath $voice_conversion_exp)/corpora

# X-Vector model used in the VoicePrivacy Challenge
xvec_nnet_dir=exp/models/2_xvect_extr/exp/xvector_nnet_1a
# PPG_Model used in the VoicePrivacy Challenge
ppg_model=exp/models/1_asr_am/exp
ivec_extractor=${ppg_model}/nnet3_cleaned/extractor
ivec_data_dir=${ppg_model}/nnet3_cleaned/ivectors_${data}_ppg
model_dir=${ppg_model}/chain_cleaned/tdnn_1d_sp


anon_xvec_out_dir=$(realpath $voice_conversion_exp)/feats/anoni_pool
mkdir -p $anon_xvec_out_dir

ppg_out_dir=$(realpath $voice_conversion_exp)/feats/ppg
mkdir -p $ppg_out_dir

BASEDIR=$(dirname $0)
VC_DIR=$BASEDIR/path

# Download LibriTTS data sets for training anonymization system (train-other-500)
if [ $stage -le 0 ]; then
  printf "  ${GREEN}\nStage 5: Downloading LibriTTS data sets for training anonymization system (train-other-500)...${NC}\n"
  for part in train-other-500; do
    $VC_DIR/local/download_and_untar.sh $corpora $data_url_libritts $part LibriTTS || exit 1;
  done
fi

libritts_corpus=$(realpath $corpora/LibriTTS)       # Directory for LibriTTS corpus

if [ $stage -le 1 ]; then
  # Prepare data for libritts-train-other-500
  printf "  ${GREEN}\nStage 1: Prepare anonymization pool data...${NC}\n"

  cd $VC_DIR
  local/data_prep_libritts.sh ${libritts_corpus}/train-other-500 ${anoni_pool} || exit 1;
  cd -
fi

if [ $stage -le 2 ]; then
  printf "  ${GREEN}\nStage 2: Extracting xvectors for anonymization pool...${NC}\n"
  cd $VC_DIR
  local/featex/01_extract_xvectors.sh --nj $nj ${anoni_pool} ${xvec_nnet_dir} \
	  ${anon_xvec_out_dir} || exit 1;
  cd -
fi


data_realpath=$(realpath ".")/data

anon_xvec_out_dir=$(realpath $voice_conversion_exp)/feats/x_vector/

if [ $stage -le 3 ]; then
  for name in $(echo $1 | tr " " "\n"); do
    # NJ < num_spk
    spk2utt=${data_realpath}/$name/spk2utt
    [ ! -f $spk2utt ] && echo "File $spk2utt does not exist" && exit 1
    num_spk=$(wc -l < $spk2utt)
    [ $nj -gt $num_spk ] && nj=$num_spk

    printf "  ${GREEN}\nStage 3.1: Extracting xvectors $name.${NC}\n"
    mkdir -p $anon_xvec_out_dir

    cd $VC_DIR
    # local/featex/01_extract_xvectors.sh --nj $nj ${data_realpath}/$name ${xvec_nnet_dir} \
      # $anon_xvec_out_dir || exit 1;
    cd -


    cd $VC_DIR
    printf "${GREEN}\nStage 3.2: Pitch extraction for $name.${NC}\n"
    # local/featex/02_extract_pitch.sh --nj ${nj} ${data_realpath}/$name || exit 1;
    cd -

    cd $VC_DIR
    printf "${GREEN}\nStage 3.3: PPG extraction for  $name.${NC}\n"
    # Extract word position dependent phonemes (346) posteriors and 256-bottleneck PPGs based on ppg-type option.

    data_dir=data/${name}_hires # in the vpc data directory
    utils/copy_data_dir.sh ${data_realpath}/$name ${data_dir}
    steps/make_mfcc.sh --nj $nj --mfcc-config conf/mfcc_hires.conf \
      --cmd "$train_cmd" ${data_dir}
    steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj $nj \
      ${data_dir} ${ivec_extractor} ${ivec_data_dir}

    local/featex/extract_bn.sh --cmd "$train_cmd" --nj $nj \
      --use_gpu false --iv-root ${ivec_data_dir} --model-dir ${model_dir} \
      ${name} ${ppg_out_dir}/ppg_$name || exit 1;
    cd -
  done
fi
