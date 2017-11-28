#!/bin/bash
 
### Author: Boris Guennewig & Zac Chatterton  & Bell Lee
### Date: 2017/10/19

# Modules
module load gatk/3.8.0
module load fastqc
module load trimmomatic/0.36
module load bwa/0.7.15
module load picard/2.7.1
module load samtools/1.3.1
module load fastqc/0.11.3
module load java
module load pigz
 

if [ -z $1 ]; then
    echo "Need to submit name of folder" && exit
fi

if [ -z $2 ]; then
    echo "Need to path to folder to process" && exit
fi

if [ -z $3 ]; then
    echo "Need to provide number of processors to be used e.g. 6" && exit
fi

## Define project folder

inDir="${2}"
echo "inDir= $inDir"

outDir=${inDir}"/results"
echo $outDir && mkdir -p $outDir


fastQCDir=${outDir}"/fastQC"
echo "FastQCDir is $fastQCDir" && mkdir -p $fastQCDir

fastQC_trim_Dir=${outDir}"/fastQC_trim"
echo "FastQCDir_trim is $fastQC_trim_Dir" && mkdir -p $fastQC_trim_Dir

trim_Dir=${outDir}"/fastq_trim"
echo "TrimmedDir is $trim_Dir" && mkdir -p ${trim_Dir}

## Cores best 6 so far
numcores=${3}
echo "numcores= $numcores"


## Annotations

indexDir="/project/RDS-SMS-FFbigdata-RW/local_lib/genomes/hg38_broad_bundle/"
echo "indexDir is $indexDir"

genomeDir=${indexDir}"Homo_sapiens_assembly38.fasta"
echo "genomeDir is $genomeDir"

db_snp=${indexDir}"dbsnp_146.hg38.vcf.gz"
echo $db_snp

###Check if files are there
##########################################################################################################################
##########################################################################################################################
###for fastq
##########################################################################################################################
##########################################################################################################################


minFileSize="1M"

inFile1=${inDir}"/*.read1.fq"
echo "File1 is $inFile1"

inFile2=${inDir}"/*.read2.fq"
echo "File2 is $inFile2"

find $inFile1 -type f -size $minFileSize -delete
find $inFile2 -type f -size $minFileSize -delete

if [ ! -f $inFile1 ];
then
    inFile1=${inDir}"/*R1.fastq.gz"
    find $inFile1 -type f -size $minFileSize -delete
    if [ ! -f $inFile1 ];
    then
        echo "Can't find $inFile1 fastq file"
    else
        echo "Found" $inFile1
    fi
else
    echo "Found" $inFile1
fi

if [ ! -f $inFile2 ];
then
    inFile2=${inDir}"/*R2.fastq.gz"
    find $inFile2 -type f -size $minFileSize -delete
    if [ ! -f $inFile2 ];
    then
        echo "Can't find $inFile2 fastq file"
    else
        echo "Found" $inFile2
    fi
else
    echo "Found" $inFile2
fi

##########################################################################################################################
##########################################################################################################################
### bam to fastq
##########################################################################################################################
##########################################################################################################################

