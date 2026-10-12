"""Windows validation: Swift grammar and project integrity, NOT Swift typechecking.
Requires: tree-sitter, tree-sitter-swift, openstep-parser.
"""
from pathlib import Path
import json
import re
import sys
import xml.etree.ElementTree as ET
from tree_sitter import Language, Parser
import tree_sitter_swift
from openstep_parser import OpenStepDecoder

ROOT = Path(__file__).resolve().parents[1]
parser = Parser(Language(tree_sitter_swift.language()))
issues = []
files = sorted((ROOT / 'App').glob('*.swift')) + sorted((ROOT / 'Tests').glob('*.swift'))
for file in files:
    content = file.read_bytes()
    tree = parser.parse(content)
    def walk(node):
        if node.type == 'ERROR' or node.is_missing:
            issues.append(f'{file.name}:{node.start_point.row+1}: {node.type} {content[node.start_byte:node.end_byte][:120]!r}')
        for child in node.children: walk(child)
    walk(tree.root_node)

project = OpenStepDecoder.ParseFromString((ROOT / 'AfterClass.xcodeproj/project.pbxproj').read_text(encoding='utf-8'))
objects = project['objects']
assert project['rootObject'] in objects
tracked = set()
for identifier, obj in objects.items():
    if obj['isa'] == 'PBXFileReference' and obj.get('sourceTree') == 'SOURCE_ROOT':
        p = ROOT / obj['path']
        assert p.is_file(), f'Missing project file {p}'
        tracked.add(p.resolve())
    for field in ['children', 'files', 'buildPhases', 'dependencies', 'buildConfigurations', 'targets', 'packageReferences', 'packageProductDependencies']:
        for ref in obj.get(field, []): assert ref in objects, f'Invalid reference {ref}'
    for field in ['fileRef','productRef','package','target','targetProxy','mainGroup','buildConfigurationList','productReference','containerPortal','productRefGroup']:
        if field in obj: assert obj[field] in objects, f'Invalid {field}: {obj[field]}'
assert all(p.resolve() in tracked for p in files), 'Unregistered Swift source'
scheme = ET.parse(ROOT / 'AfterClass.xcodeproj/xcshareddata/xcschemes/AfterClass.xcscheme')
for ref in scheme.iter('BuildableReference'):
    assert ref.attrib['BlueprintIdentifier'] in objects
assert len([x for x in objects.values() if x['isa']=='XCRemoteSwiftPackageReference']) == 1
for x in objects.values():
    if x['isa']=='XCRemoteSwiftPackageReference': assert re.fullmatch(r'[0-9a-f]{40}',x['requirement']['revision'])
assert 'kSecAttrAccessibleWhenUnlockedThisDeviceOnly' in (ROOT/'App/Keychain.swift').read_text(encoding='utf-8')
assert 'apiKey' not in (ROOT/'App/Models.swift').read_text(encoding='utf-8')
for license_name in ['HorizonCalendar']:
    assert len((ROOT/f'ThirdParty/{license_name}-LICENSE.txt').read_text(encoding='utf-8')) > 500

report = {'swift_files':len(files),'swift_grammar_errors':issues,'project_objects':len(objects),
          'native_compilation':'NOT RUN: Windows host has no Xcode',
          'native_tests':'NOT RUN: requires iOS simulator',
          'live_ai':'NOT RUN: no user API configuration',
          'passed':not issues}
out=ROOT/'validation'; out.mkdir(exist_ok=True)
(out/'source-check.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(report,ensure_ascii=False,indent=2))
sys.exit(bool(issues))
