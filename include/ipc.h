/*
 *
 * ipc.h
 *
 * Created at:  28 Jul 2016 00:24:29 +0200 (CEST)
 *
 * Author:  Szymon Urbaś <szymon.urbas@aol.com>
 *
 * License:  please visit the LICENSE file for details.
 *
 */

#ifndef IPC_H
#define IPC_H

#include <kernel/common.h> /* for bool type */
#include <queue.h> /* for bool type */

struct msg_packet {
  int sender, receiver;
  void        *send_buf, *recv_buf;
  size_t       send_len,  recv_len;
  void *phys_send_buf, *phys_recv_buf;
  /* physical location of the msg_packet
   * it's a dirty hack - when a process calls ipc_recv, and there was no other
   * process having called ipc_send, this process gets blocked - but - when
   * finally some process decides to send the first process a message, then we
   * need to modify the return value of the ipc_recv call (we don't know the
   * sender at this point) */
  void *phys_msg_packet;
};

struct msg_packet_queue {
  struct msg_packet msg;
  STAILQ_ENTRY(msg_packet_queue) msgs;
};

/*
 * Send <send_len> bytes located at <send_buf> to process <receiver>, which is
 * expected to fill it's result into <recv_buf>.
 *
 * If the <receiver> hasn't yet called ipc_recv() then the current process
 * becomes send-blocked. Once the <receiver> calls ipc_recv() the kernel changes
 * the current process' state to reply-blocked. When the <receiver> calls
 * ipc_reply() the current process becomes ready (gets unblocked).
 *
 * So this call is blocking.
 */
bool ipc_send(int receiver, void *send_buf, size_t send_len, void *recv_buf, size_t recv_len);

/*
 * Check if any messages were sent to the current process
 *
 * If no other process has sent a message to the current process, then it
 * gets receive-blocked.
 * When another process sends a message to the current process then it
 * becomes ready to be scheduled (gets unblocked).
 *
 * If another process has already sent a message to the current process then
 * this call returns with the message (fills it into <msg>)
 *
 * So this call is blocking.
 *
 * Return the process id of the original sender which you can use when replying
 * to the original message.
 */
int ipc_recv(void *recv_buf, size_t recv_len);

/*
 * Send a message (<len> bytes at location <msg>) with a response to the
 * original <sender>. The <sender> then becomes ready (gets unblocked) and able
 * to act upon the reply.
 */
bool ipc_reply(int sender, void *send_buf, size_t send_len);

/*
 * Helper functions
 */

bool find_by_name(const char *name);

#endif /* !IPC_H */

/*
 * vi: ft=c:ts=2:sw=2:expandtab
 */

