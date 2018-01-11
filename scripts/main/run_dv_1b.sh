
. path.sh

kvstore=dist_device_sync
ngpus=3
mb=162
script=scripts/run_dict_pal2.sh
na=nmt_model_dict.1a
queue=3gpuq
datadir=data/swb.plstm_ctc5_wb.f.d2w.2d.train_tr90-htk.mxnet/
addin=""

. parse_options.sh || exit 1;

na=$na.$mb.$ngpus.$kvstore
dir=exp/$na
scp=$datadir/tr/feats.scp
lab=$datadir/tr/train.labels
vscp=$datadir/cv/feats.scp
vlab=$datadir/cv/train.labels
test_scp=$datadir/eval2000/feats.scp

mkdir -p $dir

sbatch -o $dir/s.log -e $dir/s.log -p $queue --gres=gpu:3   --mem=100GB  \
    $script \
    --na $na --ngpus $ngpus --mb $mb --kvstore $kvstore \
    --scp $scp --lab $lab --vscp $vscp --vlab $vlab --test_scp $test_scp \
    --addin "$addin" \
    | tee   $dir/s.id
echo $dir/s.log
