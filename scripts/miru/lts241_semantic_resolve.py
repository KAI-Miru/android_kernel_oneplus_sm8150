from pathlib import Path
import shutil, sys, re
import os
SRC=Path(os.environ['MERGE_ROOT'])
DST=Path(os.environ['RESOLVE_ROOT'])
if DST.exists(): shutil.rmtree(DST)
shutil.copytree(SRC,DST)

def resolve(path, decisions):
    p=DST/path
    lines=p.read_text(errors='surrogateescape').splitlines(keepends=True)
    out=[]; i=0; idx=0
    while i < len(lines):
        if not lines[i].startswith('<<<<<<< '):
            out.append(lines[i]); i+=1; continue
        idx+=1; i+=1; ours=[]
        while i<len(lines) and not lines[i].startswith('======='):
            ours.append(lines[i]); i+=1
        if i>=len(lines): raise RuntimeError(f'{path} hunk {idx}: no separator')
        i+=1; theirs=[]
        while i<len(lines) and not lines[i].startswith('>>>>>>> '):
            theirs.append(lines[i]); i+=1
        if i>=len(lines): raise RuntimeError(f'{path} hunk {idx}: no end')
        i+=1
        d=decisions[idx-1]
        if d=='ours': chosen=ours
        elif d=='theirs': chosen=theirs
        elif d=='both': chosen=ours+theirs
        elif callable(d): chosen=d(ours,theirs)
        else: chosen=[d] if isinstance(d,str) else list(d)
        out.extend(chosen)
    if idx != len(decisions): raise RuntimeError(f'{path}: got {idx} hunks, expected {len(decisions)}')
    p.write_text(''.join(out), errors='surrogateescape')

resolve('arch/x86/Makefile',['both'])
resolve('drivers/block/zram/zram_drv.c', [lambda o,t: t + o[1:]])

def dmabuf_h1(o,t): return o

def dmabuf_h2(o,t):
    return [
        '\tmutex_lock(&db_list.lock);\n',
        '\tlist_del(&dmabuf->list_node);\n',
        '\tmutex_unlock(&db_list.lock);\n',
        '\n',
        '\tkfree(dmabuf->name);\n',
        '\tkfree(dmabuf->buf_name);\n',
        '\tkfree(dmabuf);\n',
    ]

def dmabuf_h3(o,t): return []
resolve('drivers/dma-buf/dma-buf.c',[dmabuf_h1,dmabuf_h2,dmabuf_h3])

def msm(o,t):
    return [
        '\tstruct drm_device *ddev = platform_get_drvdata(pdev);\n',
        '\tstruct msm_drm_private *priv = ddev ? ddev->dev_private : NULL;\n',
        '\n',
        '\tif (!priv || !priv->kms)\n',
        '\t\treturn;\n',
        '\n',
        '\tmsm_lastclose(ddev);\n',
    ]
resolve('drivers/gpu/drm/msm/msm_drv.c',[msm])

def mmc_core(o,t):
    return [
        '\t\tgoto power_cycle;\n',
        '\n',
        '\tif (!mmc_host_is_spi(host) && (cmd.resp[0] & R1_ERROR)) {\n',
        '\t\terr = -EIO;\n',
        '\t\tgoto power_cycle;\n',
        '\t}\n',
    ]
resolve('drivers/mmc/core/core.c',[mmc_core])
p=DST/'drivers/mmc/core/core.c'; s=p.read_text(); dup='''
	if (!mmc_host_is_spi(host) && (cmd.resp[0] & R1_ERROR)) {
		err = -EIO;
		goto err_command;
	}
'''
if s.count(dup)!=1: raise RuntimeError('mmc duplicate R1 block')
s=s.replace(dup,'\n',1)
label='''
err_command:
	mmc_host_clk_release(host);'''
if s.count(label)!=1: raise RuntimeError('mmc obsolete cleanup label')
s=s.replace(label,'\n\tmmc_host_clk_release(host);',1)
p.write_text(s)
resolve('drivers/mmc/core/mmc.c',['both'])

def ufs2(o,t):
    return [
        '\tufshcd_print_cmd_log(hba);\n',
        '\tlun = ufshcd_scsi_to_upiu_lun(cmd->device->lun);\n',
        '\terr = ufshcd_issue_tm_cmd(hba, lun, 0, UFS_LOGICAL_RESET, &resp);\n',
    ]
resolve('drivers/scsi/ufs/ufshcd.c',['theirs',ufs2])

def smp(o,t): return t + o[1:]
resolve('drivers/soc/qcom/smp2p.c',[smp])
resolve('drivers/tty/tty_jobctrl.c',['theirs'])
resolve('drivers/usb/core/hub.c',['theirs'])
p=DST/'drivers/usb/core/hub.c'; s=p.read_text(); old='\t\t/* TRSMRCY = 10 msec */\n\t\tmsleep(10);'; new='\t\t/* TRSMRCY = 10 msec */\n\t\tusleep_range(10000, 10500);'
if old not in s: raise RuntimeError('hub final TRSMRCY')
s=s.replace(old,new,1); p.write_text(s)

def dwc3_core(o,t):
    return [
        '\tdwc3_gadget_exit(dwc);\n',
        '\tdwc3_debugfs_exit(dwc);\n',
        '\tpm_runtime_allow(&pdev->dev);\n',
    ]
