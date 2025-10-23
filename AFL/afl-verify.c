#include "config.h"
#include "types.h"
#include "debug.h"
#include "alloc-inl.h"
#include "hash.h"

#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <errno.h>
#include <signal.h>
#include <dirent.h>
#include <ctype.h>
#include <fcntl.h>
#include <termios.h>
#include <dlfcn.h>
#include <sched.h>
#include <stdbool.h>

#include <sys/wait.h>
#include <sys/time.h>
#include <sys/shm.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/resource.h>
#include <sys/mman.h>
#include <sys/ioctl.h>
#include <sys/file.h>

#define EXP_ST

#define ADDRESS_LOG_FILE    "./log/address_log"
#define ADDRESS_LOG_SUB_GROUNDTRUTH "./log/subgt"
#define ICALL_VIOLATION_LOG "./log/icall_violation_log"

#define ENV_ICALL_ID    "ICALL"
#define ENV_TARGET_ID   "TARGET"
#define ENV_TARGET_ADDR "ADDRESS"
#define ENV_NULL_MODE   "NULLPTR"


EXP_ST u8  icall_save_input = 1;        /* Time to save the input to icall/input  */
EXP_ST u8  icallmap_changed = 1;         /* Time to update icallmap?                */
EXP_ST u8  icall_violation = 1;         /* Mark there is an icall violation*/

EXP_ST u64 total_icalls,              /* Total indirect calls             */
           total_ipairs,              /* Total icall pairs                */
           dbg_total_mallocs;         /* Debug number of malloc operations*/                       

struct address_entry {
    u64 address;                        /* Indirect call address     */
    bool has_flipped;                   /* whether this icall target has been flipped to yet?*/
    u32 target_id;                      /* current address's target_id*/
    struct address_entry *next;         /* Next element, if any      */
};

static struct address_entry *overall_icall[MAP_SIZE];      /* Overall indirect call by fuzzing */
static struct address_entry *overall_icall_flip[MAP_SIZE]; /* Overall indirect call by fuzzing (identical to overall_icall dry-run) */
static struct address_entry *overall_load_flip[MAP_SIZE];  /* Record and Flip start from loading side*/ 

static s32 overall_icall_target_num[MAP_SIZE];             /* Quick search how many target num for this icall*/

/* helper function, to recursively copy linked list*/

struct address_entry* copy_address_entry(struct address_entry* original) {
    if (original == NULL) {
        return NULL;
    }

    // allocate memory for new entry and copy data
    struct address_entry* new_entry = (struct address_entry*)malloc(sizeof(struct address_entry));
    if (new_entry == NULL) {
        return NULL;
    }

    new_entry->address = original->address;
    new_entry->has_flipped = original->has_flipped;
    new_entry->target_id = original->target_id;
    
    // recursively copy next from original 
    new_entry->next = copy_address_entry(original->next);

    return new_entry;
}


/* search execution_icall[head] to find target exist or not, 
   if exist return 1, if not return 0         */
static int icall_search(struct address_entry* head, u64 target) {
    struct address_entry* current = head;
    while (current != NULL) {
        if (current->address == target) {
            // found it, means that target_id should increase, because this is a duplicate icall;
            //current->target_id++; should only be performed after dry run --> don't implement here
            return 1;
        }
        current = current->next;
    }
    return 0;
}

/* append new_address to execution_icall       */
static void icall_append(struct address_entry** head_ref, u64 new_address ,u64 icall_id) {

    struct address_entry* new = (struct address_entry*)malloc(sizeof(struct address_entry)); //TODO: use ck_alloc
    dbg_total_mallocs++ ; 
    new->address = new_address;
    new->next = NULL;
    new->has_flipped =false;

    overall_icall_target_num[icall_id]++;
    new->target_id = 1;

    if (*head_ref == NULL) {
        *head_ref = new;
    } else {
        new->next = *head_ref;
        *head_ref = new;
    }
}

