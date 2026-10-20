#!/bin/bash
export PULSE_SERVER=unix:/mnt/wslg/PulseServer
ACTION=$1
PIDFILE=/tmp/dictate.pid
REC=/tmp/dictate_rec.wav
GATED=/tmp/dictate_rec_gated.wav
TIMING=/home/nikit/.local/share/dictate/dictate_timing.log
SERVER=http://127.0.0.1:8080
LOCK=/tmp/dictate_inf.lock

# Lazy-start: wake whisper-server if it's not answering (first press of RAlt takes ~2s longer)
if ! curl -s -m 1 -o /dev/null "$SERVER/" 2>/dev/null; then
    systemctl start whisper-server 2>/dev/null
    nohup /home/nikit/.local/bin/whisper-server.sh >/dev/null 2>&1 &
    for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
        curl -s -m 1 -o /dev/null "$SERVER/" 2>/dev/null && break
        sleep 0.5
    done
fi

transcribe() {
    local code rc
    code=$(curl -s -m 90 -o /tmp/dictate_resp.json -w '%{http_code}' \
        -X POST "$SERVER/inference" -F file=@"$1" -F response_format=json)
    rc=$?
    [ $rc -ne 0 ] && { echo "ERR:curl($rc)"; return; }
    [ "$code" != "200" ] && { echo "ERR:http($code)"; return; }
    python3 -c 'import json,sys
try:
    print(json.load(open("/tmp/dictate_resp.json")).get("text","").strip())
except Exception:
    print("ERR:json")'
}

case "$ACTION" in
  start)
    rm -f "$REC" /tmp/dictate_out.txt /tmp/dictate_out.done
    setsid parecord --file-format=wav --rate=16000 --channels=1 "$REC" >/dev/null 2>&1 < /dev/null &
    echo $! > "$PIDFILE"
    sleep 1
    ;;
  abort)
    if [ -f "$PIDFILE" ]; then
      kill "$(cat "$PIDFILE")" 2>/dev/null
      rm -f "$PIDFILE"
    fi
    rm -f "$REC" "$GATED" /tmp/dictate_out.txt /tmp/dictate_out.done
    echo "$(date +%s.%N) aborted" >> "$TIMING"
    ;;
  stop)
    echo "$(date +%s.%N) stop_begin" >> "$TIMING"
    if [ -f "$PIDFILE" ]; then
      kill "$(cat "$PIDFILE")" 2>/dev/null
      rm -f "$PIDFILE"
      sleep 0.3
    fi
    if ! python3 -c '
import sys, wave, array, math
w = wave.open(sys.argv[1], "rb")
d = array.array("h", w.readframes(w.getnframes()))
w.close()
if not d: sys.exit(1)
r = math.sqrt(sum(x*x for x in d)/len(d))
sys.stderr.write("rms=%.0f\n" % r)
sys.exit(0 if r >= 60 else 1)
' "$REC"; then
      echo "$(date +%s.%N) rms_skip" >> "$TIMING"
      echo "SILENCE" > /tmp/dictate_out.txt
      touch /tmp/dictate_out.done
      exit 0
    fi
    exec 9>"$LOCK"
    flock -n 9 || { echo "ERR:busy" > /tmp/dictate_out.txt; touch /tmp/dictate_out.done; exit 0; }
    GATE_LOG=$(python3 /home/nikit/.local/bin/dictate-normalize.py "$REC" "$GATED" 2>&1 >/dev/null)
    if python3 -c 'import wave,sys; sys.exit(0 if wave.open(sys.argv[1]).getnframes()>1600 else 1)' "$GATED" 2>/dev/null; then
      TEXT=$(transcribe "$GATED")
      [ -n "$GATE_LOG" ] && echo "$(date +%s.%N) gate[$GATE_LOG]" >> "$TIMING"
    else
      TEXT="ERR:gated_wav"
    fi
    echo "$(date +%s.%N) transcribe_done" >> "$TIMING"
    if [ "$TEXT" = "ERR:curl(0)" ] || [ -z "$TEXT" ] || [ "$TEXT" = "ERR:json" ]; then
      TEXT=$(transcribe "$REC")
      echo "$(date +%s.%N) retry_raw" >> "$TIMING"
    fi
    if echo "$TEXT" | grep -q '\*'; then
      echo "$(date +%s.%N) hallucination_filtered" >> "$TIMING"
      TEXT="SILENCE"
    fi
    if echo "$TEXT" | grep -qiE 'субтитр|закомолдин|кривошеев|подписк|продолжение следует|спасибо за (просмотр|внимание)|приносим извинения|звук по-профессии|звук по-говорящ|по-говорому|редактор субтитров'; then
      echo "$(date +%s.%N) hallucination_filtered" >> "$TIMING"
      TEXT="SILENCE"
    fi
    [ -z "$TEXT" ] && TEXT="SILENCE"
    TEXT=$(printf '%s' "$TEXT" | tr '\r\n' '  ' | sed 's/  */ /g')
    printf '%s' "$TEXT" > /tmp/dictate_out.txt
    touch /tmp/dictate_out.done
    ;;
esac
exit 0