if [ ! -f $inFile1 ]; 
then
        echo "fastq files not present " $inFile1
    	inFile1=${inDir}"/"${1}
    	inFile2=$inFile1
    	#find $inFile1 -type f -size $minFileSize -delete
    	#if [ ! -f $inFile1 ];
    	#then
    	#    echo "Can't find $inFile1 bam file"
    	#else
    	#    echo "Found" $inFile1
    	#fi
	echo "DEBUG $inFile1"
	echo "DEBUG #2 ${1}"
	echo "DEBUG #3 ${2}"
	echo "DEBUG #4 $(echo $inFile1 | cut -d'.' -f 1).sorted.bam"
	if [ ! -f "$(echo $inFile1 | cut -d'.' -f 1).sorted.bam" ]; 
	then
		chksorted=$(samtools view -H $inFile1 | grep "@HD")	
		if [[ $chksorted =~ "SO:coordinate" ]];
		then
    			echo "bam file is sorted"
			mv $inFile1 $(echo $inFile1 | cut -d'.' -f 1).sorted.bam
		else
                	echo "Sorting bam file"
                	java -jar /usr/local/picard/2.7.1/picard.jar SortSam \
			I=$inFile1 \
                	O=$(echo $inFile1 | cut -d'.' -f 1).sorted.bam \
                	SORT_ORDER=queryname
		fi	
        elif [[ -e $(echo $inFile1 | cut -d'.' -f 1).sorted.bam ]]; 
	then
        	echo "bam file already sorted"
        else
        	echo $inFile1" No bam file and fastq file found"
		exit 1
        fi
        if [[ -e $(echo $inFile1 | cut -d'.' -f 1).sorted.bam ]]; 
	then
                echo "generating fastq files"
                java -jar /usr/local/picard/2.7.1/picard.jar SamToFastq \
	        I=$(echo $inFile1 | cut -d'.' -f 1).sorted.bam \
                FASTQ=$(echo $inFile1 | cut -d'.' -f 1)_R1.fq \
                SECOND_END_FASTQ=$(echo $inFile2 | cut -d'.' -f 1)_R2.fq
                inFile1=$(echo $inFile1 | cut -d'.' -f 1)_R1.fq
                inFile2=$(echo $inFile2 | cut -d'.' -f 1)_R2.fq	
        else
                echo $inFile1" No sorted bam file"
		exit 1
        fi
        if [[ -e $inFile1 && $inFile2 ]]; 
	then
                echo "Compressing fastq files"
		echo "DEBUG#5"$inFile1".gz"
                pigz -p 8 $inFile1
                pigz -p 8 $inFile2
		inFile1=$inFile1".gz"
		inFile2=$inFile2".gz"
        else
                echo $inFile1" No fastq files to compress"
		exit 1
        fi
        if [[ -e $inFile1 && $inFile2 ]]; 
	then
                echo " now removing bam files"
		if [[ -e ${inDir}/$(basename $inFile1 _R1.fq.gz).bam ]];
		then
			echo "removing " ${inDir}/$(basename $inFile1 _R1.fq.gz).bam
			rm ${inDir}/$(basename $inFile1 _R1.fq.gz).bam
		fi
		echo "removing " ${inDir}/$(basename $inFile1 _R1.fq.gz).sorted.bam
                rm ${inDir}/$(basename $inFile1 _R1.fq.gz).sorted.bam
        else
        	echo $inFile1" No compressed fastq files"
		exit 1
        fi
else
        echo $inFile1" fastqs already present"
fi


##########################################################################################################################
##########################################################################################################################
###FastQC preTrim
##########################################################################################################################
##########################################################################################################################

# can skip for total/capseq rerun 2017
if [ ! -f $fastQCDir/$(basename $inFile1)_fastqc.zip ]; 
then
  echo "Running fastQC preTrim"
 
  echo "fastqc -t $numcores --outdir $fastQCDir $inFile1  $inFile2"
  echo "[TIME: fastqc postTrim]"
  time fastqc \
  -t $numcores \
  --outdir $fastQCDir \
  $inFile1  $inFile2 
else
  echo "Found" $fastQCDir/$inFile1_fastqc.zip
fi



##########################################################################################################################
##########################################################################################################################
###Trimming
##########################################################################################################################
##########################################################################################################################


# can skip for total/cap rerun 2017

