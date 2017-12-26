/*
 *
 * putc.c
 *
 * Created at:  19 Oct 2017 18:15:31 +0200 (CEST)
 *
 * Author:  Szymon Urbaś <szymon.urbas@aol.com>
 *
 * License:  please visit the LICENSE file for details.
 *
 */

#include <ipc.h>
#include <msg/io.h>

int putc(char c)
{
  struct msg_io msg;
  int result;
  int screen = find_by_name("screen");

  msg.type = MSG_PUTC;
  msg.one_char = c;

  ipc_send(screen, &msg, sizeof msg, &result, sizeof result);

  return result;
}

/*
 * vi: ft=c:ts=2:sw=2:expandtab
 */


/*
 * vi: ft=c:ts=2:sw=2:expandtab
 */

