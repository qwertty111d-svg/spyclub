#!/usr/bin/env python3
"""Lossless Roblox binary place source extraction and patching.

Preserves unmodified binary chunks byte-for-byte, including unknown properties.
Only selected Source PROP chunks are rebuilt; optional new script groups and parent
links are appended. Supports Roblox's Zstandard and legacy LZ4 compressed chunks.
"""
from __future__ import annotations
import argparse
from collections import Counter
from dataclasses import dataclass
import hashlib
import json
from pathlib import Path
import struct
from urllib.parse import quote, unquote
import zstandard

MAGIC = b'<roblox!\x89\xff\r\n\x1a\n'
SCRIPT_CLASSES = {'Script', 'LocalScript', 'ModuleScript'}

def file_component(name):
    encoded=quote(name,safe=' -_.')
    if encoded in ('.','..'):encoded=encoded.replace('.','%2E')
    if not encoded:encoded='%00'
    return encoded

def instance_name(component):
    return '' if component=='%00' else unquote(component)

def u32(data, offset=0): return struct.unpack_from('<I', data, offset)[0]
def read_string(data, offset):
    size = u32(data, offset); offset += 4
    return data[offset:offset+size], offset+size

def string(data):
    if isinstance(data, str): data = data.encode('utf-8')
    return struct.pack('<I',len(data))+data

def decode_interleaved(data, count, signed=False):
    assert len(data) == count*4
    values = [int.from_bytes(bytes(data[i+j*count] for j in range(4)), 'big') for i in range(count)]
    return [(v >> 1) ^ -(v & 1) for v in values] if signed else values

def encode_interleaved(values, signed=False):
    encoded = [(((v << 1) ^ (v >> 31)) & 0xffffffff if signed else v).to_bytes(4,'big') for v in values]
    return bytes(b[i] for i in range(4) for b in encoded)

def decode_refs(data, count):
    result=[]; total=0
    for value in decode_interleaved(data,count,True):
        total+=value; result.append(total)
    return result

def encode_refs(values):
    previous=0; deltas=[]
    for value in values:
        deltas.append(value-previous);previous=value
    return encode_interleaved(deltas,True)

def lz4_decompress(data,expected):
    """Decode a raw LZ4 block; no native dependency is required."""
    output=bytearray(); i=0
    while i<len(data):
        token=data[i];i+=1; length=token>>4
        if length==15:
            while True:
                extra=data[i]; i+=1; length+=extra
                if extra!=255: break
        output.extend(data[i:i+length]);i+=length
        if i==len(data): break
        offset=int.from_bytes(data[i:i+2],'little');i+=2
        if offset<=0 or offset>len(output): raise ValueError('Invalid LZ4 match offset')
        length=(token&15)+4
        if (token&15)==15:
            while True:
                extra=data[i];i+=1;length+=extra
                if extra!=255: break
        for _ in range(length): output.append(output[-offset])
    if len(output)!=expected: raise ValueError('LZ4 decompressed size mismatch')
    return bytes(output)

@dataclass
class Chunk:
    tag: bytes
    data: bytes
    raw: bytes

