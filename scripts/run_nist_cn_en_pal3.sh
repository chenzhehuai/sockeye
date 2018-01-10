#!/usr/bin/env bash
#sbatch -o slp.log -e slp.log -p 3gpuq --gres=gpu:3   --mem=20GB run_nist_cn_en_pal.sh


. path.sh

#/cm/shared/apps/sockeye/1.15.1/lib/python3.6/site-packages/sockeye/train.py

#config init
na=nmt_model_nist_cn_en.1a
ngpus=3
mb=80
kvstore=device

. parse_options.sh || exit 1;

set -x
#config after
#fmb=`echo "$ngpus * $mb"|bc`
fmb=$mb
dir=exp/$na/train
ldir=exp/$na/lock



#begin
hostname | tee -a exp/$na/s.id
nvidia-smi | tee -a exp/$na/s.id

mkdir -p $dir $ldir
#                       --use-tensorboard \
python3 ../incubator-mxnet/tools/launch.py --cluster=local -n 1 \
" python3 -m sockeye.train -s data.nist/train.cn \
                        --overwrite-output \
                        --kvstore $kvstore \
                        -t data.nist/train.en \
                        -vs data.nist/nist06.cn \
                        -vt data.nist/nist06.en \
                        --num-embed 620 \
                        --rnn-num-hidden 1000 \
                        --rnn-attention-type mlp \
                        --max-seq-len 50 \
                        -o $dir \
                        --device-ids -$ngpus \
                        --lock-dir $ldir \
                        --num-words 30000 \
                        --rnn-cell-type gru \
                        --batch-size $fmb \
                        --checkpoint-frequency 2000 \
                        --learning-rate-scheduler-type fixed-rate-inv-sqrt-t \
                        --initial-learning-rate 0.0005 \
                        "
#                        --learning-rate-reduce-factor 1.0 
#                         --learning-rate-decay-param-reset False \
#                        --learning-rate-decay-optimizer-states-reset off \                       



