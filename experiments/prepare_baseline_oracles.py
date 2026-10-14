"""Fetch pinned pristine baseline sources and build mechanical test oracles.
Derived third-party code stays under ignored work/. No parameter tuning here.
"""
from pathlib import Path
from urllib.request import Request, urlopen
import hashlib,json,zipfile,io
ROOT=Path(__file__).resolve().parents[1]
def download(url,sha):
    with urlopen(Request(url,headers={'User-Agent':'SAQ-CSO-reproduction-audit'}),timeout=60) as response:b=response.read()
    assert hashlib.sha256(b).hexdigest()==sha, f'Unexpected source checksum: {url}'
    return b

def prepare_hclpso():
    w=ROOT/'work/hclpso_author_audit_20261013';w.mkdir(parents=True,exist_ok=True)
    commit='4d7ce681d5121e5af1cffb21c5b79ce9df7de5b1';sha='1e984cb7a3b6496cb5cbceb04ff337bbcbff0f553775f504679b4eb529457acd'
    b=download(f'https://raw.githubusercontent.com/P-N-Suganthan/CODES/{commit}/2015-SWEVO-HCLPSO.zip',sha)
    (w/'2015-SWEVO-HCLPSO.zip').write_bytes(b); dest=w/'original';dest.mkdir(exist_ok=True)
    with zipfile.ZipFile(io.BytesIO(b)) as z:
        for member in z.infolist():
            target=(dest/member.filename).resolve();assert target.is_relative_to(dest.resolve()),'Unsafe ZIP member'
        z.extractall(dest)
    original=w/'original/HCLPSO/HCLPSO_PS_15_35.m';s=original.read_text(encoding='utf-8-sig')
    s=s[s.index('check_vel=[];'):s.index("% fprintf('Output")]
    s=s.replace('num_g=num_particle;','num_g=N;').replace('dimension','D')
    s=s.replace('range(1)*ones(num_g,D)','repmat(state.lowerBound,num_g,1)').replace('range(2)*ones(num_g,D)','repmat(state.upperBound,num_g,1)')
    s=s.replace('pos = range_min+ interval.*rand(num_g,D);','pos = range_min+ interval.*rand(num_g,D); pos=state.initialPopulation;')
    s=s.replace('benchmark_func(pos(i,:),func_num)','capture(pos(i,:))')
    s=s.replace('while k<=max_iteration && fitcount<=max_FES','while calls<max_FES\n        iterations=iterations+1; assert(iterations<=50*max_iteration);')
    s=s.replace('for i=1:num_g   ','for i=1:num_g\n            if calls>=max_FES, break; end')
    head="function [Best,T,info]=HCLPSO_AuthorOracle(f,state,~,N,seed)\nrng(seed,'twister'); D=size(state.initialPopulation,2); max_FES=state.maxEvaluations;\nmax_iteration=ceil(max_FES/N); calls=0; T=nan(max_FES,1); Best.Cost=inf; iterations=0;\n"
    tail="\ninfo=struct('Evaluations',calls,'Iterations',iterations);\n function value=capture(x)\n  calls=calls+1; assert(calls<=max_FES); value=f(x);\n  if value<Best.Cost, Best.Cost=value; Best.Vector=x; end\n  T(calls)=Best.Cost;\n end\nend\n"
    (w/'HCLPSO_AuthorOracle.m').write_text(head+s+tail,encoding='utf-8')
    (w/'source_provenance.json').write_text(json.dumps({'Repository':'https://github.com/P-N-Suganthan/CODES','Commit':commit,'Archive':'2015-SWEVO-HCLPSO.zip','ZipSHA256':sha,'OriginalSourceSHA256':hashlib.sha256(original.read_bytes()).hexdigest()},indent=2),encoding='utf-8')

def prepare_hidms():
    w=ROOT/'work/hidms_author_audit_20261013';w.mkdir(parents=True,exist_ok=True)
    commit='93e9fa6ba399fd24ae955a0b91b3e384d30ac30c';sha='4138eec48fbec88706cf578db769f86858f338c9dd66afac78f630f927bfdbcf'
    b=download(f'https://raw.githubusercontent.com/FTVarna/HIDMS-PSO/{commit}/HIDMSPSO.m',sha)
    (w/'HIDMSPSO.m').write_bytes(b);s=b.decode('utf-8-sig').replace('\r\n','\n')
    s=s.replace('function [fmin] = HIDMSPSO(fhd,fId,n,d,range)','function [fmin,T,info] = HIDMS_SourceOracle(fhd,fId,n,d,range,state,seed)')
    s=s.replace('if rem(n,4)~=0','if rem(n,8)~=0').replace("rand('seed',sum(100*clock));","rng(seed,'twister'); calls=0; T=nan(state.maxEvaluations,1); initialCost=NaN; recordedBest=inf;")
    s=s.replace('showProgress=true;','showProgress=false;').replace('Fmax=10^4*d;','Fmax=state.maxEvaluations;').replace('Tmax=Fmax/n;','Tmax=ceil(Fmax/n);')
    s=s.replace('PX=X;','X=state.initialPopulation;\nPX=X;',1).replace("F=feval(fhd,X',fId);","F=capture(X'); initialCost=min(F);")
    s=s.replace('for t=1:Tmax','t=0;\nfor t=1:Tmax\n    if calls>=Fmax,break;end')
    s=s.replace('for i=1:n\n        if F(i)','for i=1:n\n        if calls>=Fmax,break;end\n        if F(i)')
    s=s.replace("F(i)=feval(fhd,X(i,:)',fId);","F(i)=capture(X(i,:)');")
    assert s.count('exemplar2=PX(bsId,:);')==1
    s=s.replace('exemplar2=PX(bsId,:);','exemplar2=PX(sList(bsId),:); % documented local-index correction')
    s=s.replace('fmin=GF;\nend',"fmin=GF;\ninfo=struct('Evaluations',calls,'InitialCost',initialCost,'InitialPopulation',state.initialPopulation,'Iterations',t);\n function values=capture(columns)\n  values=zeros(1,size(columns,2));\n  for ci=1:size(columns,2)\n   calls=calls+1;assert(calls<=Fmax);values(ci)=fhd(columns(:,ci)');\n   recordedBest=min(recordedBest,values(ci));T(calls)=recordedBest;\n  end\n end\nend")
    (w/'HIDMS_SourceOracle.m').write_text(s,encoding='utf-8')
    adapter=(ROOT/'src/HIDMS_PSO_CEC.m').read_text(encoding='utf-8-sig')
    start=adapter.index('function [exemplar,exemplar2]=getExemplarMaster(');end=adapter.index('function [exemplar,exemplar2]=getExemplarSlave(')
    (w/'hidms_master_fixture.m').write_text(adapter[start:end].replace('getExemplarMaster','hidms_master_fixture',1),encoding='utf-8')
    start=adapter.index('function [y] = Non_uniform_mutation(')
    (w/'hidms_mutation_fixture.m').write_text(adapter[start:].replace('Non_uniform_mutation','hidms_mutation_fixture',1),encoding='utf-8')
    (w/'source_provenance.json').write_text(json.dumps({'Repository':'https://github.com/FTVarna/HIDMS-PSO','Commit':commit,'SHA256':sha,'License':None},indent=2),encoding='utf-8')
if __name__=='__main__':
    prepare_hclpso();prepare_hidms();print('Pinned sources and mechanical oracles ready; no algorithm files changed.')

