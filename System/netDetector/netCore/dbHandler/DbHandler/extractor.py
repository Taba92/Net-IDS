#!/usr/local/bin/python3.7
import csv
import sys
import os

labels=set()
stringLabels=""
directory=sys.argv[1]
outDir=sys.argv[2]+"/labels.txt"
files=os.listdir(directory)
for dataset in files:
	with open(directory+"/"+dataset, newline='') as f:
    		reader = csv.reader(f)
    		for row in reader:
    			if((row[-1] in labels)==False and row[-1]!=" Label"):
    				labels.add(row[-1])
    				stringLabels=stringLabels+row[-1]+","
file=open(outDir,"w")
file.write(stringLabels[:-1])
