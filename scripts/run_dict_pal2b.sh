#!/usr/bin/env bash
#sbatch -o slp.log -e slp.log -p 3gpuq --gres=gpu:3   --mem=20GB run_nist_cn_en_pal.sh


. path.sh

#/cm/shared/apps/sockeye/1.15.1/lib/python3.6/site-packages/sockeye/train.py

#config init
na=nmt_model_nist_cn_en.1a
ngpus=3
mb=10
kvstore=device
idim=47

. parse_options.sh || exit 1;

set -x
#config after
fmb=`echo "$ngpus * $mb"|bc`
#fmb=$mb
#scp="/fgfs/users/zhc00/works/ctc/allctc/mxnet/nmt.exp/tmp/feats.scp"
dir=exp/$na/train
ldir=exp/$na/lock

ie_size=`echo "$idim - 4"| bc`

#begin
hostname | tee -a exp/$na/s.id
nvidia-smi | tee -a exp/$na/s.id

mkdir -p $dir $ldir
scp="../nmt.exp/tmp/feats.scp"
lab="../nmt.exp/tmp/label.txt"

#                       --use-tensorboard \
python3 -m sockeye.train -s $scp \
                        --overwrite-output \
                        --kvstore $kvstore \
                        -t $lab \
                        -vs $scp \
                        -vt $lab \
                        --num-embed $idim:620 \
                        --rnn-num-hidden 1000 \
                        --rnn-attention-type mlp \
                        --max-seq-len 400 \
                        -o $dir \
                        --device-ids -$ngpus \
                        --lock-dir $ldir \
                        --num-words $ie_size:30275 \
                        --rnn-cell-type gru \
                        --batch-size $fmb \
                        --checkpoint-frequency 2000 \
                        --learning-rate-scheduler-type fixed-rate-inv-sqrt-t \
                        --initial-learning-rate 0.0005 
#                        --learning-rate-reduce-factor 1.0 
#                         --learning-rate-decay-param-reset False \
#                        --learning-rate-decay-optimizer-states-reset off \                       



