/*
 * Darkness - Load Sensitive CPU Frequency Governor
 *
 * Copyright (c) 2010-2016, Alucard24 <dmbaoh2@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 *
 */

#include <linux/cpu.h>
#include <linux/cpumask.h>
#include <linux/cpufreq.h>
#include <linux/module.h>
#include <linux/moduleparam.h>
#include <linux/rwsem.h>
#include <linux/sched.h>
#include <linux/sched/rt.h>
#include <linux/time.h>
#include <linux/timer.h>
#include <linux/workqueue.h>
#include <linux/kthread.h>
#include <linux/slab.h>
#include <asm/cputime.h>
#ifdef CONFIG_STATE_NOTIFIER
#include <linux/state_notifier.h>
#endif

struct cpufreq_darkness_policyinfo {
	struct timer_list policy_timer;
	struct timer_list policy_slack_timer;
	spinlock_t load_lock; /* protects load tracking stat */
	u64 last_evaluated_jiffy;
	struct cpufreq_policy *policy;
	struct cpufreq_frequency_table *freq_table;
	spinlock_t target_freq_lock; /*protects target freq */
	unsigned int target_freq;
	unsigned int min_freq;
	struct rw_semaphore enable_sem;
	bool reject_notification;
	int governor_enabled;
	struct cpufreq_darkness_tunables *cached_tunables;
	unsigned long *cpu_busy_times;
};

/* Protected by per-policy load_lock */
struct cpufreq_darkness_cpuinfo {
	u64 time_in_idle;
	u64 time_in_idle_timestamp;
	unsigned int load;
};

static DEFINE_PER_CPU(struct cpufreq_darkness_policyinfo *, polinfo);
static DEFINE_PER_CPU(struct cpufreq_darkness_cpuinfo, cpuinfo);

/* realtime thread handles frequency scaling */
static struct task_struct *speedchange_task;
static cpumask_t speedchange_cpumask;
static spinlock_t speedchange_cpumask_lock;
static struct mutex gov_lock;

#define DEFAULT_TIMER_RATE (20 * USEC_PER_MSEC)
#define DEFAULT_TIMER_RATE_SUSP ((unsigned long)(50 * USEC_PER_MSEC))

struct cpufreq_darkness_tunables {
	int usage_count;
	/*
	 * The sample rate of the timer used to increase frequency
	 */
	unsigned long timer_rate;
#ifdef CONFIG_STATE_NOTIFIER
	unsigned long timer_rate_prev;
#endif
	/*
	 * Max additional time to wait in idle, beyond timer_rate, at speeds
	 * above minimum before wakeup to reduce speed, or -1 if unnecessary.
	 */
#define DEFAULT_TIMER_SLACK (4 * DEFAULT_TIMER_RATE)
	int timer_slack_val;
	bool io_is_busy;
	/*
	 * Whether to align timer windows across all CPUs.
	 */
	bool align_windows;
};

/* For cases where we have single governor instance for system */
static struct cpufreq_darkness_tunables *common_tunables;
static struct cpufreq_darkness_tunables *cached_common_tunables;

static struct attribute_group *get_sysfs_attr(void);

/* Round to starting jiffy of next evaluation window */
static u64 round_to_nw_start(u64 jif,
			     struct cpufreq_darkness_tunables *tunables)
{
	unsigned long step = usecs_to_jiffies(tunables->timer_rate);
	u64 ret;

	if (tunables->align_windows) {
		do_div(jif, step);
		ret = (jif + 1) * step;
	} else {
		ret = jiffies + usecs_to_jiffies(tunables->timer_rate);
	}

	return ret;
}

static void cpufreq_darkness_timer_resched(unsigned long cpu,
					      bool slack_only)
{
	struct cpufreq_darkness_policyinfo *ppol = per_cpu(polinfo, cpu);
	struct cpufreq_darkness_cpuinfo *pcpu;
	struct cpufreq_darkness_tunables *tunables =
		ppol->policy->governor_data;
	u64 expires;
	unsigned long flags;
	int i;

	spin_lock_irqsave(&ppol->load_lock, flags);
	expires = round_to_nw_start(ppol->last_evaluated_jiffy, tunables);
	if (!slack_only) {
		for_each_cpu(i, ppol->policy->cpus) {
			pcpu = &per_cpu(cpuinfo, i);
			pcpu->time_in_idle = get_cpu_idle_time(i,
						&pcpu->time_in_idle_timestamp,
						tunables->io_is_busy);
		}
		del_timer(&ppol->policy_timer);
		ppol->policy_timer.expires = expires;
		add_timer(&ppol->policy_timer);
	}

	if (tunables->timer_slack_val >= 0 &&
	    ppol->target_freq > ppol->policy->min) {
		expires += usecs_to_jiffies(tunables->timer_slack_val);
		del_timer(&ppol->policy_slack_timer);
		ppol->policy_slack_timer.expires = expires;
		add_timer(&ppol->policy_slack_timer);
	}

	spin_unlock_irqrestore(&ppol->load_lock, flags);
}

/* The caller shall take enable_sem write semaphore to avoid any timer race.
 * The policy_timer and policy_slack_timer must be deactivated when calling
 * this function.
 */
static void cpufreq_darkness_timer_start(
	struct cpufreq_darkness_tunables *tunables, int cpu)
{
	struct cpufreq_darkness_policyinfo *ppol = per_cpu(polinfo, cpu);
	struct cpufreq_darkness_cpuinfo *pcpu;
	u64 expires = round_to_nw_start(ppol->last_evaluated_jiffy, tunables);
	unsigned long flags;
	int i;

	spin_lock_irqsave(&ppol->load_lock, flags);
	ppol->policy_timer.expires = expires;
	add_timer(&ppol->policy_timer);
	if (tunables->timer_slack_val >= 0 &&
	    ppol->target_freq > ppol->policy->min) {
		expires += usecs_to_jiffies(tunables->timer_slack_val);
		ppol->policy_slack_timer.expires = expires;
		add_timer(&ppol->policy_slack_timer);
	}

	for_each_cpu(i, ppol->policy->cpus) {
		pcpu = &per_cpu(cpuinfo, i);
		pcpu->time_in_idle 
