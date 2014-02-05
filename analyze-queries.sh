#!/bin/bash

# written by Michael Maier (species@osm)
# 
# 05.11.2013   - intial release
#

# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# version 2 as published by the Free Software Foundation.

###
### Standard help text
###

if  [ "$1" = "-h" ] || [ "$1" = " -help" ] || [ "$1" = "--help" ]
then 
cat <<EOH
Usage: $0 filename [OPTIONS] 

$0 is a program to analyze performance of rendering for query optimizing

requires file postgresql-9.3-main.log to be present in folder

OPTIONS:
   -h -help --help     this help text

   how to use: queries are sorted in descending run time in file "endergebnis"

   search for query run-time:
   	cd single_queries-with-duration
		grep 'SELECT * ... (your query)' * |head -1
	cd ..
	grep xxNNNN md5sums-all
		take md5sum and:
	grep \$md5sum endergebnis
		first column is average run-time in ms

  get SELECT clause of query:
  	cat slow_queries/0-73.722-xx00182 
	  or if not there:
	cat single_queries-with-duration/xxNNNN [ xxNNNN from file endergebnis ]

EOH
exit
fi

###
### variables
###

logfile=postgresql-9.3-main.log

nr_queries=$(grep SELECT $logfile|wc -l)

nr_renderings=$(grep "way,way_area,name" $logfile|grep exec|wc -l)

echo "analyzing $logfile: „$nr_queries“ SQL queries, „$nr_renderings“ mapnik renderings found"

###
### working part
###

# make queries all the same, rm coordinates and logging timestamps 
#cat $logfile|sed 's/BOX3D.*box3d//g' > without-coords
#cat without-coords|sed 's/^.*CET LOG:  duration: //g' > without_timestamp
cat $logfile|sed 's/^.*CET LOG:  duration: //g' > without_timestamp

#split up these normalized queries into single files with query-durations
if [ -d single_queries-with-duration ]; then rm -rf single_queries-with-duration; fi
mkdir single_queries-with-duration/; cd single_queries-with-duration/
csplit --quiet -n 5 ../without_timestamp '/: SELECT/' '{*}'
rm xx00000
echo -n > ../query-durations
for i in x*; do head -1 $i |cut -f 1 -d" " >> ../query-durations; done # auf dateien, wo timestamps noch drin sind
cd ..

echo "done split up time-count queries into „$nr_queries“ files"

# a second folder without query-duration to find same queries with md5sum
cp -r single_queries-with-duration/ single_queries-without-duration/

cd single_queries-without-duration/
for i in `ls x*`; do sed -i -e 's/^.* ms  //g' -e 's/BOX3D.*box3d//g' $i; done # remove dauer-pro-query und BBOX zum finden gleicher queries
md5sum x* > ../md5sums-all
cd ..

echo "done split up normalized queries into „$nr_queries“ files"

# find out same queries with md5sums
paste md5sums-all query-durations > all_md5sums+durations
sort all_md5sums+durations > all_md5sums+durations.sorted

cut -f 1 -d" " all_md5sums+durations.sorted|uniq -c > md5sum_counts
cut -b 9-  md5sum_counts > unique_md5sums

#write all running times of same queries in file named after its md5sum
if [ -d query_run_times ]; then rm -rf query_run_times; fi
mkdir query_run_times
for i in `cat unique_md5sums`; do grep $i all_md5sums+durations|cut -f 2- > query_run_times/$i; done
echo "done extracting query_run_times"

#sum up running times of query per file
if [ -d sums_runtime ]; then rm -rf sums_runtime; fi
mkdir sums_runtime
cd query_run_times/ 
for i in `ls *`; do awk '{a+=$0}END{print a}' $i > ../sums_runtime/$i.sum; done
cd .. 
echo "done summation of query run times"

#how often this query is executed
if [ -d query_counts ]; then rm -rf query_counts; fi
mkdir query_counts
cd query_run_times/ 
for i in `ls *`; do wc -l $i > ../query_counts/$i.lines; done
cd ..

cd query_counts/
for i in `ls *`; do sed -i 's/ .*$//' $i; done # wc puts filename after count, rm it
cd ..
echo "done counting of query runs"

