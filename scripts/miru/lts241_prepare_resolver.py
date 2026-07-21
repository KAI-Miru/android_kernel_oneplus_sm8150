from pathlib import Path
from textwrap import dedent

resolver = Path('scripts/miru/lts241_semantic_resolve.py')
text = resolver.read_text()

for old, new in {
    '"failed to put link in Recovery\\n"':
        '"failed to put link in Recovery\\\\n"',
    '"failed to send transfer wakeup\\n"':
        '"failed to send transfer wakeup\\\\n"',
}.items():
    if old not in text:
        raise SystemExit(f'missing generated DWC3 string: {old!r}')
    text = text.replace(old, new, 1)


def insert_after(marker: str, addition: str) -> None:
    global text
    if marker not in text:
        raise SystemExit(f'missing resolver marker: {marker!r}')
    text = text.replace(marker, marker + dedent(addition).lstrip(), 1)


insert_after(
    "resolve('drivers/usb/dwc3/gadget.c',[dwc3_gadget])\n",
    r'''
    p=DST/'drivers/usb/dwc3/gadget.c'
    s=p.read_text()
    duplicate=''' + "'''" + r'''
    \tcase DWC3_LINK_STATE_U2:\t/* in HS, means Sleep (L1) */
    \tcase DWC3_LINK_STATE_U1:
    \tcase DWC3_LINK_STATE_RESUME:
    \t\tbreak;
    \tcase DWC3_LINK_STATE_U1:
    ''' + "'''" + r'''
    combined=''' + "'''" + r'''
    \tcase DWC3_LINK_STATE_U2:\t/* in HS, means Sleep (L1) */
    \tcase DWC3_LINK_STATE_RESUME:
    \t\tbreak;
    \tcase DWC3_LINK_STATE_U1:
    ''' + "'''" + r'''
    if s.count(duplicate)!=1:
        raise RuntimeError('DWC3 clean-merge U1 collision')
    s=s.replace(duplicate,combined,1)
    p.write_text(s)
    ''',
)

insert_after(
    "resolve('drivers/usb/gadget/function/f_fs.c',['theirs','theirs',ffs_ss,'theirs'])\n",
    r'''
    p=DST/'drivers/usb/gadget/function/f_fs.c'
    s=p.read_text()
    duplicate_speed=''' + "'''" + r'''
    \t\tcase USB_SPEED_SUPER_PLUS:
    \t\tcase USB_SPEED_SUPER:
    \t\tcase USB_SPEED_SUPER_PLUS:
    ''' + "'''" + r'''
    combined_speed=''' + "'''" + r'''
    \t\tcase USB_SPEED_SUPER_PLUS:
    \t\tcase USB_SPEED_SUPER:
    ''' + "'''" + r'''
    if s.count(duplicate_speed)!=1:
        raise RuntimeError('FunctionFS clean-merge speed collision')
    s=s.replace(duplicate_speed,combined_speed,1)
    declaration=''' + "'''" + r'''
    \t\tcontainer_of(f->fi, struct f_fs_opts, func_inst);
    \tstruct ffs_data *ffs_data;
    \tint ret;
    ''' + "'''" + r'''
    declaration_fixed=''' + "'''" + r'''
    \t\tcontainer_of(f->fi, struct f_fs_opts, func_inst);
    \tstruct ffs_data *ffs;
    \tint ret;
    ''' + "'''" + r'''
    if s.count(declaration)!=1:
        raise RuntimeError('FunctionFS bind declaration collision')
    s=s.replace(declaration,declaration_fixed,1)
    replacements={
        '\tffs_data = ffs_opts->dev->ffs_data;\n': '\tffs = ffs_opts->dev->ffs_data;\n',
        '\tfunc->ffs = ffs_data;\n': '\tfunc->ffs = ffs;\n',
    }
    for old,new in replacements.items():
        if s.count(old)!=1:
            raise RuntimeError('FunctionFS locked ffs lookup collision: '+repr(old))
        s=s.replace(old,new,1)
    p.write_text(s)
    ''',
)

insert_after(
    "resolve('fs/incfs/main.c',['theirs'])\n",
    r'''
    p=DST/'fs/incfs/main.c'
    s=p.read_text()
    feature=''' + "'''" + r'''static ssize_t mounter_context_for_backing_rw_show(struct kobject *kobj,
    \t\t\t  struct kobj_attribute *attr, char *buff)
    {
    \treturn snprintf(buff, PAGE_SIZE, "supported\\n");
    }

    static struct kobj_attribute mounter_context_for_backing_rw_attr =
    \t__ATTR_RO(mounter_context_for_backing_rw);

    ''' + "'''" + r'''
    if s.count(feature)!=2 or s.count(feature+feature)!=1:
        raise RuntimeError('IncFS duplicate mounter feature collision')
    s=s.replace(feature+feature,feature,1)
    p.write_text(s)
    ''',
)

old_skb = "resolve('net/core/skbuff.c',['both'])"
new_skb = dedent('''
    def skbuff_hunk(ours, theirs):
        if len(ours) < 3:
            raise RuntimeError('short downstream skbuff conflict hunk')
        return ours[:3] + theirs
    resolve('net/core/skbuff.c',[skbuff_hunk])
''').strip()
if text.count(old_skb) != 1:
    raise SystemExit('missing networking skb resolver')
text = text.replace(old_skb, new_skb, 1)

resolver.write_text(text)

transaction = Path('scripts/miru/lts241_targeted_integration.sh')
text = transaction.read_text()
old = '      install -D -m 0644 "${RESOLVE_ROOT}/${path}" "${KERNEL_WORKTREE}/${path}"'
new = '      mkdir -p "${KERNEL_WORKTREE}/$(dirname "${path}")"\n      cp "${RESOLVE_ROOT}/${path}" "${KERNEL_WORKTREE}/${path}"'
if old not in text:
    raise SystemExit('missing source installation line')
transaction.write_text(text.replace(old, new, 1))
