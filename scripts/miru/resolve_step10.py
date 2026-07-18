#!/usr/bin/env python3

from __future__ import annotations

import pathlib
import subprocess

COMPRESS = pathlib.Path("sound/core/compress_offload.c")
RAWMIDI = pathlib.Path("sound/core/rawmidi.c")
COMPRESS_HEADER = pathlib.Path("include/sound/compress_driver.h")
RAWMIDI_HEADER = pathlib.Path("include/sound/rawmidi.h")
LEDGER = pathlib.Path("Documentation/miru/lts-4.14.190-conflicts.md")

EXPECTED_HASHES = {
    COMPRESS: "77c7e91112f983062984b16f0c3e6f82a243f1ed",
    RAWMIDI: "22faa6f8df86f1b083565883d84d1a8f1cb52b85",
    COMPRESS_HEADER: "ca0fa6193353cf1d6432bd90e273ccc94036973c",
    RAWMIDI_HEADER: "17f2f6ed8defdc6570d4424403b6ff20f8be8b89",
    LEDGER: "39b632b9bfd056c6684d3c857a5254b178b13a86",
}

RESOLVED_HASHES = {
    COMPRESS: "9296eb6c4ce8ae96ac49a2b4d77cc05ee1d047f4",
    RAWMIDI: "7b841a23481a86dc28c91dc39870fd43d1e50d29",
}


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], text=True)


def verify_blob(path: pathlib.Path, expected: str) -> None:
    actual = git("hash-object", str(path)).strip()
    if actual != expected:
        raise SystemExit(f"{path}: expected blob {expected}, found {actual}")


def replace_exact(text: str, old: str, new: str, count: int = 1) -> str:
    actual = text.count(old)
    if actual != count:
        raise SystemExit(
            f"replacement guard failed: expected {count}, found {actual}: {old!r}"
        )
    return text.replace(old, new, count)


def replace_function(text: str, start_marker: str, end_marker: str,
                     replacement: str) -> str:
    if text.count(start_marker) != 1:
        raise SystemExit(f"function start marker missing or duplicated: {start_marker}")
    start = text.index(start_marker)
    end = text.index(end_marker, start)
    return text[:start] + replacement + text[end:]


def resolve_compress() -> None:
    text = COMPRESS.read_text()
    text = replace_exact(
        text,
        """\t\tstream->runtime->state = SNDRV_PCM_STATE_SETUP;
\t\twake_up(&stream->runtime->sleep);
\t\tstream->runtime->total_bytes_available = 0;
""",
        """\t\tstream->runtime->state = SNDRV_PCM_STATE_SETUP;
\t\twake_up(&stream->runtime->sleep);
\t\t/* clear flags and stop any drain wait */
\t\tstream->partial_drain = false;
\t\tstream->metadata_set = false;
\t\tstream->runtime->total_bytes_available = 0;
""",
    )
    text = replace_exact(
        text,
        "\tretval = stream->ops->trigger(stream, SND_COMPR_TRIGGER_PARTIAL_DRAIN);\n",
        "\tstream->partial_drain = true;\n"
        "\tretval = stream->ops->trigger(stream, SND_COMPR_TRIGGER_PARTIAL_DRAIN);\n",
    )

    required = (
        "stream->partial_drain = false;",
        "stream->metadata_set = false;",
        "stream->partial_drain = true;",
        "snd_compr_set_next_track_param",
        "snd_compress_simple_ioctls",
        "void snd_compress_free(struct snd_card *card, struct snd_compr *compr)",
        "EXPORT_SYMBOL(snd_compress_free);",
        "queue_delayed_work(system_power_efficient_wq, &stream->error_work, 0);",
    )
    for token in required:
        if token not in text:
            raise SystemExit(f"compressed offload lost required behavior: {token}")

    COMPRESS.write_text(text)
    verify_blob(COMPRESS, RESOLVED_HASHES[COMPRESS])


