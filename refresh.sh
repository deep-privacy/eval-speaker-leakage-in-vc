#!/usr/bin/env bash

function yes_or_no {
  return 1; # safe mesure
    while true; do
        read -p "$* [y/n]: " yn
        case $yn in
            [Yy]*) return 0  ;;
            [Nn]*) echo "Aborted" ; return  1 ;;
        esac
    done
}


log_suffix=f0-run-fix

# for f in exp/oar-log/*err-verif-no-voice.log; do
for f in exp/oar-log/*err-$log_suffix.log; do
  echo $f
# for f in exp/oar-log/*nof0-out.log; do
# for f in exp/oar-log/*more.log; do
# for f in exp/oar-log/*out.log; do
  id=$(echo "$f" | cut -d'-' -f2 | cut -d'/' -f2)
  pseudo_speaker_test=$(echo "$f" | cut -d'-' -f3 | cut -d'/' -f2)
  log=$(oarstat -j $id --json --full)
  query=.\"$id\".state
  state=$(echo -n $log | jq $query)
  if [ "$state" == "\"Terminated\"" ]; then
    query=.\"$id\".exit_code
    status=$(echo -n $log | jq $query)

    query=.\"$id\".command
    cmd=$(echo -n $log | jq $query)

    query=.\"$id\".assigned_network_address
    host=$(echo -n $log | jq $query | cut -d"." -f1)

    echo $id $state" || error:" $status "|" $cmd "|" $host

    i=$(echo $cmd | rev | cut -d" " -f1 | rev | sed -e "s/\"//")
    printf "\n"
    yes_or_no "Resubmit the job?" && \
      oarsub -q production -p "host in ('graffiti-4.nancy.grid5000.fr', 'graffiti-5.nancy.grid5000.fr', 'graffiti-6.nancy.grid5000.fr', 'graffiti-8.nancy.grid5000.fr', 'graffiti-9.nancy.grid5000.fr', 'graffiti-11.nancy.grid5000.fr')" -l walltime=44:00 --stderr=exp/oar-log/%jobid%-${pseudo_speaker_test}-err-$log_suffix.log --stdout=exp/oar-log/%jobid%-${pseudo_speaker_test}-out-$log_suffix.log "./run.sh --pseudo-speaker-test-index $i" \
      && rm -v exp/oar-log/$id*


  elif [ "$state" == "\"Running\"" ]; then
    query=.\"$id\".command
    cmd=$(echo -n $log | jq $query)

    query=.\"$id\".startTime
    startt=$(echo -n $log | jq $query)

    echo $id $state  "               |" $cmd
    TZ=Paris date -d @$startt

    printf "\n"
    yes_or_no "Resubmit the job?" && \
      oardel $id && \
      oarsub -q production -p "host in ('graffiti-4.nancy.grid5000.fr', 'graffiti-5.nancy.grid5000.fr', 'graffiti-6.nancy.grid5000.fr', 'graffiti-7.nancy.grid5000.fr', 'graffiti-8.nancy.grid5000.fr', 'graffiti-9.nancy.grid5000.fr')" -l walltime=44:00 --stderr=exp/oar-log/%jobid%-${pseudo_speaker_test}-err.log --stdout=exp/oar-log/%jobid%-${pseudo_speaker_test}-out.log "eval $cmd" \
      && rm -v exp/oar-log/$id*

  else

    query=.\"$id\".command
    cmd=$(echo -n $log | jq $query)

    query=.\"$id\".exit_code
    status=$(echo -n $log | jq $query)

    echo $id $state", error:" $status "|" $cmd

    # echo "====="
    # tail -n 2 exp/oar-log/$id*.log
    # tail -n 2 exp/oar-log/$id*.log
    # echo "====="
    # echo ""
    yes_or_no "RM de log?" && rm -v exp/oar-log/$id*
    echo ""
  fi
done
