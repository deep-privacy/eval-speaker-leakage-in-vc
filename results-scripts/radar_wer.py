# Libraries
import matplotlib.pyplot as plt
import pandas as pd
from math import pi
import os
import pprint
pp = pprint.PrettyPrinter(indent=2)
import numpy as np
import sys

resultsFile= "voice_privacy/"

f0=""
f0="_nof0"

#  resultsFile= "voice_privacy_asv_eval_retrained_ON_SIL/"

data = {
'group': [],
}

data['wer'] = []
for file in os.listdir(f"results/{resultsFile}"):
    if file.startswith("eval_spk_") and not file.endswith("_retrain"):
        if file.endswith("nof0") and f0 == "":
            continue
        if not file.endswith("nof0") and f0 == "_nof0":
            continue
        print("====")
        print("pseudo spk")
        psuedo_spk = str(file).split("_")[2]
        print(psuedo_spk)
        data['group'].append(psuedo_spk)


        f = open(f"results/{resultsFile}"+ str(file) + "/" + "ASR-libri_test-" + psuedo_spk + f0 + "_asr_anon", "r")
        content = f.readlines()[-1]
        if content == "":
            print("Ommiting", f)
            continue
        wer = float(content.split("[")[0].split("R")[1])
        data['wer'].append(wer)
        f.close()

data_origial = {
'group': [],
}

psuedo_spk = "Original Speech"
data_origial['group'].append(psuedo_spk)

for dataset in os.listdir("results/original_speech/"):
    if not dataset.startswith("xvector_selected_"):
        continue
    for proj in os.listdir("results/original_speech/"  + str(dataset)):
        if proj.startswith("ASR-"):
            f = open("results/original_speech/"  + str(dataset) + "/" + proj, "r")
            content = f.readlines()[-1]
            if content == "":
                print("Ommiting", f)
                continue
            speaker = proj.split("_")[-1]
            wer = float(content.split("[")[0].split("R")[1])
            data_origial[speaker] = wer
            f.close()

# ------- PART 1: Define a function that do a plot for one line of the dataset!

# Set data
df = pd.DataFrame({
'group': ['A','B','C','D'],
'var1': [38, 1.5, 30, 4],
'var2': [29, 10, 9, 34],
'var3': [8, 39, 23, 24],
'var4': [7, 31, 33, 14],
'var5': [28, 15, 32, 14]
})


df = pd.DataFrame(data)

df = df.set_index("group")
df = df.sort_index()
df = df.T


data = {
'group': [],
}

for col_name, da in df.items():
    #  print("col_name:",col_name, "\ndata:",da)
    #  data['group'].append(str(col_name))
    for speaker, d in da.items():
        #  print(speaker, d)
        speaker = str(speaker)

        if speaker not in data['group']:
            data['group'].append(speaker)

        if col_name not in data:
            data[col_name] = []
        data[col_name].append(d)

df = pd.DataFrame(data)
print(df.head())



def make_spider( row, title, spk, color):

    # number of variable
    categories=list(df)[1:]
    N = len(categories)

    # What will be the angle of each axis in the plot? (we divide the plot / number of variable)
    angles = [n / float(N) * 2 * pi for n in range(N)]
    angles += angles[:1]

    # Initialise the spider plot
    ax = plt.subplot(6,7,row+1, polar=True, )

    # If you want the first axis to be on top:
    ax.set_theta_offset(pi / 2)
    ax.set_theta_direction(-1)

    wer_on_original = []

    for a in categories:
        wer_on_original.append(data_origial[a])


    # Ind1
    values=df.loc[row].drop('group').values.flatten().tolist()
    values += values[:1]

    print(values)
    ax.plot(angles, values, color=color, linewidth=2, linestyle='solid')
    ax.fill(angles, values, color=color, alpha=0.4)

    wer_on_original += wer_on_original[:1]
    ax.plot(angles, wer_on_original, color='black', linewidth=3, linestyle='dotted')

    # Draw one axe per variable + add labels labels yet
    plt.xticks(angles[:-1], categories, color='grey', size=18)

    # Draw ylabels
    ax.set_rlabel_position(0)
    yval = [0,5,10,19]
    yval_label = ["0","5","10","20"]
    ylim = 21

    plt.yticks(yval, yval_label, color="grey", size=20)
    plt.ylim(0,ylim)


    # Add a title
    plt.title(title, size=30, pad=10, color=color, y=1)


plt.rcParams["axes.axisbelow"] = False
# ------- PART 2: Apply to all individuals
# initialize the figure
plt.figure(figsize=(100, 100), dpi=300)

# Create a color palette:
my_palette = plt.cm.get_cmap("Set2", len(df.index))

# Loop to plot
for row in range(0, len(df.index)):
    make_spider( row=row, title='WER', spk=df['group'][row], color=my_palette(row))

plt.savefig(f'exp/fig/radar/radar{f0}_wer.svg')
