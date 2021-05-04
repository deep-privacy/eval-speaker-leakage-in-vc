import sys
from os.path import basename, join
import os
import operator
import argparse
import numpy as np
import random
import kaldiio
from kaldiio import WriteHelper, ReadHelper
from sklearn import decomposition
from sklearn import metrics
from sklearn.cluster import KMeans
from sklearn import mixture
from sklearn.metrics.pairwise import cosine_similarity
from sklearn.metrics import pairwise_distances_argmin_min
import pickle

random_seed=2021

np.random.seed(random_seed)


def train_models(pool_data, xvec_out_dir, output_x_vec_select, combine_genders=False):

    gender_pools = {'m': [], 'f': []}
    xvector_pool = []

    print('Adding {} to the pool'.format(join(pool_data)))
    pool_spk2gender_file = join(pool_data, 'spk2gender')

    # Read pool spk2gender
    pool_spk2gender = {}
    with open(pool_spk2gender_file) as f:
        for line in f.read().splitlines():
            sp = line.split()
            pool_spk2gender[sp[0]] = sp[1]

    # Read pool xvectors
    pool_xvec_file = join(xvec_out_dir, 'spk_xvector.scp')
    if not os.path.exists(pool_xvec_file):
        raise ValueError(
            'Xvector file: {} does not exist'.format(pool_xvec_file))

    print(pool_xvec_file)
    with ReadHelper('scp:'+pool_xvec_file) as reader:
        for key, xvec in reader:
            # print key, mat.shape
            xvector_pool.append(xvec)
            gender = pool_spk2gender[key]
            gender_pools[gender].append(xvec)

    print("Read ", len(gender_pools['m']), " male pool xvectors")
    print("Read ", len(gender_pools['f']), " female pool xvectors")

    # Fit and train clustering
    if combine_genders:
        clustering = KMeans(n_clusters=clusters_per_conv, random_state=random_seed).fit(xvector_pool)
    else:
        clustering = {'m': {}, 'f': {}}
        for gender in ('m', 'f'):
            gender_xvecs = np.array(gender_pools[gender])
            np.random.shuffle(gender_xvecs)

            for xvec_1 in gender_xvecs[:50]:

                with ReadHelper('scp:'+pool_xvec_file) as reader:
                    for key, xvec in reader:
                        if (xvec_1 == xvec).all():
                            print("Spk:" , key, "Random selected")
                            kaldiio.save_ark(f"{output_x_vec_select}/spk_list.ark", {f"{key}": xvec}, append=True,  scp=f"{output_x_vec_select}/spk_list.scp")
                            break


            #  with WriteHelper("ark,scp:{output_x_vec_select}/file.ark,file.scp") as writer:
                #  for i in range(10):
                    #  writer(str(i), numpy.random.randn(10, 10))
                    # The following is equivalent
                    # writer[str(i)] = numpy.random.randn(10, 10)
    #  output_x_vec_select

    
    return clustering


if __name__ == "__main__":
    pool_data = sys.argv[1]
    xvec_out_dir = sys.argv[2]
    combine_genders = sys.argv[3].lower() == "true"
    output_x_vec_select = sys.argv[4]
    output_x_vec_select = os.path.abspath(output_x_vec_select)
    train_models(pool_data, xvec_out_dir, output_x_vec_select, combine_genders=combine_genders)
