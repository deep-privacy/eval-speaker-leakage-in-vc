#!/bin/bash

set -e

#===== begin config =======

. utils/parse_options.sh || exit 1;

. ./cmd.sh
. ./path.sh


temp=$(mktemp)

for suff in dev test; do
    for name in data/libri_$suff/{enrolls,trials_f,trials_m}; do
      [ ! -f $name ] && echo "File $name does not exist" && exit 1
    done

    dset=data/libri_$suff
    utils/subset_data_dir.sh --utt-list $dset/enrolls $dset ${dset}_enrolls || exit 1
    cp $dset/enrolls ${dset}_enrolls || exit 1

    cut -d' ' -f2 $dset/trials_f | sort | uniq > $temp
    utils/subset_data_dir.sh --utt-list $temp $dset ${dset}_trials_f || exit 1
    cp $dset/trials_f ${dset}_trials_f/trials || exit 1

    cut -d' ' -f2 $dset/trials_m | sort | uniq > $temp
    utils/subset_data_dir.sh --utt-list $temp $dset ${dset}_trials_m || exit 1
    cp $dset/trials_m ${dset}_trials_m/trials || exit 1

    ./utils/combine_data.sh ${dset}_trials_all ${dset}_trials_f ${dset}_trials_m || exit 1
    cat ${dset}_trials_f/trials ${dset}_trials_m/trials > ${dset}_trials_all/trials
    rm $temp
done
