#!/usr/bin/env bash
#sbatch -o slp.log -e slp.log -p 3gpuq --gres=gpu:3   --mem=20GB run_nist_cn_en_pal.sh


#. path_debug.sh
. path.sh

#/cm/shared/apps/sockeye/1.15.1/lib/python3.6/site-packages/sockeye/train.py

#config init
stage=0
na=nmt_model_nist_cn_en.1a
ngpus=3
mb=10
kvstore=device
idim=47
scp="../nmt.exp/tmp/feats.scp"
lab="../nmt.exp/tmp/label.ctc.txt"
vscp="../nmt.exp/tmp/feats.scp"
vlab="../nmt.exp/tmp/label.ctc.txt"
test_scp="../nmt.exp/tmp/feats.scp"
addin=""

. parse_options.sh || exit 1;

set -x
#config after
fmb=`echo "$ngpus $mb"|awk '{print $1*$2}'`
#fmb=$mb
#scp="/fgfs/users/zhc00/works/ctc/allctc/mxnet/nmt.exp/tmp/feats.scp"
dir=exp/$na/train
tdir=exp/$na/test
ldir=exp/$na/lock

ie_size=`echo "$idim 4"| awk '{print $1-$2}'`

#begin
hostname | tee -a exp/$na/s.id
nvidia-smi | tee -a exp/$na/s.id

mkdir -p $dir $ldir

dataset=$scp
dataset=`dirname $dataset`
dataset=`dirname $dataset`

vocab=$dir/../vocab.trg.json.i

if [ $stage -le 0 ]; then
awk 'BEGIN{id=0;printf "{";st=1;print "";printf "\"<pad>\": "id"";id++;print ",";printf "\"<unk>\": "id"";id++;print ",";printf "\"<s>\": "id"";id++;print ",";printf "\"</s>\": "id"";id++}$0~"<unk>"{$1="<unk2>"}{print ",";printf "\""$1"\": "id"";id++}END{print"\n}"}' $dataset/nn.osym > $vocab
#                       --use-tensorboard \
python3 -m sockeye.train -s $scp \
                        --overwrite-output \
                        --kvstore $kvstore \
                        -t $lab \
                        -vs $vscp \
                        -vt $vlab \
                        --metrics perplexity accuracy \
                        --source-vocab $vocab \
                        --num-embed $idim:620 \
                        --rnn-num-hidden 1000 \
                        --rnn-attention-type mlp \
                        --max-seq-len 500 \
                        -o $dir \
                        --device-ids -$ngpus \
                        --lock-dir $ldir \
                        --num-words $ie_size:30275 \
                        --rnn-cell-type gru \
                        --batch-size $fmb \
                        --checkpoint-frequency 2000 \
                        --learning-rate-scheduler-type fixed-rate-inv-sqrt-t \
                        --initial-learning-rate 0.0005 \
                        $addin \
                        ;
#                        --learning-rate-reduce-factor 1.0 
#                         --learning-rate-decay-param-reset False \
#                        --learning-rate-decay-optimizer-states-reset off \                       
python3 get_parm.py $dir/params.00001 > $dir/num.parms
fi


if [ $stage -le 1 ]; then
mkdir -p $tdir
python3 -m sockeye.translate --input-dim $idim -m $dir --input $test_scp --output $tdir/rst.raw 2>&1 | tee $tdir/rst.log

fi

if [ $stage -le 2 ]; then
tail  $tdir/rst.raw
#scoring
bash scripts/score.sh $tdir `dirname $test_scp` $dataset
fi
