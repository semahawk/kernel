/*
 *
 * timer.c
 *
 * Created at:  Mon  3 Nov 18:34:57 2014 18:34:57
 *
 * Author:  Szymon Urbaś <szymon.urbas@aol.com>
 *
 * License:  please visit the LICENSE file for details.
 *
 */

#include <kernel/common.h>
#include <kernel/idt.h>
#include <kernel/proc.h>
#include <kernel/print.h>
#include <kernel/x86.h>

/* this counter will keep track of how many ticks the system has been
 * running for */
static volatile int timer_ticks = 0;

/* this is actually very simple: we increment the tick counter every time the
 * timer fires (by default the timer fires 18.222 times per second) */
struct intregs *timer_handler(struct intregs *regs)
{
  struct intregs *ret;

  timer_ticks++;

  ret = proc_schedule_after_irq(regs);

  return ret;
}

void timer_wait(int ticks)
{
  unsigned long eticks;

  eticks = timer_ticks + ticks;

  while (timer_ticks < eticks)
    __asm volatile("sti\n\thlt\n\tcli");
}

void timer_set_phase(int hz)
{
  int divisor = 1193180 / hz;     /* Calculate our divisor */

  outb(0x43, 0x36);           /* Set our command byte 0x36 */
  outb(0x40, divisor & 0xFF); /* Set low byte of divisor */
  outb(0x40, divisor >> 8);   /* Set high byte of divisor */
}

/* set up the system clock by installing the timer handler into IRQ0 */
void timer_install(void)
{
  irq_install_handler(0, timer_handler, 0);

  timer_set_phase(1000);

  kprintf("[timer] timer was set up (irq 0)\n");
}

void timer_uninstall(void)
{
  irq_uninstall_handler(0);
}

/*
 * vi: ft=c:ts=2:sw=2:expandtab
 */

