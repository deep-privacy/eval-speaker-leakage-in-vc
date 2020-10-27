# Use t-SNE to plot Kaldi's x-vectors

from kaldi_arkread import load_scpfile
import numpy as np
from sklearn.manifold import TSNE
from plot_ivectors import scatter2D
import matplotlib.pyplot as plt

import sys

def main():
    args = sys.argv
    basedir = args[1] + "/"
    dataset = args[2]
    datatype = args[3]
    level = args[4]

    spk=""
    if level == "spk":
         spk = "spk_"

    domains = ['trials_m','trials_f','enrolls']

    if datatype == "anon":
        scpfile = [
            basedir + f"exp/anon_xvector/xvect_libri_{dataset}_trials_m_anon/{spk}xvector.scp"
            , basedir + f"exp/anon_xvector/xvect_libri_{dataset}_trials_f_anon/{spk}xvector.scp"
            #  , basedir + f"exp/anon_xvector/xvect_libri_{dataset}_enrolls_anon/{spk}xvector.scp"
        ]
    elif datatype == "original":
        print("=== Using x-vector computed from the voice_privacy challenge!")
        scpfile = [
             basedir + f"exp/vc_toolkit_exp_voice_privacy/feats/x_vector/xvectors_libri_{dataset}_trials_m/{spk}xvector.scp"
            , basedir + f"exp/vc_toolkit_exp_voice_privacy/feats/x_vector/xvectors_libri_{dataset}_trials_f/{spk}xvector.scp"
            #  , basedir + f"exp/vc_toolkit_exp_voice_privacy/feats/x_vector/xvectors_libri_{dataset}_enrolls/{spk}xvector.scp"
        ]
    elif datatype == "all":
        print("=== Using x-vector computed from the voice_privacy challenge!")
        scpfile = [
             basedir + f"exp/vc_toolkit_exp_voice_privacy/feats/x_vector/xvectors_libri_{dataset}_trials_m/{spk}xvector.scp"
            , basedir + f"exp/vc_toolkit_exp_voice_privacy/feats/x_vector/xvectors_libri_{dataset}_trials_f/{spk}xvector.scp"
            #  , basedir + f"exp/vc_toolkit_exp_voice_privacy/feats/x_vector/xvectors_libri_{dataset}_enrolls/{spk}xvector.scp"
            , basedir + f"exp/anon_xvector/xvect_libri_{dataset}_trials_m_anon/{spk}xvector.scp"
            , basedir + f"exp/anon_xvector/xvect_libri_{dataset}_trials_f_anon/{spk}xvector.scp"
            #  , basedir + f"exp/anon_xvector/xvect_libri_{dataset}_enrolls_anon/{spk}xvector.scp"
            , basedir + f"exp/vc_toolkit_exp_voice_privacy/feats/x_vector/xvectors_libri_{dataset}_trials_m/pseudo_xvecs/pseudo_xvector_single_target.scp"
        ]

        #  domains = ['trials_f','trials_m','enrolls', 'trials_f_anon','trials_m_anon','enrolls_anon']
        domains = ['trials_m','trials_f', 'trials_m_anon','trials_f_anon', 'target_spk']
    else:
        print(f"{datatype} unknon (anon or original)")
        sys.exit(1)

    max_smps = 1500         # Maximum no. of vectors per domain

    X = list()
    Y = list()
    for i in range(len(scpfile)):
        _, mat = load_scpfile(basedir, scpfile[i], arktype='vec')
        mat = mat[0:np.min([mat.shape[0], max_smps]), :]
        X.append(mat)
        Y.extend([i] * mat.shape[0])
    X = np.vstack(X)
    Y = np.array(Y)

    print('Creating t-SNE plot of original x-vectors')
    fig, _, _ = scatter2D(TSNE(random_state=20150101).fit_transform(X), Y, domains)
    level_file=""
    if level == "spk":
        level_file = ".spk"
    name=f"exp/{datatype}{level_file}.multi-dataset-xvec.png"
    fig.savefig(name)
    #plt.show(block=False)
    plt.show(block=True)

if __name__ == '__main__':
    main()

