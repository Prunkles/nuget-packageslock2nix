#!/bin/bash

input="Registered Sources:
  1.  nuget.org [Enabled]
      https://api.nuget.org/v3/index.json
  2.  nuget.robotsman.com [Enabled]
      http://10.58.1.1:5555/v3/index.json
warn : You are running the 'list source' operation with an 'HTTP' source, 'nuget.robotsman.com [http://10.58.1.1:5555/v3/index.json]'. Non-HTTPS access will be removed in a future version. Consider migrating to an 'HTTPS' source."

mapfile -t sources < <(
    echo "$input" \
    | awk '$3 == "[Enabled]" { print $2 }'
)
mapfile -t addresses < <(
    echo "$input" \
    | grep --no-group-separator -A1 '\[Enabled\]' \
    | grep -v '\[Enabled\]' \
    | awk '{ $1=$1; print }'
)

#echo "Source Names:"
#echo "${sources[@]}"
#
#echo "Index Addresses:"
#echo "${addresses[@]}"

for i in ${!sources[@]}; do
    echo "${sources[$i]} ${addresses[$i]}"
done


