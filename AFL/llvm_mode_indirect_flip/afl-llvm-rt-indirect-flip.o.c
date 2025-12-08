/*
  Copyright 2015 Google LLC All rights reserved.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at:

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
*/

/*
   american fuzzy lop - LLVM instrumentation bootstrap
   ---------------------------------------------------

   Written by Laszlo Szekeres <lszekeres@google.com> and
              Michal Zalewski <lcamtuf@google.com>

   LLVM integration design comes from Laszlo Szekeres.

   This code is the rewrite of afl-as.h's main_payload.
*/

/*
   Modifications for SACK
   -------------------------------------

   Modified by Zhechang Zhang, 2025.

   These modifications remain under the original Apache 2.0 license
   and retain all original copyright and attribution notices.
*/

#include "../android-ashmem.h"
#include "../config.h"
#include "../types.h"

#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
#include <unistd.h>
#include <string.h>
#include <assert.h>
#include <fcntl.h>

#include <sys/mman.h>
#include <sys/shm.h>
#include <sys/wait.h>
#include <sys/types.h>
#include <errno.h>

/* This is a somewhat ugly hack for the experimental 'trace-pc-guard' mode.
   Basically, we need to make sure that the forkserver is initialized after
   the LLVM-generated runtime initialization pass, not before. */

#ifdef USE_TRACE_PC
#  define CONST_PRIO 5
#else
#  define CONST_PRIO 0
#endif /* ^USE_TRACE_PC */

#define NOT_TRIGGERED 10000000

#define ENV_ICALL_ID    "ICALL"
#define ENV_TARGET_ID   "TARGET"
#define ENV_TARGET_ADDR "ADDRESS"
#define ENV_NULL_MODE   "NULLPTR"

/* Globals needed by the injected instrumentation. The __afl_area_initial region
   is used for instrumentation output before __afl_map_shm() has a chance to run.
   It will end up as .comm, so it shouldn't be too wasteful. */

u8  __afl_area_initial[(MAP_SIZE + 1)];
u8* __afl_area_ptr = __afl_area_initial;

u64 indirect_call_map[MAP_SIZE];
u64 store_map[MAP_SIZE];


__thread u32 __afl_prev_loc;


/* Running in persistent mode? */

static u8 is_persistent;

/* Assign ID and flag*/
static u32 cond_icall_id = (u32)(-2);
static u32 cond_target_id = (u32)(-2);
static u64 cond_flipped_target_address = (u64)(-2);

static u32 dry_run_flag = 1;
static u32 null_ptr_mode_flag = 0;
static u32 icall_id = NOT_TRIGGERED;
static u32 target_id = NOT_TRIGGERED;
static u64 flipped_target_address = (u32)(-2);

int has_flipped = 0;    // represent whether we have already flipped it or not, if yes, we do not flipped 
int counter = 0;        // mark current enter counter


/* Load map setting*/

#define MAX_TARGETS   100 // max targets num of one icall
#define MAX_NAME_LEN  50  // max name length of one function

FILE *address_log = NULL;

#define ADDRESS_LOG_FILE    "./log/address_log"

/* SHM setup. */

static void __afl_map_shm(void) {

  u8 *id_str = getenv(SHM_ENV_VAR);

  /* If we're running under AFL, attach to the appropriate region, replacing the
     early-stage __afl_area_initial region that is needed to allow some really
     hacky .init code to work correctly in projects such as OpenSSL. */

  if (id_str) {

    u32 shm_id = atoi(id_str);

    __afl_area_ptr = shmat(shm_id, NULL, 0);

    /* Whooooops. */

    if (__afl_area_ptr == (void *)-1) _exit(1);

    /* Write something into the bitmap so that even with low AFL_INST_RATIO,
       our parent doesn't give up on us. */

    __afl_area_ptr[0] = 1;

  }

}


/* Fork server logic. */

