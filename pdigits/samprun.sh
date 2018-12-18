#!/bin/bash
. path.sh


#Nikhil Gupta



################################################
#            SETTING DIRECTORIES               #
################################################     
                   
train_dir=data/train
test_dir=data/test

exp_dir=exp
lang_dir=data/lang_bigram
decode_dir=decode
graph_dir=graph

train_nj=4
decode_nj=4

train_decode_cmd=run.pl



#################################################
#               SETTING SWITCHES                #
#################################################


lm=1
mfcc=1
mono=1
tri1=1
tri2=1
tri3=1
tri4=1
sgmm=1

###################################################

###################################################



if [ $lm -eq 1 ]; then
echo "----------------------------------------------"
echo "        Creating Language Model               "
echo "----------------------------------------------"

         ./Create_ngram_LM.sh

fi

if [ $mfcc -eq 1 ]; then

echo "----------------------------------------------"
echo "     MFCC COMPUTATION and CMVN VALIDATION     "
echo "----------------------------------------------"


  steps/make_mfcc.sh --nj $train_nj --cmd $train_decode_cmd --write-utt2num-frames true $train_dir exp/make_mfcc/train mfcc_feats/train
  steps/make_mfcc.sh --nj $decode_nj --cmd $train_decode_cmd --write-utt2num-frames true $test_dir exp/make_mfcc/test mfcc_feats/test

  steps/compute_cmvn_stats.sh $train_dir exp/make_mfcc/train mfcc_feats/train
  steps/compute_cmvn_stats.sh $test_dir exp/make_mfcc/test mfcc_feats/test

fi

if [ $mono -eq 1 ]; then

echo "**************************************************"
echo  "      MONOPHONE TRAINING AND TESTING             "
echo "**************************************************"

  steps/train_mono.sh --nj $train_nj --cmd $train_decode_cmd $train_dir $lang_dir exp/mono

   utils/mkgraph.sh --mono $lang_dir exp/mono exp/mono/graph

   steps/decode.sh --nj $decode_nj --cmd $train_decode_cmd exp/mono/graph $test_dir exp/mono/$decode_dir

fi

if [ $tri1 -eq 1 ]; then

echo "**************************************************"
echo  "     TRI-1 TRAINING AND TESTING (DELTA)          "
echo "**************************************************"
  
  steps/align_si.sh --boost-silence 1.25 --nj $train_nj --cmd $train_decode_cmd $train_dir $lang_dir exp/mono/ exp/mono_ali

   steps/train_deltas.sh --cmd $train_decode_cmd 2500 30000 $train_dir $lang_dir exp/mono_ali exp/tri1

   utils/mkgraph.sh $lang_dir exp/tri1/ exp/tri1/graph

   steps/decode.sh --nj $decode_nj --cmd $train_decode_cmd exp/tri1/graph $test_dir exp/tri1/$decode_dir


fi

if [ $tri2 -eq 1 ]; then

 echo "**************************************************"
 echo " TRI-2 TRAINING AND TESTING (DELTA + DELTA-DELTA) "
 echo "**************************************************"

 steps/align_si.sh --nj $train_nj --cmd $train_decode_cmd $train_dir $lang_dir exp/tri1/ exp/tri1_ali 

 steps/train_deltas.sh --cmd $train_decode_cmd 2500 30000 $train_dir $lang_dir exp/tri1_ali exp/tri2

 utils/mkgraph.sh $lang_dir exp/tri2 exp/tri2/graph

 steps/decode.sh --nj $decode_nj --cmd $train_decode_cmd exp/tri2/graph $test_dir exp/tri2/$decode_dir

 steps/align_si.sh --nj $train_nj --cmd $train_decode_cmd $train_dir $lang_dir exp/tri2 exp/tri2_ali

fi

if [ $tri3 -eq 1 ]; then

echo "**************************************************"
echo "         TRI-3 TRAINING AND TESTING (LDA+MLLT)    "
echo "**************************************************"

  steps/train_lda_mllt.sh --cmd $train_decode_cmd 2000 16000 $train_dir $lang_dir exp/tri2_ali/ exp/tri3

   utils/mkgraph.sh $lang_dir/ exp/tri3 exp/tri3/graph

   steps/decode.sh --cmd $train_decode_cmd --nj 3 exp/tri3/graph/ $test_dir exp/tri3/$decode_dir

   steps/align_si.sh --nj $train_nj --cmd $train_decode_cmd --use-graphs true $train_dir $lang_dir exp/tri3 exp/tri3_ali

fi


if [ $tri4 -eq 1 ]; then

echo "*****************************************************"
echo "      TRI-4 TRAINING AND TESTING (LDA+MLLT+SAT)      "
echo "*****************************************************"

steps/train_sat.sh --cmd $train_decode_cmd 2000 16000 $train_dir $lang_dir exp/tri3 exp/tri4

utils/mkgraph.sh $lang_dir exp/tri4 exp/tri4/graph

steps/decode_fmllr.sh --nj $decode_nj --cmd $train_decode_cmd exp/tri4/graph $test_dir exp/tri4/$decode_dir

fi

if [ $sgmm -eq 1 ]; then

echo "*****************************************************"
echo "                SGMM  TRAINING AND TESTING           " 
echo "*****************************************************"

steps/align_fmllr.sh --nj $train_nj --cmd $train_decode_cmd $train_dir $lang_dir exp/tri4 exp/tri4_ali

steps/train_ubm.sh --cmd $train_decode_cmd 700 $train_dir $lang_dir exp/tri4_ali exp/ubm

steps/train_sgmm2.sh --cmd $train_decode_cmd 10000 7000 $train_dir $lang_dir exp/tri4_ali exp/ubm/final.ubm exp/sgmm

utils/mkgraph.sh $lang_dir exp/sgmm exp/sgmm/graph

steps/decode_sgmm2.sh --nj $train_nj --cmd $train_decode_cmd --transform-dir exp/tri4/$decode_dir exp/sgmm/graph $test_dir exp/sgmm/$decode_dir

steps/align_sgmm2.sh --nj $train_nj --cmd $train_decode_cmd --transform-dir exp/tri4_ali --use-graphs true --use-gselect true $train_dir $lang_dir exp/sgmm exp/sgmm_ali

fi

echo "****************************************************"
echo "     TRAINING AND TESTING FINISHED                  "
echo "****************************************************"






