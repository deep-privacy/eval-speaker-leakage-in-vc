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
#  f0="_nof0"

#  resultsFile= "voice_privacy_asv_eval_retrained_ON_SIL/"

data = {
'group': [],
}

for file in os.listdir(f"results/{resultsFile}"):
    if file.startswith("eval_spk_") and file.endswith(f0 + "_retrain"):
        if f0 == "":
            if file.endswith("f0_retrain"):
                continue
        print("====")
        print("pseudo spk")
        psuedo_spk = str(file).split("_")[2]
        print(psuedo_spk)
        data['group'].append(psuedo_spk)

        for dataset in os.listdir(f"results/{resultsFile}"+ str(file)):
            for proj in os.listdir(f"results/{resultsFile}"+ str(file) + "/" + str(dataset)):
                if proj.startswith("linkability_log_"):
                    f = open(f"results/{resultsFile}"+ str(file) + "/" + str(dataset) + "/" + proj, "r")
                    content = f.readline()
                    if content == "":
                        print("Ommiting", f)
                        continue
                    speaker = str(proj).split("_")[2]
                    mincllr = float(content.split(":")[1].split("/")[0])
                    if speaker not in data:
                        data[speaker] = []
                    data[speaker].append(mincllr)
                    f.close()

data_origial = {
'group': [],
}

psuedo_spk = "Original Speech"
data_origial['group'].append(psuedo_spk)

for dataset in os.listdir("results/original_speech/"):
    if not dataset.startswith("ASV-"):
        continue
    for proj in os.listdir("results/original_speech/"  + str(dataset)):
        if proj.startswith("linkability_log_"):
            f = open("results/original_speech/"  + str(dataset) + "/" + proj, "r")
            print(f)
            content = f.readline()
            if content == "":
                print("Ommiting", f)
                continue
            speaker = str(proj).split("_")[2]
            mincllr = float(content.split(":")[1].split("/")[0])
            if speaker not in data_origial:
                data_origial[speaker] = []
            data_origial[speaker].append(mincllr)
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
print(df)


#  pp.pprint(data)
df = pd.DataFrame(data)
print(df.head())

df = df.set_index("group").T

print(df.head())

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

    # Ind1
    values=df.loc[row].drop('group').values.flatten().tolist()
    values += values[:1]
    original_speech_angle = data_origial[str(spk)][0]
    if original_speech_angle < 0.01:
        original_speech_angle = 0.025
    if original_speech_angle > 0.9:
        original_speech_angle = 0.985
    print(original_speech_angle)
    ax.plot(angles, values, color=color, linewidth=2, linestyle='solid')
    ax.fill(angles, values, color=color, alpha=0.4)
    ax.plot(angles, [original_speech_angle for _ in values], color='black', linewidth=3, linestyle='dotted')

    # Draw one axe per variable + add labels labels yet
    plt.xticks(angles[:-1], categories, color='grey', size=18)

    # Draw ylabels
    ax.set_rlabel_position(0)
    yval = [0,0.3,0.6,0.93]
    yval_label = ["0","0.3","0.6","1"]
    ylim = 1

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
    make_spider( row=row, title='Speaker'+df['group'][row], spk=df['group'][row], color=my_palette(row))

plt.savefig(f'exp/fig/radar/radar{f0}_link.svg')
