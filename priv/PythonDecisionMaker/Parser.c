#include "/usr/local/include/python3.7m/Python.h"
#include "/usr/lib/erlang/lib/erl_interface-3.12/include/ei.h"
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>

//COMPILING COMMAND PARSER.C
//gcc -Wall -shared -fpic -o Parser.so -L/usr/lib/erlang/lib/erl_interface-3.12/lib Parser.c -lei -lpthread

static PyObject* erlPy(const char *,int *);
static PyObject* parseCellErlToPy(const char *,int *);
static void pyErl(ei_x_buff *,PyObject *,int);
static void parseCellPyToErl(ei_x_buff *,PyObject *);

static PyObject* parseCellErlToPy(const char *list,int *index){
    int type=0;
    int size=0;
    ei_get_type(list,index,&type,&size);
    if(type==ERL_SMALL_INTEGER_EXT || type==ERL_INTEGER_EXT || type==ERL_SMALL_BIG_EXT){
        long p=0;
        ei_decode_long(list,index,&p);
        return PyLong_FromLong(p);
    }else if(type==ERL_FLOAT_EXT){
        double p=0.0;
        ei_decode_double(list,index,&p);
        return PyFloat_FromDouble(p);
    }else if(type==ERL_STRING_EXT){
        char p[size];
        ei_decode_string(list,index,p);
        return PyUnicode_DecodeFSDefault(p);
    }else if(type==ERL_NIL_EXT){
        int len=0;
        ei_decode_list_header(list,index,&len);
        return NULL;
    }else{
        return erlPy(list,index);
    }
}

static PyObject* erlPy(const char *buff,int *index){
    int len=0;
    PyObject *pyEl;
    PyObject *list;
    ei_decode_list_header(buff,index,&len);
    list=PyList_New(len);
    for(int i=0;i<=len;i++){//DEVO TENERE CONTO DELLA FINE LISTA!!(LISTA VUOTA)
        pyEl=parseCellErlToPy(buff,index);
        if(pyEl!=NULL){//nel caso ritorno la lista vuota
            PyList_SetItem(list,i,pyEl);
        }
    }
    return list;
}

static PyObject *parseErlToPy(PyObject *self, PyObject *args){
    ei_init();
    /*FILE *fp;
    fp=fopen("logC.txt","a+");*/
    /*fprintf(fp,"ARIETA: %d\n",len);
    fclose(fp);*/
    int index=0;
    int version=0;
    const char *ret;
    Py_buffer buff;
    if (!PyArg_ParseTuple(args, "y*", &buff)){
        return NULL;
    }
    ret=(const char *)buff.buf;
    ei_decode_version(ret,&index,&version);
    PyBuffer_Release(&buff);
    return erlPy(ret,&index);
}

static void parseCellPyToErl(ei_x_buff *buffer,PyObject *el){
    if(strcmp((el->ob_type)->tp_name,"int")==0){
        long p;
        p=PyLong_AsLong(el);
        ei_x_encode_long(buffer,p);
    }else if(strcmp((el->ob_type)->tp_name,"float")==0){
        double p;
        p= PyFloat_AsDouble(el);
        ei_x_encode_double(buffer,p);
    }else if(strcmp((el->ob_type)->tp_name,"str")==0){
        const char *p=NULL;
        long int size=0;
        p=PyUnicode_AsUTF8AndSize(el,&size);
        ei_x_encode_string_len(buffer,p,size);
    }else{
        int len=PyList_Size(el);
        return pyErl(buffer,el,len);
    }
}

static void pyErl(ei_x_buff *buffer,PyObject *list,int len){
    PyObject *pyEl;
    ei_x_encode_list_header(buffer,len);
    for(int i=0;i<len;i++){
        pyEl=PyList_GetItem(list,i);
        parseCellPyToErl(buffer,pyEl);
    }
    ei_x_encode_empty_list(buffer);
}

static PyObject *parsePyToErl(PyObject *self, PyObject *args){
    ei_init();
    PyObject *list;
    PyObject *ret;
    int len=0;
    ei_x_buff buffer;
    if (!PyArg_ParseTuple(args, "O!", &PyList_Type, &list)){
        return NULL;
    }
    len=PyList_Size(list);
    ei_x_new(&buffer);
    ei_x_encode_version(&buffer);
    pyErl(&buffer,list,len);
    ret=PyBytes_FromStringAndSize(buffer.buff,buffer.index);
    ei_x_free(&buffer);
    return ret;
}

static PyMethodDef ParserMethods[] = {
    {"parseErlToPy",  parseErlToPy, METH_VARARGS,"Parsing from Erlang term format to Python"},
    {"parsePyToErl",  parsePyToErl, METH_VARARGS,"Parsing from Python to Erlang term format"},
    {NULL, NULL, 0, NULL}        /* Sentinel */
};

static struct PyModuleDef parsermodule = {
    PyModuleDef_HEAD_INIT,
    "Parser",   /* name of module */
    NULL, /* module documentation, may be NULL */
    -1,       /* size of per-interpreter state of the module,
                 or -1 if the module keeps state in global variables. */
    ParserMethods
};

PyMODINIT_FUNC
PyInit_Parser(void){
    return PyModule_Create(&parsermodule);
}