if [ ! -f $trim_Dir/${1}_R1_trim.fq.gz ];
then
  echo "Running trimmomatic"
    
  echo "Running trimmomatic PE -phred33 -threads ${numcores} \
  $inFile1 $inFile2 \
  $trim_Dir/${1}_R1_trim.fq.gz $trim_Dir/${1}_R1_trim_unpaired.fq.gz \
  $trim_Dir/${1}_R2_trim.fq.gz $trim_Dir/${1}_R2_trim_unpaired.fq.gz \
  ILLUMINACLIP:/usr/local/trimmomatic/0.36/adapters//TruSeq3-PE-2.fa:2:30:10 SLIDINGWINDOW:4:20 MINLEN:40"
  echo "[TIME: trimmomatic]"
  time trimmomatic PE -phred33 -threads ${numcores} \
  $inFile1 $inFile2 \
  $trim_Dir/${1}_R1_trim.fq.gz $trim_Dir/${1}_R1_trim_unpaired.fq.gz \
  $trim_Dir/${1}_R2_trim.fq.gz $trim_Dir/${1}_R2_trim_unpaired.fq.gz \
  ILLUMINACLIP:/usr/local/trimmomatic/0.36/adapters/TruSeq3-PE-2.fa:2:30:10 SLIDINGWINDOW:4:20 MINLEN:40
  #HEADCROP:10
 else
  echo "Found" $trim_Dir/${1}_R1_trim.fq.gz
fi

###Reset inFile to the trimmed fastq's

inFile1=$trim_Dir/${1}_R1_trim.fq.gz
echo "New infile1" $inFile1

inFile2=$trim_Dir/${1}_R2_trim.fq.gz
echo "New infile2" $inFile2



##########################################################################################################################
##########################################################################################################################
###FastQC postTrim
##########################################################################################################################
##########################################################################################################################


if [ ! -f $fastQC_trim_Dir/$(basename $inFile1 .gz)_fastqc.zip ]; 
then
  echo "Running fastQC postTrim"
 
  echo "fastqc -t $numcores --outdir $fastQC_trim_Dir $inFile1  $inFile2"
  echo "[TIME: fastqc postTrim]"
  time fastqc \
  -t $numcores \
  --outdir $fastQC_trim_Dir \
  $inFile1  $inFile2 
else
  echo "Found" $fastQC_trim_Dir/$inFile1_fastqc.zip
fi


##########################################################################################################################
##########################################################################################################################
# 1. Index the reference FASTA for use with BWA
##########################################################################################################################
##########################################################################################################################

#bwa index $reference_fasta

##########################################################################################################################
##########################################################################################################################
# 2. Align reads with BWA-MEM
##########################################################################################################################
##########################################################################################################################

cd $inDir

if  [ ! -f ${outDir}/${1}_bwamem.sam ]; then
    echo "bwa mem -M -t ${numcores} ${genomeDir} ${inFile1} ${inFile2} > ${outDir}/${1}_bwamem.sam"
    echo "[TIME: bwa-mem]"
    time bwa mem -M -t ${numcores} ${genomeDir} ${inFile1} ${inFile2} > ${outDir}/${1}_bwamem.sam
else
    echo "BWA Done"
fi

find ${outDir}/${1}_bwamem.sam -type f -size $minFileSize -delete
echo "find ${outDir}/${1}_bwamem.sam -type f -size $minFileSize -delete"


in_Bam=${outDir}/${1}_bwamem.sam
echo ${in_Bam}


##########################################################################################################################
##########################################################################################################################
# 3. Add read group information, preprocess to make a clean BAM and call variants
##########################################################################################################################
##########################################################################################################################
 
# [3.1] Create unmapped uBAM
  
if  [ ! -f ${outDir}/${1}_u.bam ]; then
    echo "picard RevertSam \
    I=${in_Bam} O=${outDir}/${1}_u.bam \
    ATTRIBUTE_TO_CLEAR=XS ATTRIBUTE_TO_CLEAR=XA"
 
   echo "[TIME: picard RevertSam]"
   time picard RevertSam \
    I=${in_Bam} O=${outDir}/${1}_u.bam \
    ATTRIBUTE_TO_CLEAR=XS ATTRIBUTE_TO_CLEAR=XA
else
    echo "Create unmapped uBAM Done"
