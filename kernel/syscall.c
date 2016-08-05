/*
 *
 * syscall.c
 *
 * Created at:  Sat Sep 26 09:23:03 2015 09:23:03
 *
 * Author:  Szymon Urbaś <szymon.urbas@aol.com>
 *
 * License:  please visit the LICENSE file for details.
 *
 */

#include <stdint.h>

#include <kernel/common.h>
#include <kernel/idt.h>
#include <kernel/pm.h>
#include <kernel/proc.h>
#include <kernel/syscall.h>
#include <kernel/vga.h>

#include <ipc.h>

struct intregs *syscall_send_msg(struct intregs *regs)
{
  proc_disable_scheduling();

  struct msg *msg = (void *)regs->eax;

  msg->sender = current_proc->pid;

  /* TODO do some sanity checking for when the receiver's mailbox is full */
  proc_push_msg(msg->receiver, msg);

  proc_enable_scheduling();

  return regs;
}

struct intregs *syscall_recv_msg(struct intregs *regs)
{
  struct msg *dest_msg = (void *)regs->eax;
  struct msg *msg_in_line = NULL;
  int wanted_sender = regs->ebx;

  proc_disable_scheduling();

  if (NULL != (msg_in_line = proc_pop_msg(current_proc->pid))){
    if (wanted_sender == 0 || msg_in_line->sender == wanted_sender){
      regs->eax = 1;
      /* copy the message that's been waiting in the line over to the destination */

      memcpy(dest_msg, msg_in_line, sizeof(*dest_msg));
    } else {
      regs->eax = 0;

      /* FIXME this might not be the most efficient way to handle messages
       * from a different sender that we wanted */
      proc_push_msg(current_proc->pid, msg_in_line);
    }
  } else {
    regs->eax = 0;
  }

  proc_enable_scheduling();

  return regs;
}

void syscall_install(void)
{
  idt_set_gate(SYSCALL_SEND_MSG_VECTOR, int186, 8, 0xee);
  idt_set_gate(SYSCALL_RECV_MSG_VECTOR, int190, 8, 0xee);

  int_install_handler(SYSCALL_SEND_MSG_VECTOR, syscall_send_msg);
  int_install_handler(SYSCALL_RECV_MSG_VECTOR, syscall_recv_msg);
}

/*
 * vi: ft=c:ts=2:sw=2:expandtab
 */

