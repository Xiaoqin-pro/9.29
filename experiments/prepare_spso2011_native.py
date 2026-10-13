"""Build native pure-standard SPSO2011 from checksum-pinned official sources.
Original/modified upstream files stay under ignored work/. This script does not
claim the downloadable MATLAB local-search extension is the pure standard.
After any rebuild rerun test_SPSO2011_reference before launching formal jobs.
"""
from pathlib import Path
from urllib.request import urlopen
import hashlib,json,zipfile,io,shutil,subprocess,argparse
root=Path(__file__).resolve().parents[1];w=root/'work/spso2011_audit_20261013';w.mkdir(exist_ok=True)
parser=argparse.ArgumentParser();parser.add_argument('--verify-rebuild',action='store_true');args=parser.parse_args()
# Exact downloaded primary archive identifiers recorded at first retrieval.
locked=json.loads((w/'source_provenance.json').read_text(encoding='utf-8')) if (w/'source_provenance.json').exists() else None
pins=[('standard_pso_2011_c.zip', 'https://www.particleswarm.info/standard_pso_2011_c.zip', '11692f658158b18aafd97d667eeebdc7527cf21147d530d73d4c7eb795af0557'), ('SPSO_descriptions.pdf', 'http://clerc.maurice.free.fr/pso/SPSO_descriptions.pdf', '1da08c4a8bba7aacba7fb0210fcf3341a1d4ff007f4e07729d1c435e5e41d7d9')]
for name,url,sha in pins:
    path=w/name
    if not path.exists():path.write_bytes(urlopen(url,timeout=60).read())
    blob=path.read_bytes();assert hashlib.sha256(blob).hexdigest()==sha, f'Unexpected primary source {name}'
    if name.endswith('.zip'):
        dest=w/name.removesuffix('.zip');dest.mkdir(exist_ok=True)
        with zipfile.ZipFile(io.BytesIO(blob)) as z:
            for m in z.infolist():assert (dest/m.filename).resolve().is_relative_to(dest.resolve())
            z.extractall(dest)
src=w/'standard_pso_2011_c';b=w/('native_rebuild_verify' if args.verify_rebuild else 'native_build');b.mkdir(exist_ok=True)
h=(src/'main.h').read_text(encoding='utf-8-sig').replace('#define\tDMax 42','#define\tDMax 128')
h=h.replace('#include <gsl/gsl_qrng.h>','// Disabled GSL nonstandard options: standard BW2=0 never calls quasiRand.')
(b/'main.h').write_text(h,encoding='utf-8')
s=(src/'PSO.c').read_text(encoding='utf-8-sig')
needle='R.SW.X[s].x[d] = alea (xMin,xMax,randCase);';assert needle in s
s=s.replace(needle,needle+'\n            R.SW.X[s].x[d] = suppliedP0[s + param.S*d];')
s=s.replace('while (noStop == 0)','while (noStop == 0 && R.nEval < pb.evalMax)')
s=s.replace('iter=iter+1;','iter=iter+1;auditIterations=iter;')
s=s.replace('switch(param.topology)','auditTopologyRebuilds++;\n            switch(param.topology)',1)
s=s.replace('s=index[s0];','if(R.nEval >= pb.evalMax) break;\n            s=index[s0];')
s=s.replace('out=1;','out=1;auditBoundaryClips++;');(b/'PSO_adapted.c').write_text(s,encoding='utf-8')
s=(src/'alea.c').read_text(encoding='utf-8-sig');start=s.index('struct vectorList quasiRand(')
s=s[:start]+'''struct vectorList quasiRand(int D,int nRand,int option){ struct vectorList q; mexErrMsgIdAndTxt("SPSO:NonStandardOption","Quasi-RNG disabled in pure standard adapter"); return q; }\n'''
(b/'alea_adapted.c').write_text(s,encoding='utf-8');(b/'KISS.c').write_bytes((src/'KISS.c').read_bytes());(b/'tools.c').write_text((src/'tools.c').read_text(encoding='utf-8-sig'),encoding='utf-8')
shutil.copy2(root/'experiments/spso2011_native_bridge.c',b/'SPSO2011_native.c')
# MATLABROOT and GCC are discovered locally; quote-free subprocess argv avoids shell injection.
matlab=shutil.which('matlab');gcc=shutil.which('gcc');assert matlab and gcc,'MATLAB and MinGW GCC required'
matroot=Path(matlab).parents[1];lib=matroot/'extern/lib/win64/mingw64'
cmd=[gcc,'-O2','-std=c99','-shared','-static-libgcc','-Wl,--export-all-symbols','-I'+str(matroot/'extern/include'),str(b/'SPSO2011_native.c'),str(lib/'libmex.lib'),str(lib/'libmx.lib'),'-lm','-o',str(b/'SPSO2011_native.mexw64')]
subprocess.run(cmd,check=True)
prov={'OfficialPrograms':'https://www.particleswarm.info/Programs.html','ArchiveURL':pins[0][1],'Archives':[{'File':name,'SHA256':sha} for name,_,sha in pins],'CodeProfile':'pure official C defaults, allBW0, KISS, uniform radius, confinement0','Compiler':subprocess.check_output([gcc,'--version'],text=True).splitlines()[0],'NativeController':True}
(b/'rebuilt_provenance.json' if args.verify_rebuild else w/'source_provenance.json').write_text(json.dumps(prov,indent=2),encoding='utf-8')
if args.verify_rebuild:shutil.copy2(b/'SPSO2011_native.mexw64',b/'SPSO2011_native_rebuildcheck.mexw64')
print('Built native pure-standard SPSO2011. MUST rerun test_SPSO2011_reference before studies.')