fi
 
 
# [3.2] Add read group information to uBAM
  
 
if  [ ! -f ${outDir}/${1}_rg.bam ]; then
    echo "picard AddOrReplaceReadGroups \
    I=${outDir}/${1}_u.bam O=${outDir}/${1}_rg.bam \
    RGID=altalt RGSM=altalt RGLB=wgsim RGPU=shlee RGPL=illumina"
     
   echo "[TIME: picard AddOrReplaceReadGroups]"
   time picard AddOrReplaceReadGroups \
    I=${outDir}/${1}_u.bam O=${outDir}/${1}_rg.bam \
    RGID=altalt RGSM=altalt RGLB=wgsim RGPU=shlee RGPL=illumina
else
    echo "Add read group information to uBAM Done"
fi
 
  
# [3.3] Merge uBAM with aligned BAM
  
if  [ ! -f ${outDir}/${1}_m.bam ]; then
    echo "picard MergeBamAlignment \
    ALIGNED=${in_Bam} UNMAPPED=${outDir}/${1}_rg.bam O=${outDir}/${1}_m.bam \
    R=$genomeDir \
    SORT_ORDER=unsorted CLIP_ADAPTERS=false \
    ADD_MATE_CIGAR=true MAX_INSERTIONS_OR_DELETIONS=-1 \
    PRIMARY_ALIGNMENT_STRATEGY=MostDistant \
    UNMAP_CONTAMINANT_READS=true \
    ATTRIBUTES_TO_RETAIN=XS ATTRIBUTES_TO_RETAIN=XA"
     
   echo "[TIME: picard MergeBamAlignment]"
   time picard MergeBamAlignment \
    ALIGNED=${in_Bam} UNMAPPED=${outDir}/${1}_rg.bam O=${outDir}/${1}_m.bam \
    R=$genomeDir \
    SORT_ORDER=unsorted CLIP_ADAPTERS=false \
    ADD_MATE_CIGAR=true MAX_INSERTIONS_OR_DELETIONS=-1 \
    PRIMARY_ALIGNMENT_STRATEGY=MostDistant \
    UNMAP_CONTAMINANT_READS=true \
    ATTRIBUTES_TO_RETAIN=XS ATTRIBUTES_TO_RETAIN=XA
else
    echo "Merge uBAM with aligned BAM Done"
fi

# # [3.4] Base Recalibrator Report
  
#   if  [ ! -f ${outDir}/${1}_mbqsr.bam ]; then
#     echo "gatk -T BaseRecalibrator \
#     -I ${outDir}/${1}_m.bam \
#     -R $genomeDir \
#     --knownSites $db_snp \
#     -o ${outDir}/recalibration_report.grp"
      
#     gatk -T BaseRecalibrator \
#     -I ${outDir}/${1}_m.bam \
#     -R $genomeDir \
#     --knownSites $db_snp \
#     -o ${outDir}/recalibration_report.grp
# else
#     echo "Perform Base Quality Score Recalibration (BQSR) Done"
# fi
 
  
   
# # [3.5] Perform Base Quality Score Recalibration (BQSR)
   
#  if  [ ! -f ${outDir}/${1}_mbqsr.bam ]; then
#     echo " gatk -T PrintReads \
#    -R $genomeDir \
#    -I ${outDir}/${1}_m.bam \
#    -BQSR ${outDir}/recalibration_report.grp \
#    -o ${outDir}/${1}_mbqsr.bam"
      
#     gatk -T PrintReads \
#    -R $genomeDir \
#    -I ${outDir}/${1}_m.bam \
#    -BQSR ${outDir}/recalibration_report.grp \
#    -o ${outDir}/${1}_mbqsr.bam
# else
#     echo "Perform Base Quality Score Recalibration (BQSR) Done"
# fi
  
   
# [3.6] Flag duplicate reads
   
