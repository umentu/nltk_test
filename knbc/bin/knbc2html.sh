#!/bin/sh
###############################################################
# % $0 out-html/
#
# KNBC��HTML�����륹����ץȡ�
# out-html�Ͻ�����ǥ��쥯�ȥꡣ
###############################################################

# �����ѥ�����1�ξ��
SYNSEM_ANN=../corpus1/
# �����ѥ�����2�ξ��
EVAL_ANN=../corpus2/

# ɾȽ���Υơ������Υϥå��岽
echo "Reading in the Evaluation Annotation...";
cat $EVAL_ANN/*.tsv | ./nict_sentiment.perl $1

# �������Υ���ǥå����ڡ����κ���
echo "Making index pages of all articles...";
./knbc_article_index.perl $SYNSEM_ANN $1

# 1���������ʸ�Υ���ǥå����ڡ����κ���
echo "Making index pages of all sentences for each article...";
for d in `find $SYNSEM_ANN -maxdepth 1 -mindepth 1 -type d`
do
 ./knbc_sentence_index.perl $d $1
done

# 1���������ʸ�η����������̣�ط��ڡ����ȷ����ǥڡ����κ���
echo "Making annotation pages for each article...";
for d in `find $SYNSEM_ANN -maxdepth 1 -mindepth 1 -type d`
do
 ./knbc_annotation_per-article.perl $d $1
done

# 1ʸ�η����������̣�ط��ڡ����ȷ����ǥڡ����κ���
echo "Making annotation pages for each sentence...";
for f in `find $SYNSEM_ANN -maxdepth 2 -mindepth 2 -type f -name KN*-[0-9]*`
do
 ./knbc_annotation.perl $f $1
done

# index.html �� keitai.html �˥��
PWD=`pwd`
ln -s $PWD/$1/keitai.html $PWD/$1/index.html

# �������륷���ȤΥ��ԡ�
cp *.css $1/

