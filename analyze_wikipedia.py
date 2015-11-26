# -*- coding: utf-8 -*-

import os.path

import wikipedia

import nltk
from nltk.corpus.reader import *
from nltk.corpus.reader.util import *
from nltk.text import Text

import MeCab

# テキストを設置するディレクトリ
TEXT_DIR = os.path.abspath(os.path.dirname(__file__)) + "/text/"

# 日本語wikipediaを指定
wikipedia.set_lang("jp")

# ！＞。で終わる文字列を文として認識されるように定義
jp_sent_tokenizer = nltk.RegexpTokenizer('[^　「」！？。]*[！？。]')

# Unicode の範囲
#  ひらがなについては [ぁ-ん]
#  カタカナについては [ァ-ン]
#  漢字については U+4E00 ～ U+9FFF
# を指定

jp_chartype_tokenizer = nltk.RegexpTokenizer(
    u'([ぁ-んー]+|[ァ-ンー]+|[\u4e00-\u9FFF]+|[^ぁ-んァ-ンー\u4e00-\u9FFF]+)')


# MeCabによる形態素解析
tagger = MeCab.Tagger("-Ochasen")


def morphological_analysis_text(filename):
    """指定したテキストファイル内で使用されている単語を形態素解析して出力する"""
    try:
        f = open(TEXT_DIR + filename + ".txt", "r")
    except IOError:
        print("%s can't open!" % filename + ".txt")

    plain_text = PlaintextCorpusReader(TEXT_DIR,
                                       filename + ".txt",
                                       encoding="utf-8",
                                       para_block_reader=read_line_block,
                                       sent_tokenizer=jp_chartype_tokenizer,
                                       word_tokenizer=jp_chartype_tokenizer)

    node = tagger.parseToNode(plain_text.raw())
    node = node.next
    result = []
    while node:

        result.append(
            {
             "word": node.surface,
             "feature": node.feature
             })
        node = node.next

    return result


def get_frequency_of_word(filename):
    """指定したテキストファイル内で使用されている単語の出現頻度をカウントする"""

    try:
        f = open(TEXT_DIR + filename + ".txt", "r")
    except IOError:
        print("%s can't open!" % filename + ".txt")

    text = nltk.filestring(open(TEXT_DIR + filename + ".txt"))
    word_token = nltk.word_tokenize(text)
    freqdist = nltk.FreqDist(word_token)

    return freqdist

def get_wikipedia_page(word):
    """Wikipediaから情報を取得し、テキストファイルに保存する"""

    with open(TEXT_DIR + word + ".txt", mode='w') as f:
        page = wikipedia.page(word)
        f.write(page.content)
 

if __name__ == '__main__':
    get_frequency_of_word("大滝詠一")
