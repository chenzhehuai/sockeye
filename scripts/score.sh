#!/bin/bash

#bash scripts/score.sh $tdir `dirname $test_scp` $dataset


stage=0

[ -f ./path.sh ] && . ./path.sh; # source the path.
. parse_options.sh || exit 1;

dir=$1
data=$2
dataset=$3

ra=$dir/rst.1

if [ $stage -le 1 ]; then
    awk 'NR==FNR{if (NF>0){d[NR]=$0}}NR!=FNR{if (d[FNR]==""){d[FNR]="uhhuh"}print $1,d[FNR]}'  $dir/rst.raw $data/feats.scp > $ra
fi

if [ $stage -le 2 ]; then
awk '{st=0.1;na=$1;c=0;for (i=2;i<=NF;i++){print na,1,c,st,$i;c+=st}}'  $ra | \
    utils/convert_ctm.pl $data/segments $data/reco2file_and_channel - \
    > $dir/ctm.raw

    x=$dir/ctm
    cp $dir/ctm.raw $x

    cp $x $dir/tmpf;
    cat $dir/tmpf | grep -i -v -E '\[NOISE|LAUGHTER|VOCALIZED-NOISE\]' | \
    grep -i -v -E '<UNK>' | \
    grep -i -v -E ' (UH|UM|EH|MM|HM|AH|HUH|HA|ER|OOF|HEE|ACH|EEE|EW)$' | \
    grep -v -- '-$' > $x;
    python local/map_acronyms_ctm.py -i $x -o $x.mapped -M data/local/dict_nosp/acronyms.map
    cp $x $x.bk

    hubscr=$KALDI_ROOT/tools/sctk/bin/hubscr.pl
    hubdir=`dirname $hubscr`

    cp $x.mapped  $x
    cp $data/stm  $dir/stm
    $hubscr -p $hubdir -v -V -l english -h hub5 -g $data/glm -r $dir/stm $x || exit 1

        grep -v '^en_' $data/stm > $dir/stm.swbd
        grep -v '^en_' $dir/ctm > $dir/ctm.swbd 
        $hubscr -p $hubdir -V -l english -h hub5 -g $data/glm -r $dir/stm.swbd $dir/ctm.swbd || exit 1;

        grep -v '^sw_' $data/stm > $dir/stm.callhm
        grep -v '^sw_' $dir/ctm > $dir/ctm.callhm
        $hubscr -p $hubdir -V -l english -h hub5 -g $data/glm -r $dir/stm.callhm $dir/ctm.callhm || exit 1;


fi

if [ $stage -le 3 ]; then
    x=$dir/ali.all.3
    cat $ra | grep -i -v -E '\[NOISE|LAUGHTER|VOCALIZED-NOISE\]' | \
    grep -i -v -E '<UNK>' | \
    grep -i -v -E ' (UH|UM|EH|MM|HM|AH|HUH|HA|ER|OOF|HEE|ACH|EEE|EW)$' | \
    grep -v -- '-$' > $x;
    awk '{printf $1" ";for (i=2;i<=NF;i++){wd=tolower($i);gsub(""," ",wd);printf wd" # "}print ""}' $x > $dir/ali.all.4
    awk '{printf $1" ";for (i=2;i<=NF;i++){wd=tolower($i);gsub(""," ",wd);printf wd" # "}print ""}' $data/text > $dir/text.4
     compute-wer --mode=all --text ark:$dir/text.4 ark:$dir/ali.all.4 | tee $dir/cer
fi

grep Sum $dir/*sw*sys
