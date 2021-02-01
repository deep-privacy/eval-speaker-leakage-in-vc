#!/usr/bin/env python3

#  python3 ./local/stats_affinity.py results/voice_privacy/test-retrain-asv/ASV-libri_test_enrolls_anon-libri_test_trials_{f,m}_anon/affinity_*

import numpy as np
import sys
for aff_log in sys.argv:
    if aff_log == sys.argv[0]:
        continue
    scores = open(aff_log, 'r').readlines()
    scores_array = []
    for line in scores:
        spkr, target, score = line.strip().split()
        scores_array.append(float(score))

    scores_array = np.array(scores_array)
    print(spkr, np.mean(scores_array), np.std(scores_array), np.min(scores_array), np.max(scores_array))
