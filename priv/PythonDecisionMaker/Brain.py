from sklearn import preprocessing
from sklearn.neural_network import MLPClassifier
from sklearn.metrics import accuracy_score
from sklearn.model_selection import train_test_split
import numpy
import pickle
import sys

class Brain():
    def __init__(self):
        self.scaler=None
        self.model=None
        self.features=[]
        self.targets=[]
        self.features_names=[]
        self.targets_names=[]

    def new(self):
        self.scaler = preprocessing.MinMaxScaler()
        self.model=MLPClassifier(hidden_layer_sizes=(50,),activation='logistic',learning_rate='adaptive',learning_rate_init=0.0001,max_iter=500)

    def loadTargetsNames(self,targets):
        self.targets_names=numpy.empty((len(targets),),dtype="<U20")
        for i,target in enumerate(targets):
            self.targets_names[i]=numpy.asarray(target,dtype="<U20")

    def fromDatasetToNumpy(self,dataset):#dataset è una lista di liste
        numFeatures=len(self.features_names)
        numRecord=len(dataset)
        self.features=numpy.empty((numRecord,numFeatures),dtype="f")
        self.targets=numpy.empty((numRecord,),dtype="<U20")
        for i,record in enumerate(dataset):
            self.features[i]=numpy.asarray(record[:-1], dtype="f")
            self.targets[i]=numpy.asarray(record[-1],dtype="<U20")

    def trainScaler(self,dataset):
        self.fromDatasetToNumpy(dataset)
        self.scaler.partial_fit(self.features)

    def trainIntelligence(self,dataset):
        self.fromDatasetToNumpy(dataset)
        self.features = self.scaler.transform(self.features)
        self.model.partial_fit(self.features,self.targets,self.targets_names)
        score=self.model.score(self.features,self.targets)
        return score

    def decide(self,recordFromErlang):
        record=numpy.empty((1,len(recordFromErlang)),dtype="f")
        record[0]=numpy.asarray(recordFromErlang,dtype="f")
        record=self.scaler.transform(record)
        prediction=self.model.predict(record)
        prediction=prediction.tolist()
        recordDecided=recordFromErlang+prediction
        return recordDecided

    def dump(self,directory):
        model_file=directory+"/model"
        scaler_file=directory+"/scaler"
        with open(model_file,'wb') as f_model:
            pickle.dump(self.model,f_model)
        with open(scaler_file,'wb') as f_scaler:
            pickle.dump(self.scaler,f_scaler)

    def load(self,directory):
        model_file=directory+"/model"
        scaler_file=directory+"/scaler"
        with open(model_file,'rb') as f_model:
            self.model=pickle.load(f_model)
        with open(scaler_file,'rb') as f_scaler:
            self.scaler=pickle.load(f_scaler)