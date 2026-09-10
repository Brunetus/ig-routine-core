#!/bin/zsh
# scan-transients.sh — ARCHITECT-CORE §6.0: find the sharp audio moments (claps, knocks,
# slams, laugh bursts) in source clips. Each hit is a cut-on-motion trigger and the
# candidate seam for a banked-clip payoff. Usage: scan-transients.sh <clip> [<clip>...]
# Prints "<clip>  <t>s  rms=<v> (x<k> median)" per hit; no audio stream = "no audio".
# Then LOOK: ffmpeg -ss <t-0.6> -t 1.2 -i <clip> -vf "fps=30,scale=-2:300,tile=12x3" strip.jpg
export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"
for f in "$@"; do
  if ! ffmpeg -i "$f" 2>&1 | grep -q "Audio:"; then echo "$f  no audio"; continue; fi
  ffmpeg -v error -i "$f" -vn -ac 1 -ar 16000 -f f32le - 2>/dev/null | /usr/bin/python3 -c "
import sys,numpy as np
a=np.frombuffer(sys.stdin.buffer.read(),dtype=np.float32); sr=16000; w=int(sr*0.02); n=len(a)//w
if n<3: print('$f  too short'); sys.exit()
e=np.sqrt((a[:n*w].reshape(n,w)**2).mean(1)); med=float(np.median(e)) or 1e-6; hits=0
for i in range(1,n-1):
    if e[i]>=8*med and e[i]>=2.5*e[i-1] and e[i]>0.02:
        print(f'$f  {i*0.02:6.2f}s  rms={e[i]:.3f} (x{e[i]/med:.0f} median)'); hits+=1
if not hits: print('$f  no transients')
"
done
