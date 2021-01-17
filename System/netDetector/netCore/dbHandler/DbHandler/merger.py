#!/usr/local/bin/python3.7
import csv
import os
import sys

first=True
csvDir=sys.argv[1]
files=os.listdir(csvDir)
outDir=sys.argv[2]+"/Dataset.csv"
db=open(outDir,"w")
writer=csv.writer(db)
for dataset in files:
	with open(csvDir+dataset, newline='') as f:
    		reader = csv.reader(f)
    		if(first==True):
    			featuresNames=next(reader)
    			writer.writerow(featuresNames)
    			first=False
    		else:
    			next(reader)
    		for row in reader:
                    if(("Nan" in row) or ("Infinity" in row)):
                        continue
                    else:
                        writer.writerow(row)
