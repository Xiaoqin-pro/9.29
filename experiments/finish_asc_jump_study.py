"""Finish only the already launched Jump pilot, without starting any additional runs."""
from pathlib import Path
import json,time,sys,subprocess
ROOT=Path(__file__).resolve().parents[1];run=ROOT/'results/cec'/Path((ROOT/'work/asc_jump_latest.txt').read_text(encoding='utf8').strip()).name
last=-60
while True:
    try:status=json.loads((run/'status.json').read_text(encoding='utf8'))
    except json.JSONDecodeError:time.sleep(2);continue
    n=status.get('Completed',0)
    if n-last>=60 or status['Status'] not in ['running','prepared']:
        print('Jump progress:',status['Status'],n,'/',status.get('Total'),flush=True);last=n
    if status['Status']=='failed':raise RuntimeError('Failed optimization; no records dropped')
    if status['Status']=='complete':break
    time.sleep(10)
subprocess.run([sys.executable,str(ROOT/'experiments/analyze_asc_jump_study.py'),str(run)],cwd=ROOT,check=True)
subprocess.run([sys.executable,str(ROOT/'experiments/verify_asc_jump_public.py')],cwd=ROOT,check=True)
print('Completed Jump pilot, artifact verification and public CSV replay.',flush=True)