def resolve_rawmidi() -> None:
    text = RAWMIDI.read_text()

    text = replace_exact(
        text,
        """static void snd_rawmidi_input_event_work(struct work_struct *work)
{
\tstruct snd_rawmidi_runtime *runtime =
\t\tcontainer_of(work, struct snd_rawmidi_runtime, event_work);
\tif (runtime->event)
\t\truntime->event(runtime->substream);
}

static int snd_rawmidi_runtime_create""",
        """static void snd_rawmidi_input_event_work(struct work_struct *work)
{
\tstruct snd_rawmidi_runtime *runtime =
\t\tcontainer_of(work, struct snd_rawmidi_runtime, event_work);
\tif (runtime->event)
\t\truntime->event(runtime->substream);
}

/* buffer refcount management: call with runtime->lock held */
static inline void snd_rawmidi_buffer_ref(struct snd_rawmidi_runtime *runtime)
{
\truntime->buffer_ref++;
}

static inline void snd_rawmidi_buffer_unref(struct snd_rawmidi_runtime *runtime)
{
\truntime->buffer_ref--;
}

static int snd_rawmidi_runtime_create""",
    )

    text = replace_exact(
        text,
        "runtime->buffer = kmalloc(runtime->buffer_size, GFP_KERNEL)",
        "runtime->buffer = kzalloc(runtime->buffer_size, GFP_KERNEL)",
    )

    output_params = """int snd_rawmidi_output_params(struct snd_rawmidi_substream *substream,
\t\t\t      struct snd_rawmidi_params * params)
{
\tchar *newbuf;
\tchar *oldbuf;
\tstruct snd_rawmidi_runtime *runtime = substream->runtime;
\tunsigned long flags;

\tif (substream->append && substream->use_count > 1)
\t\treturn -EBUSY;
\tsnd_rawmidi_drain_output(substream);
\tif (params->buffer_size < 32 || params->buffer_size > 1024L * 1024L) {
\t\treturn -EINVAL;
\t}
\tif (params->avail_min < 1 || params->avail_min > params->buffer_size) {
\t\treturn -EINVAL;
\t}
\tif (params->buffer_size != runtime->buffer_size) {
\t\tmutex_lock(&runtime->realloc_mutex);
\t\tnewbuf = kzalloc(params->buffer_size, GFP_KERNEL);
\t\tif (!newbuf) {
\t\t\tmutex_unlock(&runtime->realloc_mutex);
\t\t\treturn -ENOMEM;
\t\t}
\t\tspin_lock_irqsave(&runtime->lock, flags);
\t\tif (runtime->buffer_ref) {
\t\t\tspin_unlock_irqrestore(&runtime->lock, flags);
\t\t\tkfree(newbuf);
\t\t\tmutex_unlock(&runtime->realloc_mutex);
\t\t\treturn -EBUSY;
\t\t}
\t\toldbuf = runtime->buffer;
\t\truntime->buffer = newbuf;
\t\truntime->buffer_size = params->buffer_size;
\t\truntime->appl_ptr = runtime->hw_ptr = 0;
\t\truntime->avail = runtime->buffer_size;
\t\tspin_unlock_irqrestore(&runtime->lock, flags);
\t\tkfree(oldbuf);
\t\tmutex_unlock(&runtime->realloc_mutex);
\t}
\truntime->avail_min = params->avail_min;
\tsubstream->active_sensing = !params->no_active_sensing;
\treturn 0;
}
EXPORT_SYMBOL(snd_rawmidi_output_params);

"""
    text = replace_function(
        text,
        "int snd_rawmidi_output_params(",
        "int snd_rawmidi_input_params(",
        output_params,
    )

    input_params = """int snd_rawmidi_input_params(struct snd_rawmidi_substream *substream,
\t\t\t     struct snd_rawmidi_params * params)
{
\tchar *newbuf;
\tchar *oldbuf;
\tstruct snd_rawmidi_runtime *runtime = substream->runtime;
\tunsigned long flags;

\tsnd_rawmidi_drain_input(substream);
\tif (params->buffer_size < 32 || params->buffer_size > 1024L * 1024L) {
\t\treturn -EINVAL;
\t}
\tif (params->avail_min < 1 || params->avail_min > params->buffer_size) {
\t\treturn -EINVAL;
\t}
\tif (params->buffer_size != runtime->buffer_size) {
\t\tmutex_lock(&runtime->realloc_mutex);
\t\tnewbuf = kzalloc(params->buffer_size, GFP_KERNEL);
\t\tif (!newbuf) {
\t\t\tmutex_unlock(&runtime->realloc_mutex);
\t\t\treturn -ENOMEM;
\t\t}
\t\tspin_lock_irqsave(&runtime->lock, flags);
\t\tif (runtime->buffer_ref) {
\t\t\tspin_unlock_irqrestore(&runtime->lock, flags);
\t\t\tkfree(newbuf);
\t\t\tmutex_unlock(&runtime->realloc_mutex);
\t\t\treturn -EBUSY;
\t\t}
\t\toldbuf = runtime->buffer;
\t\truntime->buffer = newbuf;
\t\truntime->buffer_size = params->buffer_size;
\t\truntime->appl_ptr = runtime->hw_ptr = 0;
\t\truntime->avail = 0;
\t\tspin_unlock_irqrestore(&runtime->lock, flags);
\t\tkfree(oldbuf);
\t\tmutex_unlock(&runtime->realloc_mutex);
\t}
\truntime->avail_min = params->avail_min;
\treturn 0;
}
EXPORT_SYMBOL(snd_rawmidi_input_params);

"""
    text = replace_function(
        text,
        "int snd_rawmidi_input_params(",
        "static int snd_rawmidi_output_status(",
        input_params,
    )

    read_function = """static long snd_rawmidi_kernel_read1(struct snd_rawmidi_substream *substream,
\t\t\t\t     unsigned char __user *userbuf,
\t\t\t\t     unsigned char *kernelbuf, long count)
{
\tunsigned long flags;
\tlong result = 0, count1;
\tstruct snd_rawmidi_runtime *runtime = substream->runtime;
\tunsigned long appl_ptr;
\tint err = 0;

\tif (userbuf)
\t\tmutex_lock(&runtime->realloc_mutex);
\tspin_lock_irqsave(&runtime->lock, flags);
\tsnd_rawmidi_buffer_ref(runtime);
\twhile (count > 0 && runtime->avail) {
\t\tcount1 = runtime->buffer_size - runtime->appl_ptr;
\t\tif (count1 > count)
\t\t\tcount1 = count;
\t\tif (count1 > (int)runtime->avail)
\t\t\tcount1 = runtime->avail;

\t\t/* update runtime->appl_ptr before unlocking for userbuf */
\t\tappl_ptr = runtime->appl_ptr;
\t\truntime->appl_ptr += count1;
\t\truntime->appl_ptr %= runtime->buffer_size;
\t\truntime->avail -= count1;

\t\tif (kernelbuf)
\t\t\tmemcpy(kernelbuf + result, runtime->buffer + appl_ptr, count1);
\t\tif (userbuf) {
\t\t\tspin_unlock_irqrestore(&runtime->lock, flags);
\t\t\tif (copy_to_user(userbuf + result,
\t\t\t\t\t runtime->buffer + appl_ptr, count1))
\t\t\t\terr = -EFAULT;
\t\t\tspin_lock_irqsave(&runtime->lock, flags);
\t\t\tif (err)
\t\t\t\tgoto out;
\t\t}
\t\tresult += count1;
\t\tcount -= count1;
\t}
out:
\tsnd_rawmidi_buffer_unref(runtime);
\tspin_unlock_irqrestore(&runtime->lock, flags);
\tif (userbuf)
\t\tmutex_unlock(&runtime->realloc_mutex);
\treturn result > 0 ? result : err;
}

"""
    text = replace_function(
        text,
        "static long snd_rawmidi_kernel_read1(",
        "long snd_rawmidi_kernel_read(",
        read_function,
    )

    text = replace_exact(
        text,
        """\tif (substream->append) {
\t\tif ((long)runtime->avail < count) {
\t\t\tspin_unlock_irqrestore(&runtime->lock, flags);
\t\t\tif (userbuf)
\t\t\t\tmutex_unlock(&runtime->realloc_mutex);
\t\t\treturn -EAGAIN;
\t\t}
\t}
\twhile (count > 0 && runtime->avail > 0) {
""",
        """\tif (substream->append) {
\t\tif ((long)runtime->avail < count) {
\t\t\tspin_unlock_irqrestore(&runtime->lock, flags);
\t\t\tif (userbuf)
\t\t\t\tmutex_unlock(&runtime->realloc_mutex);
\t\t\treturn -EAGAIN;
\t\t}
\t}
\tsnd_rawmidi_buffer_ref(runtime);
\twhile (count > 0 && runtime->avail > 0) {
""",
    )
    text = replace_exact(
        text,
        """\tcount1 = runtime->avail < runtime->buffer_size;
\tspin_unlock_irqrestore(&runtime->lock, flags);
""",
        """\tcount1 = runtime->avail < runtime->buffer_size;
\tsnd_rawmidi_buffer_unref(runtime);
\tspin_unlock_irqrestore(&runtime->lock, flags);
""",
    )

    required = (
        "static inline void snd_rawmidi_buffer_ref",
        "static inline void snd_rawmidi_buffer_unref",
        "runtime->buffer = kzalloc(runtime->buffer_size, GFP_KERNEL)",
        "newbuf = kzalloc(params->buffer_size, GFP_KERNEL);",
        "if (runtime->buffer_ref) {",
        "spin_unlock_irqrestore(&runtime->lock, flags);",
        "mutex_unlock(&runtime->realloc_mutex);",
        "snd_rawmidi_buffer_ref(runtime);",
        "snd_rawmidi_buffer_unref(runtime);",
    )
    for token in required:
        if token not in text:
            raise SystemExit(f"raw-MIDI lost required behavior: {token}")

    forbidden = (
        "newbuf = __krealloc(runtime->buffer",
        "spin_unlock_irq(&runtime->lock);",
        "runtime->buffer = kmalloc(runtime->buffer_size, GFP_KERNEL)",
    )
    for token in forbidden:
        if token in text:
            raise SystemExit(f"unsafe raw-MIDI merge pattern remains: {token}")

    if text.count("snd_rawmidi_buffer_ref(runtime);") != 2:
        raise SystemExit("expected exactly two raw-MIDI buffer references")
    if text.count("snd_rawmidi_buffer_unref(runtime);") != 2:
        raise SystemExit("expected exactly two raw-MIDI buffer unreferences")

    RAWMIDI.write_text(text)
    verify_blob(RAWMIDI, RESOLVED_HASHES[RAWMIDI])


