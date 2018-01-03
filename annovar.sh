#!/bin/bash
 
### Author: Zac Chatterton & Boris Guennewig
### Date: 2017/11/28

# Modules
module load annovar/20170716

if [ -z $1 ]; then
    echo "Need to submit name of folder" && exit
fi

if [ -z $2 ]; then
    echo "Need to path to folder to process" && exit
fi

## Define project folder
inDir="${2}"
echo "inDir= $inDir"

outDir=${inDir}"/annovar"
echo $outDir && mkdir -p $outDir

numcores=${3}
echo "numcores= $numcores"

## Annotations
indexDir="/project/RDS-SMS-FFbigdata-RW/local_lib/genomes/hg38_broad_bundle/"
echo "indexDir is $indexDir"

genomeDir=${indexDir}"Homo_sapiens_assembly38.fasta"
echo "genomeDir is $genomeDir"

hg38_annotation_dir="/project/RDS-SMS-FFbigdata-RW/local_lib/genomes/hg38/annotation/humandb/"
echo "hg38_annotation_dir is $hg38_annotation_dir"

cohort_vcf=${2}/results/${1}.g.vcf
echo "cohort_vcf is $cohort_vcf"

##########################################################################################################################
##########################################################################################################################
# 1. Functional Annotioan of Variants using ANNOVAR
##########################################################################################################################
##########################################################################################################################

if [ ! -f $outDir/${1}.g.vcf ];
then
  echo "Running ANNOVAR"
    
  echo "Running table_annovar.pl $cohort_vcf $hg38_annotation_dir \
     -buildver hg38 \
     -out ${outDir}/${1}_annovar \
     -remove \
     -protocol refGene,cytoBand,exac03,exac03nontcga,exac03nonpsych,avsnp150,dbnsfp33a,dbnsfp31a_interpro,dbscsnv11,cosmic70,esp6500siv2_ea,esp6500siv2_aa,esp6500siv2_all,gnomad_exome,gnomad_genome,AFR.sites.2015_08,ALL.sites.2015_08,AMR.sites.2015_08,EUR.sites.2015_08,mcap,revel,clinvar_20170130 \
     -operation gx,r,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f \
     -nastring . \
     --thread $numcores \
     -vcfinput"
  echo "[TIME: ANNOVAR]"
  time table_annovar.pl $cohort_vcf $hg38_annotation_dir \
     -buildver hg38 \
     -out ${outDir}/${1}_annovar \
     -remove \
     -protocol refGene,cytoBand,exac03,exac03nontcga,exac03nonpsych,avsnp150,dbnsfp33a,dbnsfp31a_interpro,dbscsnv11,cosmic70,esp6500siv2_ea,esp6500siv2_aa,esp6500siv2_all,gnomad_exome,gnomad_genome,AFR.sites.2015_08,ALL.sites.2015_08,AMR.sites.2015_08,EUR.sites.2015_08,mcap,revel,clinvar_20170130 \
     -operation gx,r,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f,f \
     -nastring . \
     --thread $numcores \
     -vcfinput
 else
  echo "Found" $outDir/${1}.g.vcf
fi
