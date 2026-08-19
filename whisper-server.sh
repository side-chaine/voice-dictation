#!/bin/bash
CONF=/home/nikit/.config/dictate/config
MODEL=$(grep '^MODEL=' "$CONF" 2>/dev/null | cut -d= -f2)
case "$MODEL" in
  small) M=/home/nikit/.local/share/dictate/models/ggml-small.bin ;;
  q5_1)  M=/home/nikit/.local/share/dictate/models/ggml-small-q5_1.bin ;;
  *)     M=/home/nikit/.local/share/dictate/models/ggml-base.bin ;;
esac
exec /home/nikit/whisper.cpp/build/bin/whisper-server -m "$M" -l ru -t 8 -bs 1 --host 127.0.0.1 --port 8080