void load_ground_truth() {

  struct address_entry* current;
  
  //bool no_target_need_to_flip = false;
  //while (!no_target_need_to_flip) {

  //  ACTF("Entering a new round of fliping because of trigging new icall targets");
  //  no_target_need_to_flip = true;
  
  // use an identical overall_icall_flip, don't use overall_icall
  // (because it will be updated when invoking common_fuzz_stuff)
  // add here
  for (int i = 0; i < MAP_SIZE; i++) {
      if (overall_icall[i] != NULL) {
          overall_icall_flip[i] = copy_address_entry(overall_icall[i]);
      } else {
          overall_icall_flip[i] = NULL;
      }
  }

  u64 tmp_addr_s = 0;
  u64 tmp_id_s = 0;
  size_t size_in_bytes_s = sizeof(tmp_addr_s);

  /*replace with reading a sub-gt folder*/
  struct dirent *entry;
  DIR *dir = opendir(ADDRESS_LOG_SUB_GROUNDTRUTH);

  if (!dir) {
      FATAL("Unable to open directory: %s", ADDRESS_LOG_SUB_GROUNDTRUTH);
  }

  char filepath[1024]; 

  while ((entry = readdir(dir)) != NULL) {
      // Skip "." and ".." entries
      if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) {
        continue;
      }
      
      // Construct full file path
      
     snprintf(filepath, sizeof(filepath), "%s/%s", ADDRESS_LOG_SUB_GROUNDTRUTH, entry->d_name);
     ACTF("Now loading sub-gt %s",filepath);
      FILE* address_s_log = fopen(filepath, "rb");
      if (address_s_log) {
          
            /* reduce time complexity */
          struct address_entry *cur_ovep_s = NULL;
          while (fread(&tmp_id_s, size_in_bytes_s, 1, address_s_log) == 1 && fread(&tmp_addr_s, size_in_bytes_s, 1, address_s_log) == 1){
              cur_ovep_s = overall_load_flip[tmp_id_s];

              if (!icall_search(cur_ovep_s, tmp_addr_s)){
                      // we need to add to overall_icall
                  // ACTF("appending");
                  // ACTF("loading icall id %d", tmp_id_s);
                  icall_append(&overall_load_flip[tmp_id_s],tmp_addr_s, tmp_id_s);

              }

          }

      }
      else {
        ACTF("Fail to load sub-gt %s", filepath);
      }
      fclose(address_s_log);
  }

  closedir(dir);

}

void load_address_log() {

  u8   block_cov_changed = 0 ;
  u8   branch_cov_changed = 0;
  u8   icall_cov_changed = 0;
  u8   ipair_cov_changed = 0;

  u8* lfn = alloc_printf(ADDRESS_LOG_FILE);  // TODO: 需要修改log的存在位置
  FILE* address_log = fopen(lfn,"rb");
  /* do not trigger indirect call in this run, return immediately */
  if (address_log == NULL)
  {
    ck_free(lfn);
    return;
  }
  u64 tmp_addr = 0;
  u64 tmp_id = 0;
  size_t size_in_bytes = sizeof(tmp_addr);

  /* reduce time complexity */
  icall_save_input = 0;
  icall_violation = 0;
  struct address_entry *cur_ovep = NULL;
  struct address_entry *cur_ovep_gt = NULL;
  while (fread(&tmp_id, size_in_bytes, 1, address_log) == 1 && fread(&tmp_addr, size_in_bytes, 1, address_log) == 1){
      cur_ovep = overall_icall[tmp_id];

      cur_ovep_gt = overall_load_flip[tmp_id];
      if (!icall_search(cur_ovep_gt, tmp_addr)) {
        icall_violation = 1;
        ACTF("New icall/icall targets, id:address-%lld-%lld(0x%llx)\n",tmp_id, tmp_addr, tmp_addr);
        u8* vfn = alloc_printf(ICALL_VIOLATION_LOG);
        FILE* icall_vio_log = fopen(vfn,"a");
        if (icall_vio_log) {
        fprintf(icall_vio_log, "icall violation:%lld-%lld(0x%llx)\n",tmp_id, tmp_addr, tmp_addr);
        fclose(icall_vio_log);
        ck_free(vfn);
        } else {
        ck_free(vfn);
        perror("Error opening ICALL_VIOLATION_LOG file");
        }
      }


      if (!icall_search(cur_ovep, tmp_addr)){
              // we need to add to overall_icall
          icallmap_changed = 1;
          icall_save_input = 1;
          

          if (cur_ovep == NULL) {total_icalls++; icall_cov_changed=1;}

          icall_append(&overall_icall[tmp_id],tmp_addr, tmp_id);
          total_ipairs++;
          ipair_cov_changed = 1;

      }

  }
}

/* Main entry point */
int main(int argc, char** argv) {

    // load env
    u32 icall_id = getenv(ENV_ICALL_ID);
    u32 target_id = getenv(ENV_TARGET_ID);
    u64 flipped_target_address = getenv(ENV_TARGET_ADDR);

    // load subgt and address_log
    load_ground_truth();
    load_address_log();

    // write log if violation happens
    if (icall_violation == 1) {
        ACTF("↑↑↑↑↑↑↑↑↑↑↑ icall violation happens during the flip ↑↑↑↑↑↑↑↑↑↑↑\n");
        
        u8* vfn = alloc_printf(ICALL_VIOLATION_LOG);
        FILE* icall_vio_log = fopen(vfn,"a");
        if (icall_vio_log) {  // icall_id - flipped_to_target_address - entered_time
        fprintf(icall_vio_log,
                "flip operation:%d-%ld(0x%lx)-%d\n", 
                             icall_id, flipped_target_address, flipped_target_address, target_id);
        fprintf(icall_vio_log, "------ icall violation happens during the flip ------\n\n\n");
        fclose(icall_vio_log);
        ck_free(vfn);
        } else {
          ck_free(vfn);
          perror("Error opening ICALL_VIOLATION_LOG file");
        }

    }
}
