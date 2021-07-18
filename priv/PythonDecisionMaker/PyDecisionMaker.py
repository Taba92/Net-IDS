#!/usr/local/bin/python3.7
import struct
import sys
import traceback
import os
import Parser
from Brain import Brain

curDir=os.path.dirname(os.path.abspath(__file__))
brain=Brain()
brain.load(curDir)
line="1"
accuracyNameFile=curDir+"/accuracy.txt"
accuracyFile=None
dataToErlang=None
dataFromErlang=None
while len(line)>0:#finchè lo stdin è aperto da Erlang,invia almeno 1 byte(0x00)
	line=sys.stdin.buffer.read(4)
	if(len(line)==4):
		try:
			packetLenght=struct.unpack(">L",line)
			length=packetLenght[0]
			packet=sys.stdin.buffer.read(length)
			func=packet[0]
			data=packet[1:]
			dataFromErlang=Parser.parseErlToPy(data)
			if(func==1):
				brain.new()
				accuracyFile=open(accuracyNameFile,"w")
				brain.features_names=dataFromErlang[0][:-1]
				brain.loadTargetsNames(dataFromErlang[1])
				dataToErlang=struct.pack("b",1)
			elif (func==2):
				(isFinish,chunk)=(dataFromErlang[0],dataFromErlang[1:])
				brain.trainScaler(chunk)
				dataToErlang=struct.pack("bb",2,isFinish)
			elif (func==3):
				(isFinish,chunk)=(dataFromErlang[0],dataFromErlang[1:])
				score=brain.trainIntelligence(chunk)
				accuracyFile.write("SCORE: "+str(score)+"\n")
				if (isFinish==1):
					accuracyFile.close()
					brain.dump(curDir)
				dataToErlang=struct.pack("bb",3,isFinish)
			else:
				recordPredicted=brain.decide(dataFromErlang)
				dataToErlang=Parser.parsePyToErl(recordPredicted)
		except Exception:
			(tipe,value,tb)=sys.exc_info()
			error=["".join(traceback.format_exception(tipe,value,tb))]
			errorToErlang=Parser.parsePyToErl(error)
			dataToErlang=struct.pack("b",0)+errorToErlang
		finally:
			val=struct.pack(">L",len(dataToErlang))+dataToErlang
			sys.stdout.buffer.write(val)
			sys.stdout.buffer.flush()
