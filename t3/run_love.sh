#!/bin/bash
### Used to start multiple love instances. Assumes a square matrix
### receives an arg with the size one dimention of the matrix. [from 2 to 5]
defaultSize=2


if [ -z "$1" ]; then
  echo "nor arg received. Using default matrix size: $defaultSize"
  matrixDimention=$defaultSize
else
  matrixDimention=$1
fi

### Checking if is an acepted number
re='^[2345]$'
if ! [[ $matrixDimention =~ $re ]] ; then
   echo "error: the argument receiveid is not an accepted number. Received: $receivedArg, regex used: $re" >&2; exit 1
fi

### Alter matrix config, change the matrix size to match the received

sedCommand="sed -i s/[0-9]\+/$matrixDimention/ matrix-config.lua"
echo "altering the matrix-config file to set the dimentions to $matrixDimention"
echo "command: $sedCommand"
$sedCommand


### Running the nodes
baseComand="love ."
totalSize=$((matrixDimention*matrixDimention - 1))
for i in $(seq 0 $totalSize); do
  com="$baseComand $i"
  echo "initializing node $i. command: $com"
  $com &
  sleep 0.2 # sleep so the nodes graphical interface initialize more smoothly
done
