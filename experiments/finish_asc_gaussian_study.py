"""Finish only the current fixed A0-A3 experiment; do not launch additional optimizations."""
from pathlib import Path
import json,time,sys,subprocess
ROOT=Path(__file__).resolve().parents[1];run=ROOT/'results/cec'/Path((ROOT/'work/asc_gaussian_latest.txt').read_text(encoding='utf8').strip()).name
last=-80
while True:
 try:status=json.loads((run/'status.json').read_text(encoding='utf8'))
 except json.JSONDecodeError:time.sleep(2);continue
 n=status.get('Completed',0)
 if n-last>=80 or status['Status'] not in ['running','prepared']:
  print('Gaussian progress:',status['Status'],n,'/',status.get('Total'),flush=True);last=n
 if status['Status']=='failed':raise RuntimeError('Failed run; all records preserved')
 if status['Status']=='complete':break
 time.sleep(10)
subprocess.run([sys.executable,str(ROOT/'experiments/analyze_asc_gaussian_study.py'),str(run)],cwd=ROOT,check=True)
subprocess.run([sys.executable,str(ROOT/'experiments/verify_asc_gaussian_public.py')],cwd=ROOT,check=True)
print('Gaussian A0-A3 complete, artifacts and public CSV verified.',flush=True)
