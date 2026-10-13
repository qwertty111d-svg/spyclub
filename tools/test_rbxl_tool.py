#!/usr/bin/env python3
"""Integrity tests using the two supplied real places (no Roblox runtime needed)."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from rbxl_tool import Place, decode_refs, encode_refs, lz4_decompress

ROOT=Path(__file__).resolve().parents[1]
ORIGINALS=sorted((ROOT/'places/original').glob('*.rbxl'))

class PlaceIntegrityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if len(ORIGINALS)!=2:
            raise FileNotFoundError('Expected exactly two original places under places/original')

    def test_noop_is_byte_identical_and_extracts_all_sources(self):
        for original in ORIGINALS:
            with self.subTest(place=original.name), tempfile.TemporaryDirectory() as directory:
                place=Place(original);source=Path(directory)/'source';manifest=place.extract(source)
                self.assertEqual(len(manifest['scripts']),159 if 'LOBBY' in original.name else 110)
                for script in manifest['scripts']:
                    self.assertEqual(hashlib.sha256((source/script['file']).read_bytes()).hexdigest(),script['sha256'])
                out=Path(directory)/'noop.rbxl';report=place.patch(source,out)
                self.assertEqual(original.read_bytes(),out.read_bytes())
                self.assertEqual(report['changed_chunks'],[])

    def test_script_and_folder_additions_preserve_original_world(self):
        for original in ORIGINALS:
            with self.subTest(place=original.name), tempfile.TemporaryDirectory() as directory:
                source=Path(directory)/'source';place=Place(original);place.extract(source)
                config=source/'ReplicatedStorage/SpyShared/Config.luau'
                updated=config.read_bytes()+b'\n-- source mutation fixture\n';config.write_bytes(updated)
                additions={
                    'ReplicatedStorage/SpyShared/RoundtripFolder/AddedModule.luau':b'return { tested = true }\n',
                    'StarterPlayer/StarterPlayerScripts/AddedClient.client.luau':b'print("client fixture")\n',
                    'ServerScriptService/AddedServer.server.luau':b'print("server fixture")\n',
                }
                for file,contents in additions.items():
                    target=source/file;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(contents)
                out=Path(directory)/'changed.rbxl';report=place.patch(source,out);decoded=Place(out)
                self.assertEqual(report['output_instances'],report['original_instances']+4)
                self.assertEqual(len(report['changed_scripts']),1)
                self.assertTrue(all(report['validation'].values()))
                for ref,inst in place.instances.items():
                    self.assertEqual(inst['properties'],decoded.instances[ref]['properties'])
                    self.assertEqual(inst['parent'],decoded.instances[ref]['parent'])
                    self.assertEqual(inst['name'],decoded.instances[ref]['name'])
                    self.assertEqual(inst['class'],decoded.instances[ref]['class'])
                by_path={inst['path']:inst for inst in decoded.instances.values()}
                self.assertEqual(by_path['ReplicatedStorage/SpyShared/Config']['source'],updated)
                self.assertEqual(by_path['ReplicatedStorage/SpyShared/RoundtripFolder/AddedModule']['class'],'ModuleScript')
                self.assertEqual(by_path['StarterPlayer/StarterPlayerScripts/AddedClient']['class'],'LocalScript')
                self.assertFalse(by_path['StarterPlayer/StarterPlayerScripts/AddedClient']['properties']['Disabled'])
                self.assertEqual(by_path['ServerScriptService/AddedServer']['class'],'Script')
                self.assertEqual(original.read_bytes(),place.binary)

    def test_missing_original_source_is_an_error(self):
        with tempfile.TemporaryDirectory() as directory:
            place=Place(ORIGINALS[0]);source=Path(directory)/'source';manifest=place.extract(source)
            (source/manifest['scripts'][0]['file']).unlink()
            with self.assertRaisesRegex(ValueError,'Missing original script'):
                place.patch(source,Path(directory)/'out.rbxl')

    def test_original_hash_and_output_protection(self):
        with tempfile.TemporaryDirectory() as directory:
            place=Place(ORIGINALS[0]);source=Path(directory)/'source';place.extract(source)
            with self.assertRaisesRegex(ValueError,'Output must differ'):
                place.patch(source,ORIGINALS[0])
            manifest_path=source/'manifest.json';manifest=json.loads(manifest_path.read_text());manifest['original_sha256']='0'*64
            manifest_path.write_text(json.dumps(manifest))
            with self.assertRaisesRegex(ValueError,'does not match'):
                place.patch(source,Path(directory)/'out.rbxl')

    def test_reference_negative_root_and_large_deltas(self):
        refs=[0,1,1287,-1,8,10000000,8,-1]
        self.assertEqual(decode_refs(encode_refs(refs),len(refs)),refs)

    def test_lz4_literal_and_overlap_supported(self):
        self.assertEqual(lz4_decompress(b'\x40test',4),b'test')
        self.assertEqual(lz4_decompress(b'\x35abc\x03\x00',12),b'abcabcabcabc')

if __name__=='__main__':
    if len(ORIGINALS)!=2:raise SystemExit('Expected exactly two original places under places/original')
    unittest.main()
