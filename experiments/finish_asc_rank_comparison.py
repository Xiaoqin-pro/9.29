"""Finish this one comparison after its counted MATLAB runs end."""
from pathlib import Path
import json,time,sys,subprocess
ROOT=Path(__file__).resolve().parents[1]
run=ROOT/'results/cec'/Path((ROOT/'work/asc_rank_comparison_latest.txt').read_text(encoding='utf8').strip()).name
last=-160
while True:
    status=json.loads((run/'status.json').read_text(encoding='utf8'))
    n=status.get('Completed',0)
    if n-last>=160 or status['Status']!='running':
        print('MATLAB progress:',status['Status'],n,'/',status.get('Total'),flush=True);last=n
    if status['Status']=='failed':raise RuntimeError('MATLAB run failed; see raw runs and error log')
    if status['Status']=='complete':break
    time.sleep(10)
subprocess.run([sys.executable,str(ROOT/'experiments/analyze_asc_rank_comparison.py'),str(run)],cwd=ROOT,check=True)
subprocess.run([sys.executable,str(ROOT/'experiments/verify_asc_rank_public.py')],cwd=ROOT,check=True)
print('ASC comparison analysis and public verification complete.',flush=True)