resolve('drivers/usb/dwc3/core.c',[dwc3_core])

def dwc3_gadget(o,t):
    return [
        '\tif (DWC3_DEPCMD_CMD(cmd) == DWC3_DEPCMD_STARTTRANSFER) {\n',
        '\t\tint link_state;\n',
        '\n',
        '\t\tlink_state = dwc3_gadget_get_link_state(dwc);\n',
        '\t\tif (link_state == DWC3_LINK_STATE_U1 ||\n',
        '\t\t    link_state == DWC3_LINK_STATE_U2 ||\n',
        '\t\t    link_state == DWC3_LINK_STATE_U3) {\n',
        '\t\t\tret = dwc3_gadget_wakeup_for_transfer(dwc);\n',
        '\t\t\tdev_WARN_ONCE(dwc->dev, ret,\n',
        '\t\t\t\t      "wakeup failed --> %d\\n", ret);\n',
        '\t\t}\n',
        '\t}\n',
        '\n',
    ]
resolve('drivers/usb/dwc3/gadget.c',[dwc3_gadget])
p=DST/'drivers/usb/dwc3/gadget.c'; s=p.read_text(); marker='''/**
 * dwc3_send_gadget_ep_cmd - issue an endpoint command
'''
helper='''static int dwc3_gadget_wakeup_for_transfer(struct dwc3 *dwc)
{
	int retries = 20000;
	int ret;
	u32 reg;

	ret = dwc3_gadget_set_link_state(dwc, DWC3_LINK_STATE_RECOV);
	if (ret < 0) {
		dev_err(dwc->dev, "failed to put link in Recovery\n");
		return ret;
	}

	if (dwc->revision < DWC3_REVISION_194A) {
		reg = dwc3_readl(dwc->regs, DWC3_DCTL);
		reg &= ~DWC3_DCTL_ULSTCHNGREQ_MASK;
		dwc3_writel(dwc->regs, DWC3_DCTL, reg);
	}

	while (retries--) {
		reg = dwc3_readl(dwc->regs, DWC3_DSTS);
		if (DWC3_DSTS_USBLNKST(reg) == DWC3_LINK_STATE_U0)
			return 0;
	}

	dev_err(dwc->dev, "failed to send transfer wakeup\n");
	return -EINVAL;
}

'''
if marker not in s: raise RuntimeError('dwc3 send marker')
s=s.replace(marker,helper+marker,1); p.write_text(s)
resolve('drivers/usb/gadget/configfs.c',['theirs','theirs',lambda o,t: t])
p=DST/'drivers/usb/gadget/configfs.c'; s=p.read_text()
if '\tstrcpy(str, s);' not in s: raise RuntimeError('configfs strcpy')
s=s.replace('\tstrcpy(str, s);','\tstrlcpy(str, s, USB_MAX_STRING_WITH_NULL_LEN);',1); p.write_text(s)
resolve('drivers/usb/gadget/function/f_accessory.c',['theirs','theirs','theirs','theirs','theirs','theirs'])

def ffs_ss(o,t):
    return [
        '\t\tfunc->function.ss_descriptors = func->function.ssp_descriptors =\n',
        '\t\t\tvla_ptr(vlabuf, d, ss_descs);\n',
        '\t\tss_len = ffs_do_descs(ffs, ffs->ss_descs_count,\n',
    ]
resolve('drivers/usb/gadget/function/f_fs.c',['theirs','theirs',ffs_ss,'theirs'])
resolve('drivers/usb/gadget/function/f_uac1.c',['both'])

def uac2(o,t):
    return [x.replace('USB_ENDPOINT_SYNC_ASYNC','USB_ENDPOINT_SYNC_SYNC') for x in t]
resolve('drivers/usb/gadget/function/f_uac2.c',[uac2,uac2,uac2,uac2])
resolve('fs/incfs/data_mgmt.c',['theirs'])
resolve('fs/incfs/format.c',['theirs','theirs','ours','ours','ours','ours'])
resolve('fs/incfs/main.c',['theirs'])
(DST/'fs/incfs/pseudo_files.c').unlink()
resolve('fs/incfs/vfs.c',['ours'])
resolve('include/linux/usb/usbnet.h',['both'])
resolve('kernel/bpf/helpers.c',['theirs'])
resolve('kernel/cgroup/cgroup.c',['ours'])
resolve('kernel/cpu.c',['ours'])
resolve('kernel/futex.c',['theirs'])
resolve('kernel/sched/fair.c',[[
    '\t\tif (cpu_isolated(cpu))\n',
    '\t\t\tcontinue;\n',
]])
resolve('net/core/skbuff.c',['both'])

def qrtr(o,t): return t + o
resolve('net/qrtr/qrtr.c',[qrtr])
resolve('net/sctp/sm_make_chunk.c',['theirs','theirs'])
resolve('security/selinux/avc.c',['theirs','theirs'])

bad=[]
for p in DST.rglob('*'):
    if p.is_file():
        text=p.read_text(errors='ignore')
        if '<<<<<<< ' in text or '\n=======\n' in text or '>>>>>>> ' in text:
            bad.append(str(p.relative_to(DST)))
if bad: raise RuntimeError(f'unresolved markers: {bad}')
print('semantic conflict snapshots resolved')