# calculate durchschnittliche laufzeit pro einzelner query
if [ -d durchschnitt ]; then rm -rf durchschnitt; fi
mkdir durchschnitt
#for i in `cat md5sums`; do a=$(cat sums_runtime/$i.sum); b=$(cat query_counts/$i.lines); let c=$a/$ab; echo "$c" > durchschnitt/$i; done #only works in zsh, not bash
for i in `cat unique_md5sums`; do a=$(cat sums_runtime/$i.sum); b=$(cat query_counts/$i.lines); c=$(bc -l <<< "$a/$b"); echo "$c" > durchschnitt/$i; done
# für jede query einen filename rausfinden
echo -n > single-query-files
for i in `cat unique_md5sums`; do grep -m 1 $i md5sums-all >> single-query-files; done
# dazu passend den durchschnitt in eine spalte
echo -n >  single-query-durchschnitt
for i in `cat unique_md5sums`; do cat durchschnitt/$i | cut -b -6 >> single-query-durchschnitt; done
# nun in eine datei
paste single-query-durchschnitt single-query-files > zeit-pro-query
sort -g zeit-pro-query > zeit-pro-query.sorted
# sortier-reihenfolge umdrehen
tac zeit-pro-query.sorted > zeit-pro-query.rsorted
echo "done calculating durchschnittszeit"

#cut -f 1-2 zeit-pro-query.rsorted > slowest_queries_durchschnitt
#sed -i 's/single\///' slowest_queries_durchschnitt
#cut -f 3 -d" " slowest_queries_durchschnitt|head -30 > 30-slowest-files_durchschnitt
#mkdir  slow_queries_durchschnitt
#for i in `cat 30-slowest-files_durchschnitt`; do cp single-with-timestamps/$i slow_queries_durchschnitt/$(grep $i zeit-pro-query.rsorted| cut -f 1); done

# next step: durchschnittszeit mal anzahl gelaufene queries pro durchlauf!
echo -n > zeit-pro-query.spalte
for i in `cat unique_md5sums`; do a=$(cat query_counts/$i.lines); b=$(cat durchschnitt/$i); c=$(bc -l <<< "$a*$b/$nr_renderings") ; echo "$c" | cut -b -6 >> zeit-pro-query.spalte ; done
echo -n >  anzahl-pro-query.spalte
for i in `cat unique_md5sums`; do a=$(cat query_counts/$i.lines); c=$(bc -l <<< "$a/$nr_renderings"); echo "$c" | cut -b -4 >> anzahl-pro-query.spalte ; done
echo -n >  anzahl.spalte
for i in `cat unique_md5sums`; do cat query_counts/$i.lines >> anzahl.spalte ; done
echo -n >  summe.spalte
for i in `cat unique_md5sums`; do a=$(cat query_counts/$i.lines); b=$(cat durchschnitt/$i); c=$(bc -l <<< "$a*$b") ; echo "$c" | cut -b -6 >> summe.spalte ; done

paste zeit-pro-query.spalte  anzahl-pro-query.spalte single-query-durchschnitt single-query-files anzahl.spalte summe.spalte |sort -g |tac > ergebnis 

#paste summe.spalte anzahl zeit-pro-query > summe-zeit-pro-query
#sort -g summe-zeit-pro-query > summe-zeit-pro-query.sorted
#tac summe-zeit-pro-query.sorted > summe-zeit-pro-query.rsorted

#gesamtzeit 
gesamtzeit=`awk '{a+=$0}END{print a}' zeit-pro-query.spalte`

echo "done calculating gesamtzeit ($gesamtzeit) aller queries"

if [ -d slow_queries ]; then rm -rf slow_queries; fi
mkdir  slow_queries
counter=0
for i in `head ergebnis|cut -f 4 |cut -f 3 -d" "`; do 
	new_filename="$counter-$(grep $i ergebnis|cut -f 1)-$i"
	cp single_queries-with-duration/$i slow_queries/$new_filename
	let counter=$counter+1
done

if [ -d slow_exec_queries ]; then rm -rf slow_exec_queries; fi
mkdir  slow_exec_queries
counter=0
while read -r line
do
  if [ "$counter" = "10" ]; then
    break
  fi

  query_filename=$(echo "$line" | cut -f 4 |cut -f 3 -d" ")
  if grep -q "execute" single_queries-with-duration/$query_filename; then
    new_filename="$counter-$(grep $query_filename ergebnis|cut -f 1)-$query_filename"
    cp single_queries-with-duration/$query_filename slow_exec_queries/$new_filename
    let counter=$counter+1
    continue
  fi

done < "ergebnis"


echo -e "zeit query pro rendering\tanzahl runs pro rendering\teinzeldurchschnittszeit\tmd5sum\tfilename\tgesamtläufe einzelquery\tgesamtlaufzeit" > endergebnis
cat ergebnis >> endergebnis

head endergebnis
