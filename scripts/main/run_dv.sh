
. path.sh

kvstore=dist_device_sync
ngpus=3
mb=162
script=scripts/run_dict_pal2.sh
na=nmt_model_dict.1a
queue=3gpuq

. parse_options.sh || exit 1;

na=$na.$mb.$ngpus.$kvstore
dir=exp/$na


mkdir -p $dir

sbatch -o $dir/s.log -e $dir/s.log -p $queue --gres=gpu:3   --mem=40GB  \
    $script \
    --na $na --ngpus $ngpus --mb $mb --kvstore $kvstore \
    | tee   $dir/s.id
echo $dir/s.log
