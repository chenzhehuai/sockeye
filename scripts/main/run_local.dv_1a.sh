
. path.sh

kvstore=dist_device_sync
ngpus=3
mb=162
script=scripts/run_dict_pal2.sh
na=nmt_model_dict.1a
queue=3gpuq
datadir=data/swb.plstm_ctc5_wb.f.d2w.2d.train_tr90-htk.mxnet/
addin=""
translate_addin=""
tsuffix=""
tr_stage=0

. parse_options.sh || exit 1;

na=$na.$mb.$ngpus.$kvstore
dir=exp/$na
scp=$datadir/tr/feats.scp
lab=$datadir/tr/train.labels.ctc
vscp=$datadir/cv/feats.scp
vlab=$datadir/cv/train.labels.ctc
test_scp=$datadir/eval2000/feats.scp

mkdir -p $dir

bash \
    $script \
    --na $na --ngpus $ngpus --mb $mb --kvstore $kvstore \
    --scp $scp --lab $lab --vscp $vscp --vlab $vlab --test_scp $test_scp --stage $tr_stage \
    --addin "$addin" \
    --translate_addin "$translate_addin" \
    --tsuffix "$tsuffix" \
    2>&1 | tee   $dir/s.log
echo $dir/s.log
