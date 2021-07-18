#include<netinet/in.h>
#include<erl_nif.h>
#include<stdio.h>
#include<stdlib.h>
#include<sys/types.h>
#include<net/ethernet.h>
#include<sys/socket.h>
#include<unistd.h>

//gcc -shared -fpic -I/usr/lib/erlang/usr/include -o snifNif.so snifNif.c

//NB: se faccio ping sulla stessa macchina dalla stessa macchina E la grandezza del pacchetto è
//    maggiore a 40000 => questo sniffer va in errore di segmentazione!!!!

typedef struct sniffer{
	int sniffer;
	unsigned char *buffer;
}sniffer_t;

static int load(ErlNifEnv* caller_env, void** priv_data, ERL_NIF_TERM load_info){
    sniffer_t *p=(sniffer_t*)malloc(sizeof(sniffer_t));
    p->buffer=(unsigned char*)malloc(65536);
    p->sniffer=socket(AF_PACKET,SOCK_RAW, htons(ETH_P_ALL));
    struct timeval timeout;//the sniffer will wait for 2 seconds for packets, then it will proceed   
    timeout.tv_sec = 2;
    timeout.tv_usec = 0;
    setsockopt(p->sniffer, SOL_SOCKET, SO_RCVTIMEO, (char *)&timeout,sizeof(timeout));//
    *priv_data=p;
    return 0;
}

static int upgrade(ErlNifEnv* caller_env, void** priv_data, void** old_priv_data,ERL_NIF_TERM load_info){
    *priv_data=*old_priv_data;
    return 0;
}

static void unload(ErlNifEnv* caller_env, void* priv_data){
    free(priv_data);
}

static ERL_NIF_TERM sniff(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]){
    sniffer_t *p=(sniffer_t*)enif_priv_data(env);
	int data_size=recv(p->sniffer,p->buffer,65536,MSG_TRUNC);
    if(data_size== -1 || data_size>65536){
        return enif_make_int(env,0);
    }else{
        ERL_NIF_TERM st[data_size];
        for(int i=0;i<data_size;i++){
            st[i]=enif_make_int(env,p->buffer[i]);
        }
        return enif_make_list_from_array(env,st,data_size);
    }
}

static ErlNifFunc nif_funcs[] = {
    {"sniff", 0, sniff,ERL_NIF_DIRTY_JOB_IO_BOUND}
};

ERL_NIF_INIT(sniffer, nif_funcs,load, NULL,upgrade,unload)
