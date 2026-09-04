// SPDX-License-Identifier: GPL-2.0-only
/*
 * Android 14 OnePlus 9R storage log ABI, adapted for Linux 4.14.
 *
 * Donor: OnePlusOSS/android_kernel_modules_and_devicetree_oneplus_sm8250
 *        oneplus/sm8250_u_14.0.0_op9r
 *        vendor/oplus/kernel/storage/storage_feature_in_module/common/
 *        storage_log/storage_log.c
 */

#define pr_fmt(fmt) "oplus_storage_log: " fmt

#include <linux/init.h>
#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/proc_fs.h>
#include <linux/sched/clock.h>
#include <linux/seq_file.h>
#include <linux/slab.h>
#include <linux/spinlock.h>
#include <linux/time.h>
#include <linux/uaccess.h>
#include <linux/vmalloc.h>

#define OPLUS_STORAGE_LOG_SIZE	(1024 * 1024)
#define OPLUS_STORAGE_LINE_MAX	1024
#define OPLUS_STORAGE_CLEAR	"clear storage log"
#define OPLUS_STORAGE_HEADER	"storage log begin:\n"

struct oplus_storage_log {
	char *buffer;
	size_t position;
	size_t length;
	spinlock_t lock;
};

static struct oplus_storage_log *storage_log;

static size_t oplus_storage_timestamp(char *buffer, size_t size)
{
	u64 timestamp = local_clock();
	unsigned long nanoseconds = do_div(timestamp, NSEC_PER_SEC);

	return scnprintf(buffer, size, "[%5lu.%06lu] ",
			 (unsigned long)timestamp, nanoseconds / NSEC_PER_USEC);
}

static void oplus_storage_append(const char *buffer, size_t count)
{
	struct oplus_storage_log *log = READ_ONCE(storage_log);
	char timestamp[64];
	unsigned long flags;
	size_t stamp_length;
	size_t total;

	if (!log || !log->buffer || !count)
		return;
	count = min_t(size_t, count, OPLUS_STORAGE_LINE_MAX);
	stamp_length = oplus_storage_timestamp(timestamp, sizeof(timestamp));
	total = stamp_length + count;
	if (total > OPLUS_STORAGE_LOG_SIZE)
		return;

	spin_lock_irqsave(&log->lock, flags);
	if (log->position + total > OPLUS_STORAGE_LOG_SIZE) {
		log->position = 0;
		log->length = 0;
	}
	memcpy(log->buffer + log->position, timestamp, stamp_length);
	log->position += stamp_length;
	memcpy(log->buffer + log->position, buffer, count);
	log->position += count;
	log->length = min_t(size_t, log->length + total,
				OPLUS_STORAGE_LOG_SIZE);
	spin_unlock_irqrestore(&log->lock, flags);
}

int pr_storage(const char *format, ...)
{
	char buffer[OPLUS_STORAGE_LINE_MAX];
	va_list arguments;
	int length;

	va_start(arguments, format);
	length = vscnprintf(buffer, sizeof(buffer), format, arguments);
	va_end(arguments);
	oplus_storage_append(buffer, length);
	return length;
}
EXPORT_SYMBOL_GPL(pr_storage);

static int oplus_storage_log_show(struct seq_file *m, void *unused)
{
	struct oplus_storage_log *log = READ_ONCE(storage_log);
	char *snapshot;
	unsigned long flags;
	size_t offset = 0;
	size_t length = 0;

	if (!log || !log->buffer)
		return 0;

	snapshot = vmalloc(OPLUS_STORAGE_LOG_SIZE);
	if (!snapshot)
		return -ENOMEM;

	spin_lock_irqsave(&log->lock, flags);
	length = min_t(size_t, log->length, OPLUS_STORAGE_LOG_SIZE);
	spin_unlock_irqrestore(&log->lock, flags);

	while (offset < length) {
		size_t chunk = min_t(size_t, PAGE_SIZE, length - offset);

		spin_lock_irqsave(&log->lock, flags);
		memcpy(snapshot + offset, log->buffer + offset, chunk);
		spin_unlock_irqrestore(&log->lock, flags);
		offset += chunk;
	}

	offset = 0;
	while (offset < length) {
		size_t chunk = min_t(size_t, PAGE_SIZE, length - offset);

		seq_write(m, snapshot + offset, chunk);
		if (seq_has_overflowed(m))
			break;
		offset += chunk;
	}
	vfree(snapshot);
	return 0;
}

static int oplus_storage_log_open(struct inode *inode, struct file *file)
{
	return single_open(file, oplus_storage_log_show, NULL);
}

static ssize_t oplus_storage_log_write(struct file *file,
		const char __user *buffer, size_t count, loff_t *ppos)
{
	struct oplus_storage_log *log = READ_ONCE(storage_log);
	char input[OPLUS_STORAGE_LINE_MAX + 1];
	unsigned long flags;
	size_t length;

	if (!log)
		return -ENODEV;
	if (!count)
		return 0;
	if (count > OPLUS_STORAGE_LINE_MAX)
		return -E2BIG;
	if (copy_from_user(input, buffer, count))
		return -EFAULT;
	input[count] = '\0';

	if (!strncmp(input, OPLUS_STORAGE_CLEAR,
		     strlen(OPLUS_STORAGE_CLEAR))) {
		length = strlen(OPLUS_STORAGE_HEADER);
		spin_lock_irqsave(&log->lock, flags);
		memcpy(log->buffer, OPLUS_STORAGE_HEADER, length);
		log->position = length;
		log->length = length;
		spin_unlock_irqrestore(&log->lock, flags);
		return count;
	}

	oplus_storage_append(input, count);
	return count;
}

static const struct file_operations oplus_storage_log_fops = {
	.owner		= THIS_MODULE,
	.open		= oplus_storage_log_open,
	.read		= seq_read,
	.write		= oplus_storage_log_write,
	.llseek		= seq_lseek,
	.release	= single_release,
};

static int __init oplus_storage_log_init(void)
{
	struct oplus_storage_log *log;
	struct proc_dir_entry *directory;
	size_t header_length = strlen(OPLUS_STORAGE_HEADER);

	log = kzalloc(sizeof(*log), GFP_KERNEL);
	if (!log)
		return -ENOMEM;
	log->buffer = vzalloc(OPLUS_STORAGE_LOG_SIZE);
	if (!log->buffer) {
		kfree(log);
		return -ENOMEM;
	}
	spin_lock_init(&log->lock);
	memcpy(log->buffer, OPLUS_STORAGE_HEADER, header_length);
	log->position = header_length;
	log->length = header_length;
	WRITE_ONCE(storage_log, log);

	directory = proc_mkdir("storage", NULL);
	if (!directory ||
	    !proc_create("buf_log", 0666, directory,
			 &oplus_storage_log_fops)) {
		WRITE_ONCE(storage_log, NULL);
		vfree(log->buffer);
		kfree(log);
		return -ENOMEM;
	}

	pr_info("registered /proc/storage/buf_log\n");
	return 0;
}
module_init(oplus_storage_log_init);

MODULE_DESCRIPTION("Oplus bounded storage diagnostic log ABI");
MODULE_LICENSE("GPL v2");
