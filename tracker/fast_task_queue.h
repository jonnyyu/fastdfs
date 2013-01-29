/**
* Copyright (C) 2008 Happy Fish / YuQing
*
* FastDFS may be copied only under the terms of the GNU General
* Public License V3, which may be found in the FastDFS source kit.
* Please visit the FastDFS Home Page http://www.csource.org/ for more detail.
**/

//fast_task_queue.h

#ifndef _TASK_QUEUE_H
#define _TASK_QUEUE_H 

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <event.h>
#include "common_define.h"
#include "chain.h"

struct fast_task_info;

typedef int (*TaskFinishCallBack) (struct fast_task_info *pTask);

struct fast_task_info
{
	char client_ip[IP_ADDRESS_SIZE];
	struct event ev_read;
	struct event ev_write;
	void *arg;  //extra argument pointer
	char *data; //buffer for write or recv
	int size;   //alloc size
	int length; //data length
	int offset; //current offset
	int req_count; //request count
	struct fast_task_info *next;
	TaskFinishCallBack finish_callback;
};

struct fast_task_queue
{
	struct fast_task_info *head;
	struct fast_task_info *tail;
	pthread_mutex_t lock;
	int max_connections;
	int min_buff_size;
	int max_buff_size;
	int arg_size;
	bool malloc_whole_block;
};

#ifdef __cplusplus
extern "C" {
#endif

int free_queue_init(const int max_connections, const int min_buff_size, \
		const int max_buff_size, const int arg_size);

void free_queue_destroy();

int free_queue_push(struct fast_task_info *pTask);
struct fast_task_info *free_queue_pop();
int free_queue_count();


int task_queue_init(struct fast_task_queue *pQueue);
int task_queue_push(struct fast_task_queue *pQueue, \
		struct fast_task_info *pTask);
struct fast_task_info *task_queue_pop(struct fast_task_queue *pQueue);
int task_queue_count(struct fast_task_queue *pQueue);

#ifdef __cplusplus
}
#endif

#endif