def validate_headers() -> None:
    verify_blob(COMPRESS_HEADER, EXPECTED_HASHES[COMPRESS_HEADER])
    verify_blob(RAWMIDI_HEADER, EXPECTED_HASHES[RAWMIDI_HEADER])

    compress_header = COMPRESS_HEADER.read_text()
    for token in (
        "bool metadata_set;",
        "bool next_track;",
        "bool partial_drain;",
        "static inline void snd_compr_drain_notify",
        "stream->runtime->state = SNDRV_PCM_STATE_RUNNING;",
    ):
        if token not in compress_header:
            raise SystemExit(f"compressed-audio header dependency missing: {token}")

    rawmidi_header = RAWMIDI_HEADER.read_text()
    for token in (
        "int buffer_ref;",
        "struct mutex realloc_mutex;",
    ):
        if token not in rawmidi_header:
            raise SystemExit(f"raw-MIDI header dependency missing: {token}")


def update_ledger() -> None:
    verify_blob(LEDGER, EXPECTED_HASHES[LEDGER])
    text = LEDGER.read_text()
    replacements = {
        "- Resolved conflicts: 26": "- Resolved conflicts: 28",
        "- Remaining conflicts: 2": "- Remaining conflicts: 0",
    }
    for old, new in replacements.items():
        text = replace_exact(text, old, new)

    old_remaining = """## Remaining deferred conflicts

```text
sound/core/compress_offload.c
sound/core/rawmidi.c
```
"""
    section = """## Resolved in Step 10

The ALSA compressed-offload and raw-MIDI conflicts were resolved as one audio
core compatibility unit:

```text
sound/core/compress_offload.c
sound/core/rawmidi.c
```

`compress_offload.c` applies stable commit
`0a117d00e86fe6ec856e72548e405169ab9dc78d` (upstream
`f79a732a8325dfbd570d87f1435019d7e5501c6d`). Partial drains are marked before
the DSP trigger so `snd_compr_drain_notify()` returns the stream to RUNNING,
and STOP clears both partial-drain and metadata state before waking waiters.
The resulting file exactly matches the Lineage SM8150 4.14.190 merge while
preserving H.40's next-track parameter ioctl, simple-ioctl split, error work and
exported `snd_compress_free()` interface.

`rawmidi.c` applies stable commits `8645ac3684a70e4e8a21c7c407c07a1a4316beec`
(upstream `c1f6e3c818dd734c30f6a7eeebf232ba2cf3181d`) and
`e8e3fcbc66f608d38a72fc716ff45e31b7f3d123` (upstream
`5a7b44a8df822e0667fc76ed7130252523993bda`). Runtime buffer accesses now carry
a spinlock-protected reference while user copies temporarily drop the lock, and
new buffers are zero-initialized.

The raw-MIDI resize resolution is intentionally stricter than the mechanical
Lineage merge. H.40's `realloc_mutex` is preserved, but resize allocates a
separate zeroed buffer before taking the runtime spinlock. If a buffer user is
active, the new allocation is freed, IRQ flags and the mutex are restored, and
`-EBUSY` is returned. This avoids calling downstream `__krealloc()` on a live
buffer before the stable busy check and avoids the incomplete early-return
cleanup present in the mechanical merge. Successful resize atomically swaps the
buffer and resets stream pointers only after drain has completed.

Resolution commit:

```text
lts: resolve ALSA compress and rawmidi conflicts
```

## Remaining deferred conflicts

None. All 28 merge conflicts now have explicit source-level resolutions. The
branch remains unsuitable for release until the full build, symbol/ABI audit and
device validation are complete.
"""
    text = replace_exact(text, old_remaining, section)
    LEDGER.write_text(text)


def main() -> None:
    for path, expected in EXPECTED_HASHES.items():
        verify_blob(path, expected)
    resolve_compress()
    resolve_rawmidi()
    validate_headers()
    update_ledger()
    print("Step 10 guarded ALSA resolution completed.")


if __name__ == "__main__":
    main()
