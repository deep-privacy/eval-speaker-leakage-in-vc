# Libraries
import matplotlib.pyplot as plt
import pandas as pd
from math import pi
import os
import pprint
pp = pprint.PrettyPrinter(indent=2)
import numpy as np
import sys
import statistics

class DataSpk:
    def __init__(self, speaker):
        self.speaker_session = []
        self.spk = speaker
        self.cllr_xvector_mean = 0.5
        

    def __repr__(self):
        return "Num session:" + str(len(self.speaker_session)) + " - " + speaker # + " | " + str(self.speaker_session)
        


data = {
'group': [],
}

for file in os.listdir("results/voice_privacy/"):
    if file.startswith("eval_spk_") and file.endswith("_retrain"):
        print("====")
        print("pseudo spk")
        psuedo_spk = str(file).split("_")[2]
        print(psuedo_spk)
        data['group'].append(psuedo_spk)

        for dataset in os.listdir("results/voice_privacy/" + str(file)):
            for proj in os.listdir("results/voice_privacy/" + str(file) + "/" + str(dataset)):
                if proj.startswith("Cllr_"):
                    speaker = str(proj).split("_")[1]
                    d = DataSpk(speaker)

                    f = open("results/voice_privacy/" + str(file) + "/" + str(dataset) + "/" + proj, "r")
                    content = f.readline()
                    if content == "":
                        print("Ommiting", f)
                        continue
                    speaker = str(proj).split("_")[1]
                    mincllr = float(content.split(":")[1].split("/")[0])

                    d.cllr_xvector_mean = mincllr

                    for session_loc in os.listdir("results/voice_privacy/" + str(file) + "/" + str(dataset) + "/scores_no_mean_" + speaker):
                        if session_loc.startswith("Cllr_"):
                            print("====", session_loc)
                            f = open("results/voice_privacy/" + str(file) + "/" + str(dataset) + "/scores_no_mean_" + speaker + "/" + session_loc, "r")
                            content = f.readline()
                            if content == "":
                                print("Ommiting", f)
                                continue
                            mincllr = float(content.split(":")[1].split("/")[0])
                            d.speaker_session.append(mincllr)
                            f.close()

                    if len(d.speaker_session) == 0:
                        continue

                    if speaker not in data:
                        data[speaker] = []
                    data[speaker].append(d)


psuedo_spk = "Orig"
data['group'].append(psuedo_spk)

for dataset in os.listdir("results/original_speech/"):
    for proj in os.listdir("results/original_speech/"  + str(dataset)):
        if proj.startswith("Cllr_"):
            f = open("results/original_speech/"  + str(dataset) + "/" + proj, "r")
            content = f.readline()
            if content == "":
                print("Ommiting", f)
                continue
            speaker = str(proj).split("_")[1]
            mincllr = float(content.split(":")[1].split("/")[0])
            if speaker not in data:
                data[speaker] = []

            d = DataSpk("original")
            d.speaker_session = [mincllr]
            d.cllr_xvector_mean = mincllr
            data[speaker].append(d)
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


pp.pprint(data)
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


def make_spider( row, title, color):

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

    # Draw one axe per variable + add labels labels yet
    plt.xticks(angles[:-1], categories, color='grey', size=18)
    #  for tick in ax.get_xticklabels():
        #  tick.set_rotation(75)

    # Ind1
    values=df.loc[row].drop('group').values.flatten().tolist()
    values += values[:1]
    original_speech_angle=1
    for (a,b) in zip(categories, values):
        if a == psuedo_spk: # "original" spk
            original_speech_angle = b.speaker_session[0]
            if original_speech_angle < 0.01:
                original_speech_angle = 0.01
            break
    ax.plot(angles, [original_speech_angle for _ in values], color='black', linewidth=2, linestyle='dotted')
    plot_value_min = []
    plot_value_max = []
    plot_value_mean = []
    plot_value_mean_spk_xvector = []
    for value in values:
        plot_value_mean.append(statistics.mean(value.speaker_session))
        plot_value_min.append(min(value.speaker_session))
        plot_value_max.append(max(value.speaker_session))
        plot_value_mean_spk_xvector.append(value.cllr_xvector_mean)

    #  ax.plot(angles, plot_value_mean, color=color, linewidth=1, linestyle='solid')

    #  ax.plot(angles, plot_value_min, color=color, linewidth=1, linestyle='dotted')
    #  ax.plot(angles, plot_value_max, color=color, linewidth=1, linestyle='dotted')

    ax.plot(angles, plot_value_mean_spk_xvector, color=color, linewidth=3, linestyle='solid')
    ax.fill(angles, plot_value_mean_spk_xvector, color=color, alpha=0.4)

    # Draw ylabels
    ax.set_rlabel_position(0)
    yval = [0,0.3,0.6,1]
    yval_label = ["0","0.3","0.6","1"]
    ylim = 1


    plt.yticks(yval, yval_label, color="grey", size=20)
    plt.ylim(0,ylim)


    # Add a title
    plt.title(title, size=30, pad=10, color=color, y=1)

# ------- PART 2: Apply to all individuals
# initialize the figure
plt.figure(figsize=(100, 100), dpi=300)

# Create a color palette:
my_palette = plt.cm.get_cmap("Set2", len(df.index))

# Loop to plot
for row in range(0, len(df.index)):
    make_spider( row=row, title='Speaker'+df['group'][row], color=my_palette(row))

plt.savefig('exp/fig/radar/radar.png')
