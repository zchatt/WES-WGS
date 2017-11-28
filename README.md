# WES-WGS
Pipelines and tools for  WES and WGS data processing

# pjob_bwa_gatk.sh
## Script creates and submits PBS batch script
### Script description 
1. Create submission script for rsync of .fastq files from RDS to HPC
2. Creates submission script for bwa_gatk.sh
3. Creates submission script for rsync of bwa_katk.sh results from HPC to RDS

# bwa_gatk.sh
## Align WGS or WES using BWA-MEM and call variants using GATK
### Script description 
1. Index the reference FASTA sequence for use with BWA
2. Align FASTQ reads with BWA-MEM to hg38 with ATL-contigs
3. Add read group information, preprocess to make a clean BAM and call variants
4. Create unmapped uBAM- This step uses Picard tools RevertSam function to revert sam file produced during alignment to 
  previous state. We clear read attributes that have prevented  alignments (XA: Alternative hits; format: (chr,pos,CIGAR,NM;) & 
  XS:Suboptimal alignment score) 
5. Add read group information to uBAM
6. Merge uBAM with aligned BAMi) Performed with Picard MergeBamAlignment. Needs to have FASTA dictionary file (.dic) in same 
  directory as reference sequence.ii) Set UNMAP_CONTAMINANT_READS (Boolean) to “true” which enables detection of reads originating 
   from foreign organisms (e.g. bacterial DNA in a non-bacterial sample), and unmap + label those reads accordingly. iii) When 
   UNMAP_CONTAMINANT_READS is set, then we must setMIN_UNCLIPPED_BASES (Integer), default = 32

#### 7. Base Recalibrator Report & 8. Perform Base Quality Score Recalibration (BQSR) - Currently uncommented as previous studies by Tian et al 2016 (https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5048557/) found  BQSR had virtually negligible effect on INDEL calling and generally reduced sensitivity for SNP calling and reduced the SNP calling sensitivity but improved the precision when the coverage is insufficient. However, in regions of high divergence (e.g., the HLA region), BQSR reduced the sensitivity of callers. There is currently not a good argument to support its use if we are using alt-aware alignment. # - This step attempts performs recalibration of base score qualities using machine learning. Read Group information is used to identify the same sample/ run therefore this must be performed prior to changing of read group information.

9. Flag duplicate reads- The step flags duplicate reads. OPTICAL_DUPLICATE_PIXEL_DISTANCE; The maximum offset between two duplicate 
clusters in order to consider them optical duplicates. The default is appropriate for unpatterned versions of the Illumina platform. 
For the patterned flowcell models, 2500 is moreappropriate. For other platforms and models, users should experiment to find what 
works best. Default value: 100. This option can be set to 'null' to clear the default value.
10. Coordinate sort, fix NM and UQ tags and index for clean BAMi) Picard.SortSam;  Sort BAM file using coordinatesii) Picard. 
SetNmAndUqTags; - NM:i: Edit distance to the reference, including ambiguous bases but excluding clipping. i.e. mismatches to 
reference- UQ:i: Phred likelihood of the segment, conditional on the mapping being correct. i.e. quality score of the mapping- NOTE; 
Here we are using picard 2.7.1. With picard 2.10.6 and higher command is SetNmMDAndUqTags however seems to have piping issues at the 
moment https://gatkforums.broadinstitute.org/gatk/discussion/10104/picard-2-10-7-fails-pipelining-sortsam-and-setnmanduqtags
11. Call SNP and indel variants in reference confidence (ERC) mode per sample using HaplotypeCaller

# annovar.sh
## Annotates .vcf files from gatk using ANNOVAR
### Script description 
1. ANNOVAR .vcf file annotioans with currently implemented annnotations that include; refGene,cytoBand,exac03,exac03nontcga,exac03nonpsych,avsnp147,dbnsfp33a,dbscsnv11,cosmic70,esp6500siv2_ea,esp6500siv2_aa,esp6500siv2_all,gnomad_exome,gnomad_genome,AFR.sites.2015_08,ALL.sites.2015_08,AMR.sites.2015_08,mcap,revel,clinvar_20170130

RUN SCRIPT

~/scripts/annovar.sh CDS0024.20K_ /project/RDS-SMS-FFbigdata-RW/Genetics/Genomes/whole_genome_sequencing_2012/FASTQ/bwagatk_test/test_271117