static void __afl_start_forkserver(void) {

  static u8 tmp[24];
  s32 child_pid;

  u8  child_stopped = 0;

  /* Phone home and tell the parent that we're OK. If parent isn't there,
     assume we're not running in forkserver mode and just execute program. */

  if (write(FORKSRV_FD + 1, tmp, 4) != 4) return;

  while (1) {

    u32 was_killed;
    int status;

    /* Wait for parent by reading from the pipe. Abort if read fails. */

    if (read(FORKSRV_FD, tmp, 28) != 28) _exit(1); // [TODO]: need to match with afl-fuzz
    was_killed = *(u32 *)tmp;
    dry_run_flag = *(u32 *)(tmp + 4);
    icall_id = *(u32 *)(tmp + 8);
    target_id = *(u32 *)(tmp + 12);
    flipped_target_address = *(u64 *)(tmp + 16);
    null_ptr_mode_flag = *(u32 *)(tmp + 24);

    int fd;

    if (!access(ADDRESS_LOG_FILE,F_OK)) remove(ADDRESS_LOG_FILE);
    fd = open(ADDRESS_LOG_FILE, O_WRONLY | O_CREAT | O_EXCL, 0777);
    chmod(ADDRESS_LOG_FILE, 0777);
    close(fd);

    if (address_log) fclose(address_log);
    address_log = fopen(ADDRESS_LOG_FILE,"ab");

    /* If we stopped the child in persistent mode, but there was a race
       condition and afl-fuzz already issued SIGKILL, write off the old
       process. */

    if (child_stopped && was_killed) {
      child_stopped = 0;
      if (waitpid(child_pid, &status, 0) < 0) _exit(1);
    }

    if (!child_stopped) {


      cond_icall_id = icall_id;
      cond_target_id = target_id;
      cond_flipped_target_address = flipped_target_address;

      child_pid = fork();
      if (child_pid < 0) _exit(1);

      /* In child process: close fds, resume execution. */

      if (!child_pid) {

        close(FORKSRV_FD);
        close(FORKSRV_FD + 1);
        return;
  
      }

    } else {

      /* Special handling for persistent mode: if the child is alive but
         currently stopped, simply restart it with SIGCONT. */

      kill(child_pid, SIGCONT);
      child_stopped = 0;

    }

    /* In parent process: write PID to pipe, then wait for child. */

    if (write(FORKSRV_FD + 1, &child_pid, 4) != 4) _exit(1);

    if (waitpid(child_pid, &status, is_persistent ? WUNTRACED : 0) < 0)
      _exit(1);

    /* In persistent mode, the child stops itself with SIGSTOP to indicate
       a successful run. In this case, we want to wake it up without forking
       again. */

    if (WIFSTOPPED(status)) child_stopped = 1;

    /* Relay wait status to pipe, then loop back. */

    if (write(FORKSRV_FD + 1, &status, 4) != 4) _exit(1);

  }

}


/* A simplified persistent mode handler, used as explained in README.llvm. */

int __afl_persistent_loop(unsigned int max_cnt) {

  static u8  first_pass = 1;
  static u32 cycle_cnt;

  if (first_pass) {

    /* Make sure that every iteration of __AFL_LOOP() starts with a clean slate.
       On subsequent calls, the parent will take care of that, but on the first
       iteration, it's our job to erase any trace of whatever happened
       before the loop. */

    if (is_persistent) {

      memset(__afl_area_ptr, 0, (MAP_SIZE+1));
      __afl_area_ptr[0] = 1;
      __afl_prev_loc = 0;
    }

    cycle_cnt  = max_cnt;
    first_pass = 0;
    return 1;

  }

  if (is_persistent) {

    if (--cycle_cnt) {
      //fprintf(stderr, "cycle_cnt: %d\n", cycle_cnt);
      raise(SIGSTOP);

      __afl_area_ptr[0] = 1;
      __afl_prev_loc = 0;

      return 1;

    } else {

      /* When exiting __AFL_LOOP(), make sure that the subsequent code that
         follows the loop is not traced. We do that by pivoting back to the
         dummy output region. */

      __afl_area_ptr = __afl_area_initial;

    }

  }

  return 0;

}


/* This one can be called from user code when deferred forkserver mode
    is enabled. */

void __afl_manual_init(void) {

  static u8 init_done;

  if (!init_done) {

    __afl_map_shm();
    __afl_start_forkserver();
    init_done = 1;

  }

}


/* Proper initialization routine. */

__attribute__((constructor(CONST_PRIO))) void __afl_auto_init(void) {
  /* Initialization log file*/
  // mkdir("log",0755);
  int fd;

  if (!access(ADDRESS_LOG_FILE,F_OK)) remove(ADDRESS_LOG_FILE);
  fd = open(ADDRESS_LOG_FILE, O_WRONLY | O_CREAT | O_EXCL, 0777);
  chmod(ADDRESS_LOG_FILE, 0777);
  close(fd);

  address_log = fopen(ADDRESS_LOG_FILE,"ab");

  // system("chmod -R 777 log");
  
  // disable dryrun if any flipping env is specified
  if (getenv(ENV_ICALL_ID) ||
      getenv(ENV_TARGET_ID) ||
      getenv(ENV_TARGET_ADDR) ||
      getenv(ENV_NULL_MODE)) {
      dry_run_flag = 0;
  }

  const char* env_icall_id = getenv(ENV_ICALL_ID);
  if (env_icall_id) {
    icall_id = atoi(env_icall_id);
    cond_icall_id = icall_id;
  }

  const char* env_target_id = getenv(ENV_TARGET_ID);
  if (env_target_id) {
    target_id = atoi(env_target_id);
    cond_target_id = target_id;
  }

  const char* env_target_addr = getenv(ENV_TARGET_ADDR);
  if (env_target_addr) {
    flipped_target_address = atoi(env_target_addr);
    cond_flipped_target_address = flipped_target_address;
  }

  if (getenv(ENV_NULL_MODE)) {
    null_ptr_mode_flag = 1;
    flipped_target_address = 0;
    cond_flipped_target_address = flipped_target_address;
  }



  is_persistent = !!getenv(PERSIST_ENV_VAR);

  if (getenv(DEFER_ENV_VAR)) return;

  __afl_manual_init();

}

