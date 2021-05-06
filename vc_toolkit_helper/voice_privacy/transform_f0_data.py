import sys
from os.path import join, basename, dirname

from ioTools import readwrite
from kaldiio import WriteHelper, ReadHelper
import numpy as np
import json

from f0transformation import log_linear_transformation
import ast
import math

args = sys.argv
data_dir = args[1]
target_spk = args[2]
out_dir = args[3]
dataset_of_target = args[4]

dataname = basename(data_dir)
yaap_pitch_dir = join(data_dir, 'yaapt_pitch')
pitch_out_dir = join(out_dir, "f0")

statsdir = "exp/vc_toolkit_exp_voice_privacy/feats/f0/"

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
        if kaldi_f0.shape < yaapt_f0.shape:
            print("Warning yaapt_f0 > kaldi_f0 for utt:", key)
            yaapt_f0 = yaapt_f0[:kaldi_f0.shape[0]]
        f0 = np.zeros(kaldi_f0.shape)
        f0[:yaapt_f0.shape[0]] = yaapt_f0

        source_stats = {}
        with open(statsdir+dataname+"/"+key.split("-")[0].split("_")[0]) as f:
            source_stats = json.load(f)

        selected_target_speaker_list = [target_spk]
        #  print("selected f0 target_speaker_stats:", target_spk)
        
        pseudo_speaker_f0_stats = {"mu_s":0, "var_s":0, "std_s":0}
        for selected_target_speaker in selected_target_speaker_list:
            target_speaker_stats = {}
            with open(statsdir+dataset_of_target+"/"+selected_target_speaker) as f:
                target_speaker_stats = json.load(f)
                mu = target_speaker_stats["mu_s"]
                var = target_speaker_stats["var_s"]
                pseudo_speaker_f0_stats["mu_s"] += mu
                pseudo_speaker_f0_stats["var_s"] += var
        pseudo_speaker_f0_stats["var_s"] /= len(selected_target_speaker_list)
        pseudo_speaker_f0_stats["mu_s"]  /= len(selected_target_speaker_list)
        pseudo_speaker_f0_stats["std_s"] = math.sqrt(pseudo_speaker_f0_stats["var_s"])

        transfomation = {**source_stats, "mu_t":pseudo_speaker_f0_stats["mu_s"], "std_t":pseudo_speaker_f0_stats["std_s"]}

        f0t = log_linear_transformation(f0.copy(), transfomation)

        readwrite.write_raw_mat(f0t, join(pitch_out_dir, key+'.f0'))

