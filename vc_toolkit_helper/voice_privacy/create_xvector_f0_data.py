import sys
from os.path import join, basename
import os

from ioTools import readwrite
from kaldiio import WriteHelper, ReadHelper
import numpy as np


args = sys.argv
print(args)
data_dir = args[1]
xvector_file = args[2]
out_dir = args[3]
target = args[4]
xvector_target_file = args[5]

dataname = basename(data_dir)
yaap_pitch_dir = join(data_dir, 'yaapt_pitch')
xvec_out_dir = join(out_dir, "xvector")
pitch_out_dir = join(out_dir, "f0")

# Write pitch features
pitch_file = join(data_dir, 'pitch.scp')
pitch2shape = {}
with ReadHelper('scp:'+pitch_file) as reader:
    for key, mat in reader:
        pitch2shape[key] = mat.shape[0]
        kaldi_f0 = mat[:, 1].squeeze().copy()
        yaapt_f0 = readwrite.read_raw_mat(join(yaap_pitch_dir, key+'.f0'), 1)
        #unvoiced = np.where(yaapt_f0 == 0)[0]
        #kaldi_f0[unvoiced] = 0
        #readwrite.write_raw_mat(kaldi_f0, join(pitch_out_dir, key+'.f0'))
        f0 = np.zeros(kaldi_f0.shape)
        if kaldi_f0.shape < yaapt_f0.shape:
            print("Warning yaapt_f0 > kaldi_f0 for utt:", key)
            yaapt_f0 = yaapt_f0[:kaldi_f0.shape[0]]
        f0[:yaapt_f0.shape[0]] = yaapt_f0
        readwrite.write_raw_mat(f0, join(pitch_out_dir, key+'.f0'))


# Target the same x-vector!
target_for_all=np.array([])
with ReadHelper('scp:'+xvector_target_file) as reader:
    for key, mat in reader:
        if key.split("-")[0] == target:
            target_for_all = mat[np.newaxis]


            ark_scp_output = 'ark,scp:{}/{}.ark,{}/{}.scp'.format(
                                os.path.dirname(xvector_file), 'pseudo_xvector_single_target',
                                os.path.dirname(xvector_file), 'pseudo_xvector_single_target')
            with WriteHelper(ark_scp_output) as writer:
                  writer(key, mat)

            break

if len(target_for_all) == 0:
    print(f"target_for_all '{target}' speaker not find in {xvector_target_file}")
    sys.exit(1)

# Write xvector features
with ReadHelper('scp:'+xvector_file) as reader:
    for key, mat in reader:
        plen = pitch2shape[key]
        mat = mat[np.newaxis]
        xvec = np.repeat(target_for_all, plen, axis=0)
        #  xvec = np.repeat(np.random.rand(512), plen, axis=0)
        readwrite.write_raw_mat(xvec, join(xvec_out_dir, key+'.xvector'))
