#!/usr/bin/env python3
"""Run the strict stage-340 resolver with the reviewed Android AIO adaptation.

The original resolver placed the new IOCB_AIO_RW guard after container_of(),
which both missed Miru's existing active-request check and retained unsafe
container conversion for non-AIO kiocbs. Patch the resolver source in memory so
its committed provenance remains inspectable while this correction is applied
strictly and reproducibly.
"""
from pathlib import Path

resolver = Path(__file__).with_name("resolve_stage_340.py")
source = resolver.read_text()
old = '''# AIO: cancellation is valid only for AIO read/write requests and submitted
# requests carry the discriminator used by the cancellation path.
replace(
    "fs/aio.c",
    """\\tstruct kioctx *ctx = req->ki_ctx;
\\tunsigned long flags;

\\tspin_lock_irqsave(&ctx->ctx_lock, flags);
""",
    """\\tstruct kioctx *ctx = req->ki_ctx;
\\tunsigned long flags;

\\t/* Ignore non-AIO and non-read/write kiocbs. */
\\tif (!(iocb->ki_flags & IOCB_AIO_RW))
\\t\\treturn;

\\tspin_lock_irqsave(&ctx->ctx_lock, flags);
""",
)
'''
new = '''# AIO: cancellation is valid only for AIO read/write requests. Guard before
# container_of() so a non-AIO kiocb is never interpreted as struct aio_kiocb,
# while retaining Miru's active-request list sanity check.
replace(
    "fs/aio.c",
    """void kiocb_set_cancel_fn(struct kiocb *iocb, kiocb_cancel_fn *cancel)
{
\\tstruct aio_kiocb *req = container_of(iocb, struct aio_kiocb, common);
\\tstruct kioctx *ctx = req->ki_ctx;
\\tunsigned long flags;

\\tif (WARN_ON_ONCE(!list_empty(&req->ki_list)))
\\t\\treturn;
""",
    """void kiocb_set_cancel_fn(struct kiocb *iocb, kiocb_cancel_fn *cancel)
{
\\tstruct aio_kiocb *req;
\\tstruct kioctx *ctx;
\\tunsigned long flags;

\\t/*
\\t * Ignore kiocbs that did not originate from AIO read/write submission.
\\t * The guard must precede container_of() for non-AIO callers.
\\t */
\\tif (!(iocb->ki_flags & IOCB_AIO_RW))
\\t\\treturn;

\\treq = container_of(iocb, struct aio_kiocb, common);
\\tctx = req->ki_ctx;

\\tif (WARN_ON_ONCE(!list_empty(&req->ki_list)))
\\t\\treturn;
""",
)
'''
if source.count(old) != 1:
    raise SystemExit("stage-340 resolver AIO block missing or duplicated")
patched = source.replace(old, new, 1)
exec(compile(patched, str(resolver), "exec"), {"__name__": "__main__", "__file__": str(resolver)})
