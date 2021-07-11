# IDS
WHAT IS IT:
This project consists of a stream-based network HIDS for intrusion detection using machine learning classification.
Currently work only on linux.

PREREQUISITES:
A folder on your computer with dataset chunks.
Inside this folder MUST BE presente at least a csv file(with extension in the name for all files) and every chunk MUST HAVE the header of the csv as the first line.
Erlang OTP 22 or greater.

NOTE: For documentation check the file nids_documentation.pdf

INSTALLATION:
First of all clone the repo on your local.
After this, go inside the newly cloned folder and you will find an erlang script called "nids".
Get it and put it in any path (preferably in / usr / bin). 
It allows a basic management of the nids, acting as an interface to *nidsManager* script.
**NidsManager script it is the true manager of the nids.**
In the documentation, under chapter 2, will be explained how to use the command.
Then open the script *nids* just moved and modify the cd "PathToRepo" line to point at the folder of YOUR cloned repo(change the path to the path of your cloned repo).
***It is strongly recommended to change AT LEAST the nids cookie from the default one through the nids config command (see documentation chapter 2).*** 
Now you can setup the nids.
First type in a shell the command "sudo nids start". Now will appear the nids graphic interface.
Go to the "Run-time updates" tab, and type in the textbox near the button "New dataset" the folder of your chunks. Then click the "New dataset button" and wait the creation of files used by the nids.
Installation finished.
By default there is already a model for the recognition, so the only installation thing is the creation of the dataset. however, it is advisable to refit the model after creating a new dataset.
The default model was trained on the dataset created from the pieces available at the following link: 
https://www.unb.ca/cic/datasets/ids-2017.html (see the link at the bottom of the Download dataset page or similar)

STATE OF ART:
At present the nids is functioning.
Obviously being very recent it is still in the testing and debugging phase, so bugs or anomalous behavior may still emerge.
For now, I list the main points of improvement that have emerged personally:
    1) Model recognition needs to be improved (currently at a low-medium accuracy rate).
    2) The hot code must also involve the graphic part of the NIDS, i.e. if I modify a graphic component and reload the code, it must update the relative graphics).
    3) Automatic method for nids script installation.
    4) Cookie and node name in the handler script no cabled in the code.
These points are considered to be short-term todo.