void __attribute__((destructor(CONST_PRIO))) destructor() {
  if (address_log != NULL){
    fflush(address_log);
    fclose(address_log);
    address_log = NULL;
    //fprintf(stderr, "fclose\n");

  }

}


/* The following stuff deals with supporting -fsanitize-coverage=trace-pc-guard.
   It remains non-operational in the traditional, plugin-backed LLVM mode.
   For more info about 'trace-pc-guard', see README.llvm.

   The first function (__sanitizer_cov_trace_pc_guard) is called back on every
   edge (as opposed to every basic block). */

void __sanitizer_cov_trace_pc_guard(uint32_t* guard) {
  __afl_area_ptr[*guard]++;
}


/* Init callback. Populates instrumentation IDs. Note that we're using
   ID of 0 as a special value to indicate non-instrumented bits. That may
   still touch the bitmap, but in a fairly harmless way. */

void __sanitizer_cov_trace_pc_guard_init(uint32_t* start, uint32_t* stop) {

  u32 inst_ratio = 100;
  u8* x;

  if (start == stop || *start) return;

  x = getenv("AFL_INST_RATIO");
  if (x) inst_ratio = atoi(x);

  if (!inst_ratio || inst_ratio > 100) {
    fprintf(stderr, "[-] ERROR: Invalid AFL_INST_RATIO (must be 1-100).\n");
    abort();
  }

  /* Make sure that the first element in the range is always set - we use that
     to avoid duplicate calls (which can happen as an artifact of the underlying
     implementation in LLVM). */

  *(start++) = R(MAP_SIZE - 1) + 1;

  while (start < stop) {

    if (R(100) < inst_ratio) *start = R(MAP_SIZE - 1) + 1;
    else *start = 0;

    start++;

  }

}

int __record_icall(uint64_t call_address, uint64_t id) {
  
  uint64_t id_address_pair[2];
  id_address_pair[0] = id;
  id_address_pair[1] = call_address;
  
  int arraysize = sizeof(id_address_pair) / sizeof (id_address_pair[0]);
  if (indirect_call_map[id] != call_address){

      size_t written = fwrite(id_address_pair, sizeof(uint64_t), arraysize, address_log);
      fflush(address_log);
      

      if (written != arraysize){
        perror("failed to write to address_log");
	      fprintf(stderr, "fail to write\n");
       }

     indirect_call_map[id] = call_address;
  }
  
  return 1;
}


uint64_t  __modify_mem_func(uint64_t mem_location, uint64_t id) {   // [TODO]: if id == -1 , then it means don't modify it
    
    if (null_ptr_mode_flag){
      return 0;  // 0->no flip
    }

    if (dry_run_flag) { 
        
      return 0;  // 0-> no flip
    }

    if (has_flipped == 1) {
        

        return has_flipped;   // 1-> has flipped
    }

    // after this line. has_flipped is 0

    /* don't flip when id is wrong*/

    if (id != cond_icall_id) {


        return 0;  // 0-> no flip
    }

    /*ready to flip [TODO]: add counter strategy*/ 
    
    // flipped, no flip anymore

     // has_flipped == 0   , not flipped yet 

    if (counter != cond_target_id) {

      
      counter++;

      return has_flipped;
    
    }

    * (unsigned long *)mem_location = cond_flipped_target_address;

    has_flipped = 1;
    counter++;
    
    return 1;

}

int __write_nginx_log(uint32_t fd) {

    /*currently, we just need cond_icall_id and cond_flipped_target_address */
    
    /* u32 + u64 */
    
    ssize_t bytes_written = -1;
    char buffer[64];
    int length = snprintf(buffer, sizeof(buffer), "%u_%llu(0x%llx)_%d  ", 
    cond_icall_id, cond_flipped_target_address,cond_flipped_target_address,cond_target_id);

    if (length > 0){

        bytes_written = write(fd, buffer, length);

    }  

    // check if success
    if (bytes_written == -1) {
        
        return -1;
    }

  
  return 1;
}
