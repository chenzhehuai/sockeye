# Copyright 2017 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"). You may not
# use this file except in compliance with the License. A copy of the License
# is located at
#
#     http://aws.amazon.com/apache2.0/
#
# or in the "license" file accompanying this file. This file is distributed on
# an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
# express or implied. See the License for the specific language governing
# permissions and limitations under the License.

"""
Implements a thin wrapper around Translator to compute BLEU scores on (a sample of) validation data during training.
"""
import logging
import os
import random
import time
import argparse
from typing import Dict, Optional

import mxnet as mx

import sockeye.output_handler
from . import evaluate
from . import chrf
from . import constants as C
from . import data_io_kaldi as data_io
from . import inference
from . import utils
from . import vocab

logger = logging.getLogger(__name__)


class CheckpointDecoder:
    """
    Decodes a (random sample of a) dataset using parameters at given checkpoint and computes BLEU against references.

    :param context: MXNet context to bind the model to.
    :param inputs: Path to file containing input sentences.
    :param references: Path to file containing references.
    :param model: Model to load.
    :param max_input_len: Maximum input length.
    :param beam_size: Size of the beam.
    :param bucket_width_source: Source bucket width.
    :param bucket_width_target: Target bucket width.
    :param length_penalty_alpha: Alpha factor for the length penalty
    :param length_penalty_beta: Beta factor for the length penalty
    :param softmax_temperature: Optional parameter to control steepness of softmax distribution.
    :param max_output_length_num_stds: Number of standard deviations as safety margin for maximum output length.
    :param ensemble_mode: Ensemble mode: linear or log_linear combination.
    :param sample_size: Maximum number of sentences to sample and decode. If <=0, all sentences are used.
    :param random_seed: Random seed for sampling. Default: 42.
    """

    def __init__(self,
                 context: mx.context.Context,
                 inputs: str,
                 references: str,
                 model: str,
                 args: argparse.Namespace,
                 max_input_len: Optional[int] = None,
                 beam_size: int = C.DEFAULT_BEAM_SIZE,
                 bucket_width_source: int = 10,
                 length_penalty_alpha: float = 1.0,
                 length_penalty_beta: float = 0.0,
                 softmax_temperature: Optional[float] = None,
                 max_output_length_num_stds: int = C.DEFAULT_NUM_STD_MAX_OUTPUT_LENGTH,
                 ensemble_mode: str = 'linear',
                 sample_size: int = -1,
                 random_seed: int = 42,
                 input_dim: int = 1) -> None:
        self.context = context
        self.max_input_len = max_input_len
        self.max_output_length_num_stds = max_output_length_num_stds
        self.ensemble_mode = ensemble_mode
        self.beam_size = beam_size
        self.batch_size = int(args.batch_size/3) #per card
        self.bucket_width_source = bucket_width_source
        self.length_penalty_alpha = length_penalty_alpha
        self.length_penalty_beta = length_penalty_beta
        self.softmax_temperature = softmax_temperature
        self.model = model
        self.input_dim=input_dim
        self.target_sentences=None
        self.args=args

        input_sentences = list(data_io.read_content(inputs, "scp"))
        target_sentences = list(data_io.read_content(references, "lab"))
        if sample_size <= 0:
            sample_size = len(input_sentences)
        if sample_size < len(input_sentences):
            # custom random number generator to guarantee the same samples across runs in order to be able to
            # compare metrics across independent runs
            random_gen = random.Random(random_seed)
            self.input_sentences, self.target_sentences_a = zip(
                *random_gen.sample(list(zip(input_sentences, target_sentences)),
                                   sample_size))
        else:
            self.input_sentences, self.target_sentences_a = input_sentences, target_sentences

        logger.info("Created CheckpointDecoder(max_input_len=%d, beam_size=%d, model=%s, num_sentences=%d)",
                    max_input_len if max_input_len is not None else -1,
                    beam_size, model, len(self.input_sentences))


    def decode_and_evaluate(self,
                            checkpoint: Optional[int] = None,
                            output_name: str = os.devnull) -> Dict[str, float]:
        """
        Decodes data set and evaluates given a checkpoint.

        :param checkpoint: Checkpoint to load parameters from.
        :param output_name: Filename to write translations to. Defaults to /dev/null.
        :return: Mapping of metric names to scores.
        """
        models, vocab_source, vocab_target = inference.load_models(self.context,
                                                                   self.max_input_len,
                                                                   self.beam_size,
                                                                   self.batch_size,
                                                                   [self.model],
                                                                   [checkpoint],
                                                                   softmax_temperature=self.args.softmax_temperature,
                                                                   max_output_length_num_stds=self.max_output_length_num_stds,
                                        input_dim=self.input_dim)
        if not self.target_sentences:
            vocab_target_inv = vocab.reverse_vocab(vocab_target)
            self.target_sentences=[" ".join([vocab_target_inv[j] for j in i]) for i in self.target_sentences_a]
        translator = inference.Translator(self.context,
                                          self.ensemble_mode,
                                          self.bucket_width_source,
                                          inference.LengthPenalty(self.args.length_penalty_alpha, self.args.length_penalty_beta),
                                          models,
                                          vocab_source,
                                          vocab_target,
                                          input_dim=self.input_dim)
        trans_wall_time = 0.0
        translations = []
        with data_io.smart_open(output_name, 'w') as output:
            handler = sockeye.output_handler.StringOutputHandler(output)
            tic = time.time()
            trans_inputs = [translator.make_input(i, line) for i, line in enumerate(self.input_sentences)]
            trans_outputs = translator.translate(trans_inputs)
            trans_wall_time = time.time() - tic
            for trans_input, trans_output in zip(trans_inputs, trans_outputs):
                handler.handle(trans_input, trans_output)
                translations.append(trans_output.translation)
        avg_time = trans_wall_time / len(self.input_sentences)
        print(translations[0])
        print(self.target_sentences[0])
        # TODO(fhieber): eventually add more metrics (METEOR etc.)
        return {C.BLEU_VAL: evaluate.raw_corpus_bleu(hypotheses=translations,
                                                     references=self.target_sentences,
                                                     offset=0.01),
                C.CHRF_VAL: chrf.corpus_chrf(hypotheses=translations,
                                             references=self.target_sentences,
                                             trim_whitespaces=True),
                C.AVG_TIME: avg_time}
