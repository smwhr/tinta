#!/bin/bash

echo -n "return " > $2
cat $1|sed '1s/^\xEF\xBB\xBF//'|sed "s/\[/{/g"|sed "s/null]/\"TERM\"]/g"|sed "s/]/}/g"|sed "s/\"\([^\"]*\)\":/[\"\1\"] = /g" >> $2