class Place:
    def __init__(self,path):
        self.path=Path(path); self.binary=self.path.read_bytes()
        if self.binary[:14]!=MAGIC or len(self.binary)<32: raise ValueError('Not a Roblox binary place')
        self.header=self.binary[:32]; self.chunks=[]; self.groups={};self.instances={};self.properties={}
        offset=32
        while offset<len(self.binary):
            tag,compressed,expanded,reserved=struct.unpack_from('<4sIII',self.binary,offset)
            size=compressed or expanded; raw=self.binary[offset:offset+16+size]; payload=raw[16:]
            if compressed:
                payload=(zstandard.ZstdDecompressor().decompress(payload,max_output_size=expanded)
                         if payload.startswith(b'\x28\xb5\x2f\xfd') else lz4_decompress(payload,expanded))
            if len(payload)!=expanded: raise ValueError(f'Chunk {tag!r} length mismatch')
            self.chunks.append(Chunk(tag,payload,raw));offset+=len(raw)
            if tag==b'END\x00': break
        self.trailing=self.binary[offset:]
        for ci,chunk in enumerate(self.chunks):
            data=chunk.data
            if chunk.tag==b'INST':
                group_id=u32(data); cls,offset=read_string(data,4); service=data[offset]; count=u32(data,offset+1);offset+=5
                refs=decode_refs(data[offset:offset+count*4],count)
                self.groups[group_id]={'class':cls.decode(),'refs':refs,'service':bool(service),'chunk':ci}
                for ref in refs:self.instances[ref]={'ref':ref,'class':cls.decode(),'name':cls.decode(),'parent':-1,'group':group_id,'properties':{}}
        for ci,chunk in enumerate(self.chunks):
            data=chunk.data
            if chunk.tag==b'PROP':
                group_id=u32(data); name,offset=read_string(data,4);name=name.decode(); kind=data[offset];offset+=1
                group=self.groups[group_id];refs=group['refs'];body=data[offset:]
                values=self.decode_values(kind,body,len(refs))
                self.properties[(group_id,name)]={'chunk':ci,'type':kind,'values':values,'body':body}
                if values is not None:
                    for ref,value in zip(refs,values):
                        inst=self.instances[ref]
                        if name=='Name': inst['name']=value.decode('utf-8','surrogateescape')
                        elif name=='Source':inst['source']=value
                        else:inst['properties'][name]=value
            elif chunk.tag==b'PRNT':
                version=data[0];count=u32(data,1)
                if version!=0: raise ValueError(f'Unknown parent chunk version {version}')
                refs=decode_refs(data[5:5+count*4],count);parents=decode_refs(data[5+count*4:],count)
                self.parent_chunk=ci
                for ref,parent in zip(refs,parents):self.instances[ref]['parent']=parent
        if len(self.groups)!=u32(self.header,16) or len(self.instances)!=u32(self.header,20):
            raise ValueError('Header group/instance counts do not match decoded tree')
        for ref,inst in self.instances.items(): inst['path']=self.instance_path(ref)

    @staticmethod
    def decode_values(kind,body,count):
        if kind==1:
            values=[];offset=0
            for _ in range(count):value,offset=read_string(body,offset);values.append(value)
            if offset!=len(body):raise ValueError('Trailing string PROP data')
            return values
        if kind==2: return [bool(v) for v in body]
        if kind==3: return decode_interleaved(body,count,True)
        if kind==4:
            return [struct.unpack('>f',((v>>1)|((v&1)<<31)).to_bytes(4,'big'))[0] for v in decode_interleaved(body,count)]
        if kind==5:return list(struct.unpack('<'+'d'*count,body))
        if kind in (11,18,28):return decode_interleaved(body,count)
        if kind==19:return decode_refs(body,count)
        if kind in (12,13,14):
            dimensions=2 if kind==13 else 3
            if len(body)!=count*dimensions*4:return None
            channels=[Place.decode_values(4,body[j*count*4:(j+1)*count*4],count) for j in range(dimensions)]
            return [list(v) for v in zip(*channels)]
        if kind==16:
            offset=0;rotations=[]
            for _ in range(count):
                special=body[offset];offset+=1
                rotation={'special':special}
                if special==0:
                    rotation={'matrix':list(struct.unpack_from('<9f',body,offset))};offset+=36
                rotations.append(rotation)
            positions=Place.decode_values(14,body[offset:],count)
            return [dict(rotation,position=position) for rotation,position in zip(rotations,positions)]
        if kind==26:
            return [[body[i+j*count] for j in range(3)] for i in range(count)]
        return None

    def instance_path(self,ref):
        names=[];visited=set()
        while ref!=-1:
            if ref in visited:raise ValueError('Parent cycle')
            visited.add(ref);inst=self.instances[ref];names.append(inst['name']);ref=inst['parent']
        return '/'.join(reversed(names))

    def file_components(self,ref):
        names=[]
        while ref!=-1:
            inst=self.instances[ref];names.append(file_component(inst['name']));ref=inst['parent']
        return tuple(reversed(names))

    def metadata(self):
        def clean(value):
            if isinstance(value,bytes):
                try:return value.decode('utf-8')
                except UnicodeDecodeError:return {'hex':value.hex()}
            if isinstance(value,list):return [clean(v) for v in value]
            return value
        return [{'ref':inst['ref'],'class':inst['class'],'name':inst['name'],'parent':inst['parent'],'path':inst['path'],
                 'properties':{k:clean(v) for k,v in inst['properties'].items()}} for inst in self.instances.values()]

    def extract(self,directory):
        directory=Path(directory);directory.mkdir(parents=True,exist_ok=True)
        if (directory/'manifest.json').exists():raise ValueError(f'Extraction would overwrite an existing source tree: {directory}')
        scripts=[];seen=set()
        for ref,inst in self.instances.items():
            if inst['class'] not in SCRIPT_CLASSES: continue
            components=[];current=ref
            while current!=-1:
                components.append(file_component(self.instances[current]['name']));current=self.instances[current]['parent']
            components=list(reversed(components)); suffix={'Script':'.server.luau','LocalScript':'.client.luau','ModuleScript':'.luau'}[inst['class']]
            relative=Path(*components[:-1],components[-1]+suffix)
            if str(relative) in seen:relative=relative.with_name(relative.stem+f'__ref_{ref}'+relative.suffix)
            seen.add(str(relative));target=directory/relative;target.parent.mkdir(parents=True,exist_ok=True)
            source=inst.get('source',b'');target.write_bytes(source)
            scripts.append({'ref':ref,'class':inst['class'],'path':inst['path'],'file':str(relative),'sha256':hashlib.sha256(source).hexdigest(),
                            'bytes':len(source),'disabled':inst['properties'].get('Disabled')})
        manifest={'format_version':1,'original':str(self.path.resolve()),'original_sha256':hashlib.sha256(self.binary).hexdigest(),
                  'instances':len(self.instances),'groups':len(self.groups),'scripts':scripts}
        (directory/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
        (directory/'instances.json').write_text(json.dumps(self.metadata(),ensure_ascii=False,indent=2)+'\n')
        return manifest

    def decompress(self,output):
        """Emit equivalent uncompressed chunks for independent legacy decoders."""
        output=Path(output)
        if output.resolve()==self.path.resolve():raise ValueError('Output must differ from original input')
        binary=self.header+b''.join(struct.pack('<4sIII',chunk.tag,0,len(chunk.data),0)+chunk.data for chunk in self.chunks)+self.trailing
        output.parent.mkdir(parents=True,exist_ok=True);output.write_bytes(binary)
        decoded=Place(output)
        if [c.data for c in decoded.chunks]!=[c.data for c in self.chunks]:raise ValueError('Uncompressed payload mismatch')
        return {'output':str(output.resolve()),'chunks':len(self.chunks),'bytes':len(binary)}

    def patch(self,directory,output):
        directory=Path(directory);output=Path(output)
        if output.resolve()==self.path.resolve():raise ValueError('Output must differ from original input')
        manifest=json.loads((directory/'manifest.json').read_text())
        if manifest['original_sha256']!=hashlib.sha256(self.binary).hexdigest():
            raise ValueError('Original file does not match the extraction manifest')
        source_updates={};known_files=set();changed_scripts=[]
        for script in manifest['scripts']:
            relative=script['file']; known_files.add(relative);file=directory/relative
            if not file.is_file():raise ValueError(f'Missing original script file: {file}')
            ref=script['ref'];old=self.instances[ref].get('source',b'');new=file.read_bytes()
            if hashlib.sha256(old).hexdigest()!=script['sha256']:raise ValueError(f'Original source hash mismatch: {relative}')
            if new!=old:
                source_updates[ref]=new
                changed_scripts.append({'ref':ref,'path':script['path'],'file':relative,'old_sha256':hashlib.sha256(old).hexdigest(),
                                        'new_sha256':hashlib.sha256(new).hexdigest(),'old_bytes':len(old),'new_bytes':len(new)})
        new_files=sorted(file for file in directory.rglob('*.luau') if file.relative_to(directory).as_posix() not in known_files)
        path_refs={}
        for ref in self.instances:path_refs.setdefault(self.file_components(ref),[]).append(ref)
        added=[];new_paths={};next_ref=max(self.instances,default=-1)+1

        def parent_ref(components):
            nonlocal next_ref
            if not components:return -1
            if components in new_paths:return new_paths[components]
            refs=path_refs.get(components,[])
            if len(refs)>1:raise ValueError(f'Ambiguous parent path: {components}')
            if refs:return refs[0]
            if len(components)==1:raise ValueError(f'New top-level service is unsupported: {components[0]}')
            parent=parent_ref(components[:-1]);ref=next_ref;next_ref+=1;new_paths[components]=ref
            added.append({'ref':ref,'parent':parent,'name':instance_name(components[-1]),'class':'Folder','components':components})
            return ref

        for file in new_files:
            relative=file.relative_to(directory);name=relative.name
            if name.endswith('.server.luau'):cls='Script';name=name[:-12]
            elif name.endswith('.client.luau'):cls='LocalScript';name=name[:-12]
            else:cls='ModuleScript';name=name[:-5]
            components=tuple(relative.parts[:-1])+(name,)
            if components in path_refs or components in new_paths:raise ValueError(f'New script collides with an existing instance: {relative}')
            parent=parent_ref(components[:-1]);ref=next_ref;next_ref+=1;new_paths[components]=ref
            added.append({'ref':ref,'parent':parent,'name':instance_name(name),'class':cls,'source':file.read_bytes(),
                          'file':relative.as_posix(),'components':components})

        replacements={}
        for group_id,group in self.groups.items():
            if not any(ref in source_updates for ref in group['refs']):continue
            prop=self.properties[(group_id,'Source')]
            if prop['type']!=1:raise ValueError('Source is not stored as a string array')
            payload=struct.pack('<I',group_id)+string('Source')+b'\x01'
            payload+=b''.join(string(source_updates.get(ref,self.instances[ref].get('source',b''))) for ref in group['refs'])
            replacements[prop['chunk']]=build_chunk(b'PROP',payload)

        extra_chunks=[];new_groups=0
        for cls in sorted(set(inst['class'] for inst in added)):
            group_id=max(self.groups,default=-1)+1+new_groups;new_groups+=1
            items=[inst for inst in added if inst['class']==cls];refs=[inst['ref'] for inst in items]
            payload=struct.pack('<I',group_id)+string(cls)+b'\x00'+struct.pack('<I',len(items))+encode_refs(refs)
            extra_chunks.append(build_chunk(b'INST',payload))
            payload=struct.pack('<I',group_id)+string('Name')+b'\x01'+b''.join(string(inst['name']) for inst in items)
            extra_chunks.append(build_chunk(b'PROP',payload))
            if cls in SCRIPT_CLASSES:
                payload=struct.pack('<I',group_id)+string('Source')+b'\x01'+b''.join(string(inst['source']) for inst in items)
                extra_chunks.append(build_chunk(b'PROP',payload))
                if cls in {'Script','LocalScript'}:
                    payload=struct.pack('<I',group_id)+string('Disabled')+b'\x02'+bytes(len(items))
                    extra_chunks.append(build_chunk(b'PROP',payload))
        if added:
            data=self.chunks[self.parent_chunk].data;count=u32(data,1)
            refs=decode_refs(data[5:5+count*4],count);parents=decode_refs(data[5+count*4:],count)
            refs.extend(inst['ref'] for inst in added);parents.extend(inst['parent'] for inst in added)
            replacements[self.parent_chunk]=build_chunk(b'PRNT',b'\x00'+struct.pack('<I',len(refs))+encode_refs(refs)+encode_refs(parents))
        header=bytearray(self.header)
        if added:struct.pack_into('<II',header,16,len(self.groups)+new_groups,len(self.instances)+len(added))
        binary=bytearray(header)
        for ci,chunk in enumerate(self.chunks):
            if ci==self.parent_chunk:binary.extend(b''.join(extra_chunks))
            binary.extend(replacements.get(ci,chunk.raw))
        binary.extend(self.trailing);output.parent.mkdir(parents=True,exist_ok=True);output.write_bytes(binary)

        # Decode from disk afresh; check every original instance and raw chunk.
        patched=Place(output)
        for ref,old in self.instances.items():
            new=patched.instances[ref]
            for key in ('name','class','parent','properties'):
                if old[key]!=new[key]:raise ValueError(f'Unexpected {key} change at {old["path"]}')
            if new.get('source',b'')!=source_updates.get(ref,old.get('source',b'')):
                raise ValueError(f'Source roundtrip failed at {old["path"]}')
        for inst in added:
            new=patched.instances[inst['ref']]
            if (new['name'],new['class'],new['parent'])!=(inst['name'],inst['class'],inst['parent']):
                raise ValueError(f'Added instance roundtrip failed at {inst["components"]}')
            if inst['class'] in SCRIPT_CLASSES and new.get('source',b'')!=inst['source']:
                raise ValueError(f'Added source roundtrip failed at {inst["components"]}')
        shifted=0;preserved=0
        for ci,chunk in enumerate(self.chunks):
            if ci==self.parent_chunk:shifted+=len(extra_chunks)
            expected=replacements.get(ci,chunk.raw)
            if patched.chunks[ci+shifted].raw!=expected:raise ValueError(f'Unexpected binary chunk change at {ci}')
            if ci not in replacements:preserved+=1
        report={'format_version':1,'original':str(self.path.resolve()),'output':str(output.resolve()),
                'original_sha256':hashlib.sha256(self.binary).hexdigest(),'output_sha256':hashlib.sha256(binary).hexdigest(),
                'original_instances':len(self.instances),'output_instances':len(patched.instances),
                'original_chunks':len(self.chunks),'preserved_chunks':preserved,'changed_chunks':sorted(replacements),
                'added_chunks':len(extra_chunks),'changed_scripts':changed_scripts,
                'added_instances':[{key:inst[key] for key in ('ref','parent','name','class')}|{'path':'/'.join(instance_name(c) for c in inst['components'])}
                                   for inst in added],
                'validation':{'all_original_non_source_properties_identical':True,'all_unmodified_chunks_byte_identical':True,
                              'all_script_sources_roundtrip':True,'all_original_parent_links_identical':True}}
        output.with_suffix(output.suffix+'.report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
        return report


def build_chunk(tag,payload):
    compressed=zstandard.ZstdCompressor(level=9).compress(payload)
    return struct.pack('<4sIII',tag,len(compressed),len(payload),0)+compressed

def main():
    parser=argparse.ArgumentParser(description=__doc__);sub=parser.add_subparsers(dest='command',required=True)
    extract=sub.add_parser('extract');extract.add_argument('place');extract.add_argument('directory')
    patch=sub.add_parser('patch');patch.add_argument('place');patch.add_argument('directory');patch.add_argument('output')
    decompress=sub.add_parser('decompress');decompress.add_argument('place');decompress.add_argument('output')
    args=parser.parse_args()
    if args.command=='extract':
        place=Place(args.place);manifest=place.extract(args.directory)
        print(json.dumps({key:manifest[key] for key in ['instances','groups','original_sha256']}|{'scripts':len(manifest['scripts']),'directory':str(Path(args.directory).resolve())}))
    elif args.command=='patch':
        report=Place(args.place).patch(args.directory,args.output)
        print(json.dumps({key:report[key] for key in ['output','original_instances','output_instances','preserved_chunks','changed_chunks','added_chunks','validation']}|
                         {'changed_scripts':len(report['changed_scripts']),'added_instances':len(report['added_instances'])}))
    elif args.command=='decompress':
        print(json.dumps(Place(args.place).decompress(args.output)))

if __name__=='__main__':main()