if  [ ! -f ${outDir}/${1}_md.bam ]; then
    echo "picard MarkDuplicates \
    INPUT=${outDir}/${1}_m.bam OUTPUT=${outDir}/${1}_md.bam METRICS_FILE=${outDir}/${1}_md.bam.txt \
    OPTICAL_DUPLICATE_PIXEL_DISTANCE=2500 ASSUME_SORT_ORDER=queryname"

   echo "[TIME: picard MarkDuplicates]"
   time picard MarkDuplicates \
   INPUT=${outDir}/${1}_m.bam \
   OUTPUT=${outDir}/${1}_md.bam \
   METRICS_FILE=${outDir}/${1}_md.bam.txt \
   OPTICAL_DUPLICATE_PIXEL_DISTANCE=2500 \
   ASSUME_SORT_ORDER=queryname

else
    echo "Flag duplicate reads Done"
fi
  
# [3.7] Coordinate sort, fix NM and UQ tags and index for clean BAM
   
if  [ ! -f ${outDir}/${1}_snaut.bam ]; then
    #echo "set -o pipefail
    echo "picard SortSam \
    INPUT=${outDir}/${1}_md.bam OUTPUT=/dev/stdout SORT_ORDER=coordinate | \
    picard SetNmAndUqTags \
    INPUT=/dev/stdin OUTPUT=${outDir}/${1}_snaut.bam \
    CREATE_INDEX=true R=$genomeDir"
      
    #set -o pipefail
    echo "[TIME: picard SortSam]"
    time picard SortSam \
    INPUT=${outDir}/${1}_md.bam OUTPUT=/dev/stdout SORT_ORDER=coordinate | \
    picard SetNmAndUqTags \
    INPUT=/dev/stdin OUTPUT=${outDir}/${1}_snaut.bam \
    CREATE_INDEX=true R=$genomeDir
else
    echo "Coordinate sort, fix NM and UQ tags and index for clean BAM Done"
fi
  
   
# [3.8] Call SNP and indel variants in emit reference confidence (ERC) mode per sample using HaplotypeCaller
  
if  [ ! -f ${outDir}/${1}_hc.bam ]; then
    echo " gatk -T HaplotypeCaller \
    -R $genomeDir \
    -o ${outDir}/${1}.g.vcf -I ${outDir}/${1}_snaut.bam \
    -ERC GVCF --max_alternate_alleles 3 --read_filter OverclippedRead \
    --emitDroppedReads -bamout ${outDir}/${1}_hc.bam"
      
    echo "[TIME: gatk HaplotypeCaller]"
    time gatk -T HaplotypeCaller \
    -R $genomeDir \
    -o ${outDir}/${1}.g.vcf -I ${outDir}/${1}_snaut.bam \
    -ERC GVCF --max_alternate_alleles 3 --read_filter OverclippedRead \
    --emitDroppedReads -bamout ${outDir}/${1}_hc.bam
else
    echo "Call SNP and indel variants in emit reference confidence \(ERC\) mode per sample using HaplotypeCaller Done"
fi
  
   

asd() {
cat <<"EOT"



                      _           _        _____                      _      _           _
    /\               | |         (_)      / ____|                    | |    | |         | |
   /  \   _ __   __ _| |_   _ ___ _ ___  | |     ___  _ __ ___  _ __ | | ___| |_ ___  __| |
  / /\ \ | '_ \ / _` | | | | / __| / __| | |    / _ \| '_ ` _ \| '_ \| |/ _ \ __/ _ \/ _` |
 / ____ \| | | | (_| | | |_| \__ \ \__ \ | |___| (_) | | | | | | |_) | |  __/ ||  __/ (_| |
/_/    \_\_| |_|\__,_|_|\__, |___/_|___/  \_____\___/|_| |_| |_| .__/|_|\___|\__\___|\__,_|
                         __/ |                                 | |
                        |___/                                  |_|
EOT
}

asd
echo "Analysis finished. Have a good day"

if [ $? -eq 0 ]
then
  echo "Successfully completed"
  exit 0
else
  echo "Script failed" >&2
  exit 1
fi

##########################################################################################################################
##########################################################################################################################
###Script done!
##########################################################################################################################
##########################################################################################################################
