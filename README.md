# Otool解析工具：检查Mach-O文件中无用的类和方法

## 概述

项目界面使用的是[LinkMap](https://github.com/huanxsd/LinkMap)项目，只是其中的逻辑修改了，主要是为了自己用来分析Mach-O文件。分享出来大家参考使用。

这个工具是专为用来分析项目的Mach-O文件，检查Mach-O文件中无用的类和方法。

## 使用说明

1、打开LinkMap.xcodeproj，并运行，就可以看到工具界面

![WX20210511-133124.png](https://i.loli.net/2021/05/11/te8ifD5CYp7awdP.png)

2、点击“选择文件”按钮，选择Otool生成的文件（如何生成Otool详见下方的：如何获得Otool文件）

3、点击“开始”按钮，就可以看到未使用的类

![WX20210511-133213.png](https://i.loli.net/2021/05/11/ouBPfCzAHJIGTRa.png)

4、勾选解析方法，点击“开始”按钮，就可以看到未使用的方法

![WX20210511-145816.png](https://i.loli.net/2021/05/11/RwUVL6YzeFSjrk8.png)

4、点击“输出文件”，可以将结果输出到文本文档中


## 如何获得Otool文件

1. Xcode打包导出ipa，把ipa后缀改为zip，然后解压缩，取出.app中的mach-o文件
2. 打开 terminal，运行命令：otool -arch arm64 -ov XXX > XXX.txt，其中XXX是mach-o文件的名字
3. 回到本应用，点击“选择文件”，打开刚刚生成XXX.txt文件
4. 点击“开始”，解析文件
5. 点击“输出文件”，得到解析后的文件
6. 勾选“解析方法”，然后点击“开始”。得到的是未使用的方法


## 参考

[LinkMap](https://github.com/huanxsd/LinkMap)

## 联系我

如有问题或建议欢迎通过邮件联系我
a525325614@163.com

## 最后

如果喜欢，请顺手我一个star吧~  ：）